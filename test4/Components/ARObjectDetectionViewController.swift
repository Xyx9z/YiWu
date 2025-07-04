import UIKit
import ARKit
import SceneKit
import SwiftUI
import CoreData

// 新增：检测器类型枚举
enum DetectorType {
    case vision
    case yolo
}

class ARObjectDetectionViewController: UIViewController {
    private var sceneView: ARSCNView!
    private var sessionManager: ARSessionManager!
    private var yoloDetector: YOLOObjectDetector!
    private var labelManager: ARLabelManager!
    private var cardStore = MemoryCardStore()
    
    // 新增：公开方法用于外部控制AR会话
    @objc func startARSession() {
        sessionManager?.resetTracking()
    }
    @objc func pauseARSession() {
        sessionManager?.pauseSession()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAR()
        setupManagers()
    }
    
    private func setupAR() {
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        view.addSubview(sceneView)
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        #if DEBUG
        sceneView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        #endif
        
        sceneView.automaticallyUpdatesLighting = true
        sceneView.antialiasingMode = .multisampling4X
    }
    
    private func setupManagers() {
        sessionManager = ARSessionManager(sceneView: sceneView)
        sessionManager.delegate = self
        
        yoloDetector = YOLOObjectDetector()
        yoloDetector.delegate = self
        
        labelManager = ARLabelManager(parentView: sceneView)
        // 设置2D标签点击回调，弹出自定义标签弹窗
        labelManager.onLabelTapped = { [weak self] objectID in
            print("[onLabelTapped] 被点击的objectID: \(objectID)")
            self?.promptForCustomName(objectID: objectID)
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        tapGesture.cancelsTouchesInView = false
        
        // 加载记忆卡片
        Task {
            do {
                try await cardStore.load()
            } catch {
                print("加载卡片失败：\(error)")
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionManager.resetTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionManager.pauseSession()
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: sceneView)
        let hitResults = sceneView.hitTest(location, options: nil)
        
        if let node = hitResults.first?.node,
           let objectID = findObjectID(for: node) {
            promptForCustomName(objectID: objectID)
        }
    }
    
    private func findObjectID(for node: SCNNode) -> String? {
        var current: SCNNode? = node
        while current != nil {
            if let name = current?.name {
                return name
            }
            current = current?.parent
        }
        return nil
    }
    
    private func promptForCustomName(objectID: String) {
        let alert = UIAlertController(title: "自定义标签", message: "请输入新名称", preferredStyle: .alert)
        alert.addTextField { [weak self] textField in
            textField.placeholder = "输入新名称"
            textField.text = self?.labelManager.getCustomName(for: objectID)
        }
        
        // 添加查询按钮，使用蓝色风格使其更为突出
        alert.addAction(UIAlertAction(title: "查询水杯", style: .default) { [weak self] _ in
            self?.openWaterBottleCard()
        })
        
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            if let name = alert.textFields?.first?.text {
                self?.labelManager.saveCustomName(name, for: objectID)
                self?.labelManager.refreshBoundingBox(for: objectID, confidence: 1.0)
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    // 添加打开水杯卡片的方法
    private func openWaterBottleCard() {
        // 显示加载指示器
        let loadingAlert = UIAlertController(title: nil, message: "正在查找记忆卡片...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // 查找标题为"我的水杯"的卡片
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // 关闭加载指示器
            self.dismiss(animated: true) {
                if let waterBottleCard = self.cardStore.cards.first(where: { $0.title == "我的水杯" }) {
                    // 创建并展示CardEditView，并提供CoreData上下文
                    let context = PersistenceController.shared.container.viewContext
                    let cardEditView = UIHostingController(
                        rootView: CardEditView(cardStore: self.cardStore, card: waterBottleCard)
                            .environment(\.managedObjectContext, context)
                    )
                    self.present(cardEditView, animated: true)
                } else {
                    // 未找到对应卡片，显示提示
                    let alert = UIAlertController(title: "未找到", message: "未找到'我的水杯'的记忆卡片", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

extension ARObjectDetectionViewController: ARSessionManagerDelegate {
    func sessionManager(_ manager: ARSessionManager, didFailWithError error: Error) {
        guard let arError = error as? ARError else { return }
        
        let errorMessage: String
        switch arError.code {
        case .cameraUnauthorized:
            errorMessage = "请在设置中允许访问相机"
        case .sensorUnavailable:
            errorMessage = "传感器不可用，请确保设备支持AR"
        case .sensorFailed:
            errorMessage = "传感器出错，请重启应用"
        case .worldTrackingFailed:
            errorMessage = "跟踪失败，请尝试重置"
        default:
            errorMessage = "出现未知错误: \(error.localizedDescription)"
        }
        
        let alert = UIAlertController(
            title: "AR会话错误",
            message: errorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            self?.sessionManager.resetTracking()
        })
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    func sessionManager(_ manager: ARSessionManager, didUpdatePixelBuffer pixelBuffer: CVPixelBuffer, trackingState: ARCamera.TrackingState) {
        yoloDetector.processFrame(pixelBuffer, trackingState: trackingState)
    }
    
    func sessionManagerWasInterrupted(_ manager: ARSessionManager) {
        print("AR会话被中断")
    }
    
    func sessionManagerInterruptionEnded(_ manager: ARSessionManager) {
        print("AR会话中断结束，重置跟踪")
        sessionManager.resetTracking()
    }
}

extension ARObjectDetectionViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if let frame = sceneView.session.currentFrame {
            let camera = frame.camera
            if camera.trackingState != .normal {
//                print("相机跟踪状态: \(camera.trackingState)")
            }
        }
    }
}

extension ARSCNView {
    /// 计算 ARKit 视频帧在 ARSCNView 中的实际显示区域（考虑 letterbox）
    func videoFrameRect(pixelBuffer: CVPixelBuffer) -> CGRect {
        let bufferWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let bufferHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let bufferRatio = bufferWidth / bufferHeight
        let viewRatio = self.bounds.width / self.bounds.height
        if bufferRatio > viewRatio {
            // 视频帧宽度撑满
            let width = self.bounds.width
            let height = width / bufferRatio
            let y = (self.bounds.height - height) / 2
            return CGRect(x: 0, y: y, width: width, height: height)
        } else {
            // 视频帧高度撑满
            let height = self.bounds.height
            let width = height * bufferRatio
            let x = (self.bounds.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: height)
        }
    }
}

extension ARObjectDetectionViewController: YOLOObjectDetectorDelegate {
    func objectDetector(_ detector: Any, didDetectObjects results: [DetectedObject]) {
        print("objectDetector 回调，检测到 \(results.count) 个物体")
        labelManager.clearAllBoundingBoxes()
        guard let currentFrame = sceneView.session.currentFrame else { return }
        let transform = currentFrame.displayTransform(for: .portrait, viewportSize: sceneView.bounds.size)
        for object in results {
            guard let bbox = object.boundingBox else { continue }
            let rect = bbox.applying(transform)
            let label = labelManager.getCustomName(for: object.identifier) ?? object.identifier
            labelManager.addBoundingBox(for: object.identifier, at: rect, label: label, confidence: object.confidence, baseRect: sceneView.bounds)
        }
    }
    
    func objectDetector(_ detector: Any, didFailWithError error: Error) {
        print("物体识别错误: \(error)")
    }
} 
