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
    private let processingInterval: TimeInterval = 0.5
    private var yoloModel: VNCoreMLModel?
    
    init() {
        setupYOLO()
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
        let currentTime = CACurrentMediaTime()
        guard !isProcessing && currentTime - lastProcessedTime > processingInterval else {
            return
        }
        isProcessing = true
        lastProcessedTime = currentTime
        guard let yoloModel = yoloModel else {
            isProcessing = false
            return
        }
        let request = VNCoreMLRequest(model: yoloModel) { [weak self] request, error in
            self?.processYOLOResults(request: request, error: error)
        }
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
    }
    
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
        print("YOLO 检测到物体数量: \(results.count)")
        let detectedObjects: [DetectedObject] = results.compactMap { obs in
            guard let topLabel = obs.labels.first else { return nil }
            
            // 处理标识符，确保正确显示中文名称
            var identifier = topLabel.identifier
            
            // 对特定的英文标识符进行中文映射
            let englishToChinese: [String: String] = [
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
                "hair drier": "吹风机"
            ]
            
            if let chineseName = englishToChinese[identifier.lowercased()] {
                identifier = chineseName
            }
            
            print("物体: \(identifier), 置信度: \(topLabel.confidence), boundingBox: \(obs.boundingBox)")
            return DetectedObject(identifier: identifier, confidence: topLabel.confidence, boundingBox: obs.boundingBox)
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
