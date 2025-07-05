import Foundation
import CoreML
import Vision
import ARKit

struct DetectedObject {
    let identifier: String
    let confidence: Float
    let boundingBox: CGRect? // Vision分类模型为nil，YOLOv3为真实框
}

// 新增：YOLOObjectDetectorDelegate协议
protocol YOLOObjectDetectorDelegate: AnyObject {
    func objectDetector(_ detector: Any, didDetectObjects results: [DetectedObject])
    func objectDetector(_ detector: Any, didFailWithError error: Error)
}

class YOLOObjectDetector {
    weak var delegate: YOLOObjectDetectorDelegate?
    private var isProcessing = false
    private var lastProcessedTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 0.2  // 提高刷新率，从0.5秒降低到0.2秒
    private var yoloModel: VNCoreMLModel?
    private var useMultiThread = true  // 启用多线程处理
    private var currentDeviceOrientation: UIDeviceOrientation = .portrait  // 当前设备方向
    
    init() {
        setupYOLO()
        setupOrientationMonitoring()
    }
    
    // 监听设备方向变化
    private func setupOrientationMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        currentDeviceOrientation = UIDevice.current.orientation
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    @objc private func deviceOrientationDidChange() {
        // 在AR应用中，我们不需要根据设备方向改变图像处理方式
        // 因为ARKit提供的图像方向是固定的
        // 这个方法保留，但不做任何处理
    }
    
    private func setupYOLO() {
        if let resourcePath = Bundle.main.resourcePath {
            let files = try? FileManager.default.contentsOfDirectory(atPath: resourcePath)
            print("[YOLOObjectDetector] Bundle 资源文件列表: \(files ?? [])")
        }

        print("[YOLOObjectDetector] 尝试查找模型文件...")
        guard let modelURL = Bundle.main.url(forResource: "yolov8x", withExtension: "mlmodelc") else {
            print("[YOLOObjectDetector] 模型文件未找到，请检查文件名、扩展名和是否已加入 Copy Bundle Resources")
            return
        }
        print("[YOLOObjectDetector] 找到模型文件，路径: \(modelURL)")
        
        do {
            print("[YOLOObjectDetector] 尝试加载 MLModel ...")
            let model = try MLModel(contentsOf: modelURL)
            print("[YOLOObjectDetector] MLModel 加载成功，尝试转换为 VNCoreMLModel ...")
            yoloModel = try VNCoreMLModel(for: model)
            print("[YOLOObjectDetector] VNCoreMLModel 转换成功")
            
            // 打印模型信息
            let modelDescription = model.modelDescription
            print("[YOLOObjectDetector] 模型输入信息:")
            for input in modelDescription.inputDescriptionsByName {
                print("输入名称: \(input.key), 类型: \(input.value.type), 形状: \(input.value.multiArrayConstraint?.shape ?? [])")
            }
            print("[YOLOObjectDetector] 模型输出信息:")
            for output in modelDescription.outputDescriptionsByName {
                print("输出名称: \(output.key), 类型: \(output.value.type), 形状: \(output.value.multiArrayConstraint?.shape ?? [])")
            }
        } catch {
            print("[YOLOObjectDetector] 模型加载或转换失败: \(error)")
        }
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer, trackingState: ARCamera.TrackingState) {
        // 如果跟踪状态不正常，则降低检测频率
        let effectiveInterval = trackingState == .normal ? processingInterval : processingInterval * 1.5
        
        let currentTime = CACurrentMediaTime()
        guard !isProcessing && currentTime - lastProcessedTime > effectiveInterval else {
            return
        }
        isProcessing = true
        lastProcessedTime = currentTime
        
        guard let yoloModel = yoloModel else {
            isProcessing = false
            return
        }
        
        // 优化请求配置
        let request = VNCoreMLRequest(model: yoloModel) { [weak self] request, error in
            self?.processYOLOResults(request: request, error: error)
        }
        
        // 设置图像裁剪和缩放选项为aspectFit，保持物体比例
        request.imageCropAndScaleOption = .centerCrop
        
        // 设置更高的检测置信度阈值，减少误报
        request.usesCPUOnly = false  // 使用GPU加速
        
        // 优化图像处理选项
        let options: [VNImageOption: Any] = [
            .ciContext: CIContext(options: [.priorityRequestLow: true]),
            .cameraIntrinsics: [:]  // 使用默认相机内参
        ]
        
        // 使用固定的图像方向 - ARKit提供的图像方向是固定的
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: options)
        
        if useMultiThread {
            // 使用高优先级队列进行检测
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                do {
                    try handler.perform([request])
                } catch {
                    DispatchQueue.main.async {
                        self?.delegate?.objectDetector(self as Any, didFailWithError: error)
                    }
                }
                DispatchQueue.main.async {
                    self?.isProcessing = false
                }
            }
        } else {
            // 单线程模式 - 用于低端设备
            do {
                try handler.perform([request])
                self.processYOLOResults(request: request, error: nil)
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.objectDetector(self as Any, didFailWithError: error)
                }
            }
            isProcessing = false
        }
    }
    
    // 中英文物体名称映射表
    private let englishToChinese: [String: String] = [
        "cup": "水杯",
        "bottle": "水瓶",
        "book": "书本",
        "laptop": "笔记本电脑",
        "cell phone": "手机",
        "keyboard": "键盘",
        "mouse": "鼠标",
        "remote": "遥控器",
        "glasses": "眼镜",
        "clock": "时钟",
        "vase": "花瓶",
        "scissors": "剪刀",
        "teddy bear": "泰迪熊",
        "toothbrush": "牙刷",
        "hair drier": "吹风机",
        "toilet": "马桶",
        "sink": "水槽",
        "tv": "电视",
        "refrigerator": "冰箱",
        "microwave": "微波炉",
        "oven": "烤箱",
        "chair": "椅子",
        "dining table": "餐桌",
        "couch": "沙发",
        "bed": "床",
        "person": "人",
        "backpack": "背包",
        "umbrella": "雨伞",
        "tie": "领带"
    ]
    
    // 最低可接受的置信度
    private let confidenceThreshold: Float = 0.55
    
    // 重叠框过滤阈值
    private let iouThreshold: Float = 0.5
    
    private func processYOLOResults(request: VNRequest, error: Error?) {
        if let error = error {
            print("YOLO 检测错误: \(error)")
            DispatchQueue.main.async {
                self.delegate?.objectDetector(self as Any, didFailWithError: error)
            }
            return
        }
        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            print("YOLO 检测无结果")
            DispatchQueue.main.async {
                self.delegate?.objectDetector(self as Any, didDetectObjects: [])
            }
            return
        }
        
        // 过滤低置信度结果
        let filteredResults = results.filter { $0.confidence >= confidenceThreshold }
        
        // 应用非极大值抑制算法，减少重叠框
        let nmsResults = applyNonMaxSuppression(observations: filteredResults)
        
        print("YOLO 检测到物体数量: \(results.count)，过滤后: \(nmsResults.count)")
        
        let detectedObjects: [DetectedObject] = nmsResults.compactMap { obs in
            guard let topLabel = obs.labels.first else { return nil }
            
            // 处理标识符，确保正确显示中文名称
            var identifier = topLabel.identifier
            
            if let chineseName = englishToChinese[identifier.lowercased()] {
                identifier = chineseName
            }
            
            // 优化边界框
            let optimizedBox = optimizeBoundingBox(obs.boundingBox)
            
            print("物体: \(identifier), 置信度: \(topLabel.confidence), boundingBox: \(optimizedBox)")
            return DetectedObject(identifier: identifier, confidence: topLabel.confidence, boundingBox: optimizedBox)
        }
        DispatchQueue.main.async {
            self.delegate?.objectDetector(self as Any, didDetectObjects: detectedObjects)
        }
        print("request.results: \(String(describing: request.results))")
        if let results = request.results {
            for r in results {
                print("result type: \(type(of: r)), value: \(r)")
            }
        }
    }
    
    // 计算两个矩形的IoU（交并比）
    private func calculateIoU(rect1: CGRect, rect2: CGRect) -> Float {
        let intersection = rect1.intersection(rect2)
        if intersection.isEmpty {
            return 0.0
        }
        
        let unionArea = rect1.width * rect1.height + rect2.width * rect2.height - intersection.width * intersection.height
        return Float(intersection.width * intersection.height / unionArea)
    }
    
    // 应用非极大值抑制算法(Non-Maximum Suppression)
    private func applyNonMaxSuppression(observations: [VNRecognizedObjectObservation]) -> [VNRecognizedObjectObservation] {
        // 首先按置信度降序排序
        let sortedObservations = observations.sorted(by: { $0.confidence > $1.confidence })
        var selectedObservations: [VNRecognizedObjectObservation] = []
        
        for obs in sortedObservations {
            var shouldSelect = true
            
            // 检查当前观察结果是否与已选择的任何结果有太多重叠
            for selectedObs in selectedObservations {
                // 只比较相同类别的物体
                if obs.labels.first?.identifier == selectedObs.labels.first?.identifier {
                    let iou = calculateIoU(rect1: obs.boundingBox, rect2: selectedObs.boundingBox)
                    if iou > iouThreshold {
                        shouldSelect = false
                        break
                    }
                }
            }
            
            if shouldSelect {
                selectedObservations.append(obs)
            }
        }
        
        return selectedObservations
    }
    
    // 优化边界框尺寸和位置
    private func optimizeBoundingBox(_ box: CGRect) -> CGRect {
        // Vision API 返回的边界框有时不够精确，这里进行微调
        // 稍微扩大框的尺寸以确保物体完全包含
        let expansionFactor: CGFloat = 0.1  // 增加扩展因子，确保框更大一些
        let centerX = box.midX
        let centerY = box.midY
        let newWidth = box.width * (1 + expansionFactor)
        let newHeight = box.height * (1 + expansionFactor)
        
        // 确保边界框不会超出图像边界(0-1范围)
        let newX = max(0, min(1 - newWidth, centerX - newWidth/2))
        let newY = max(0, min(1 - newHeight, centerY - newHeight/2))
        
        // 确保边界框尺寸不会太小，这可能导致UI上显示不清晰
        let minSize: CGFloat = 0.05
        let finalWidth = max(minSize, min(1 - newX, newWidth))
        let finalHeight = max(minSize, min(1 - newY, newHeight))
        
        return CGRect(x: newX, y: newY, width: finalWidth, height: finalHeight)
    }
    
    // 将设备方向转换为Vision框架所需的CGImagePropertyOrientation
    private func getCGImageOrientation(from deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        // 简化处理：对于AR应用，相机捕获的图像方向通常是固定的
        // 无论设备如何旋转，ARKit提供的图像都是以特定方向捕获的
        // 对于大多数设备，这个方向是.up (相当于设备横向，主页键在右侧)
        
        // 注意：在AR应用中，相机图像的方向与设备方向无关，而是与相机硬件的安装方向有关
        // 在iPhone上，相机通常是以横向模式安装的，所以正确的方向是.up
        
        return .up  // 使用固定方向.up，这通常是ARKit提供的图像的正确方向
    }
    
    // 新增：图片识别接口
    func detectImage(pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedObject]) -> Void) {
        print("[YOLOObjectDetector] 开始图像检测...")
        print("[YOLOObjectDetector] 输入图像尺寸: \(CVPixelBufferGetWidth(pixelBuffer))x\(CVPixelBufferGetHeight(pixelBuffer))")
        print("[YOLOObjectDetector] 输入图像格式: \(CVPixelBufferGetPixelFormatType(pixelBuffer))")
        
        guard let yoloModel = yoloModel else {
            print("[YOLOObjectDetector] 模型未加载，无法进行检测")
            completion([])
            return
        }
        
        let request = VNCoreMLRequest(model: yoloModel) { request, error in
            if let error = error {
                print("YOLO 检测错误: \(error)")
                completion([])
                return
            }
            guard let results = request.results as? [VNRecognizedObjectObservation] else {
                print("YOLO 检测无结果")
                completion([])
                return
            }
            print("YOLO 检测到物体数量: \(results.count)")
            let detectedObjects: [DetectedObject] = results.compactMap { obs in
                guard let topLabel = obs.labels.first else { return nil }
                print("物体: \(topLabel.identifier), 置信度: \(topLabel.confidence), boundingBox: \(obs.boundingBox)")
                return DetectedObject(identifier: topLabel.identifier, confidence: topLabel.confidence, boundingBox: obs.boundingBox)
            }
            completion(detectedObjects)
        }
        request.imageCropAndScaleOption = .scaleFill
        // 使用固定的图像方向 - ARKit提供的图像方向是固定的
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("YOLO 检测异常: \(error)")
                completion([])
            }
        }
    }
}
