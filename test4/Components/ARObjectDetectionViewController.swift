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
        // 设置2D标签点击回调，直接查找并显示记忆卡片
        labelManager.onLabelTapped = { [weak self] objectID in
            print("[onLabelTapped] 被点击的objectID: \(objectID)")
            self?.findAndShowMemoryCard(objectName: objectID)
        }
        
        // 设置2D标签长按回调，显示编辑对话框
        labelManager.onLabelLongPressed = { [weak self] objectID in
            print("[onLabelLongPressed] 被长按的objectID: \(objectID)")
            self?.showCustomNameInput(objectID: objectID)
        }
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        tapGesture.cancelsTouchesInView = false
        
        // 添加长按手势
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.8
        sceneView.addGestureRecognizer(longPressGesture)
        longPressGesture.cancelsTouchesInView = false
        
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
            findAndShowMemoryCard(objectName: objectID)
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        // 只在手势开始时触发一次
        if gesture.state == .began {
            let location = gesture.location(in: sceneView)
            let hitResults = sceneView.hitTest(location, options: nil)
            
            if let node = hitResults.first?.node,
               let objectID = findObjectID(for: node) {
                // 添加触觉反馈
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // 显示编辑对话框
                showCustomNameInput(objectID: objectID)
            }
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
        let alert = UIAlertController(title: "物品标签", message: "请选择操作", preferredStyle: .alert)
        
        // 添加"查找记忆卡片"按钮
        alert.addAction(UIAlertAction(title: "查找记忆卡片", style: .default) { [weak self] _ in
            self?.findAndShowMemoryCard(objectName: objectID)
        })
        
        // 添加"自定义标签"按钮
        alert.addAction(UIAlertAction(title: "自定义标签", style: .default) { [weak self] _ in
            self?.showCustomNameInput(objectID: objectID)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    // 修改方法：显示自定义标签输入界面，增加更多选项和视觉提示
    private func showCustomNameInput(objectID: String) {
        // 获取当前自定义名称（如果有）
        let currentName = labelManager.getCustomName(for: objectID) ?? objectID
        
        let alert = UIAlertController(title: "编辑物品名称", message: "当前名称: \(currentName)", preferredStyle: .alert)
        alert.addTextField { [weak self] textField in
            textField.placeholder = "输入新名称"
            textField.text = self?.labelManager.getCustomName(for: objectID) ?? objectID
            textField.clearButtonMode = .whileEditing
            textField.autocapitalizationType = .none
            textField.returnKeyType = .done
        }
        
        // 保存按钮
        let saveAction = UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            
            // 保存自定义名称
            self.labelManager.saveCustomName(name, for: objectID)
            self.labelManager.refreshBoundingBox(for: objectID, confidence: 1.0)
            
            // 显示成功提示
            let successAlert = UIAlertController(title: nil, message: "名称已更新", preferredStyle: .alert)
            self.present(successAlert, animated: true)
            
            // 1秒后自动关闭提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                successAlert.dismiss(animated: true)
            }
        }
        
        // 查找卡片按钮
        let findCardAction = UIAlertAction(title: "查找记忆卡片", style: .default) { [weak self] _ in
            self?.findAndShowMemoryCard(objectName: objectID)
        }
        
        // 取消按钮
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        
        // 添加按钮到对话框
        alert.addAction(saveAction)
        alert.addAction(findCardAction)
        alert.addAction(cancelAction)
        
        // 设置首选按钮
        alert.preferredAction = saveAction
        
        present(alert, animated: true) {
            // 对话框显示后，自动选中文本框中的文本
            if let textField = alert.textFields?.first {
                textField.selectAll(nil)
            }
        }
    }
    
    // 新方法：查找并显示记忆卡片
    private func findAndShowMemoryCard(objectName: String) {
        // 显示加载指示器
        let loadingAlert = UIAlertController(title: nil, message: "正在查找记忆卡片...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // 获取自定义名称（如果有）
        let customName = labelManager.getCustomName(for: objectName) ?? objectName
        
        // 查找标题匹配的卡片
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // 关闭加载指示器
            self.dismiss(animated: true) {
                if let matchingCard = self.cardStore.cards.first(where: { $0.title == customName }) {
                    // 创建并展示CardDetailView，并提供CoreData上下文
                    let context = PersistenceController.shared.container.viewContext
                    
                    // 创建一个可以切换标签的TabSelection绑定
                    let tabSelectionBinding = Binding<Int>(
                        get: { 0 },
                        set: { newValue in
                            // 当设置为1(导航标签)时，先关闭当前视图，然后切换到主视图的导航标签
                            if newValue == 1 {
                                self.dismiss(animated: true) {
                                    // 通过NotificationCenter发送通知，让ContentView切换标签
                                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToNavigationTab"), object: nil)
                                }
                            }
                        }
                    )
                    
                    // 创建CardDetailView
                    let cardDetailView = CardDetailView(
                        card: matchingCard,
                        cardStore: self.cardStore,
                        tabSelection: tabSelectionBinding
                    )
                    .environment(\.managedObjectContext, context)
                    
                    // 包装在NavigationView中以显示导航栏
                    let hostingController = UIHostingController(
                        rootView: NavigationView {
                            cardDetailView
                        }
                    )
                    
                    self.present(hostingController, animated: true)
                } else {
                    // 未找到对应卡片，显示提示
                    let alert = UIAlertController(
                        title: "未找到记忆卡片",
                        message: "未找到与\"\(customName)\"匹配的记忆卡片",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
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
                    // 创建并展示CardDetailView，并提供CoreData上下文
                    let context = PersistenceController.shared.container.viewContext
                    
                    // 创建一个可以切换标签的TabSelection绑定
                    let tabSelectionBinding = Binding<Int>(
                        get: { 0 },
                        set: { newValue in
                            // 当设置为1(导航标签)时，先关闭当前视图，然后切换到主视图的导航标签
                            if newValue == 1 {
                                self.dismiss(animated: true) {
                                    // 通过NotificationCenter发送通知，让ContentView切换标签
                                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToNavigationTab"), object: nil)
                                }
                            }
                        }
                    )
                    
                    // 创建CardDetailView
                    let cardDetailView = CardDetailView(
                        card: waterBottleCard,
                        cardStore: self.cardStore,
                        tabSelection: tabSelectionBinding
                    )
                    .environment(\.managedObjectContext, context)
                    
                    // 包装在NavigationView中以显示导航栏
                    let hostingController = UIHostingController(
                        rootView: NavigationView {
                            cardDetailView
                        }
                    )
                    
                    self.present(hostingController, animated: true)
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
