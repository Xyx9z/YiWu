import SwiftUI
import ARKit
import CoreLocation
import CoreData

struct IndoorNavigationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingDestinationPicker = false
    @State private var isNavigating = false
    @State private var navigationInstructions = ""
    @State private var selectedDestination: LocationData?
    @State private var showingFullMap = false
    @Environment(\.presentationMode) var presentationMode
    
    private let locationService = LocationService.shared
    private let navigationService = NavigationService.shared
    
    var body: some View {
        ZStack {
            // AR相机预览作为背景
            ARViewContainer()
                .edgesIgnoringSafeArea(.all)
            
            if isNavigating {
                ZStack {
                    ARNavigationView(navigationInstructions: $navigationInstructions, 
                                   isNavigating: $isNavigating,
                                   destination: selectedDestination!)
                        .edgesIgnoringSafeArea(.all)
                    
                    // 右下角的小地图
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showingFullMap = true
                            }) {
                                Image("室内地图") // 确保在Assets中添加了"室内地图"图片
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .shadow(radius: 5)
                            }
                            .padding()
                        }
                    }
                }
            } else {
                // 主界面UI
                VStack {
                    Spacer()
                    
                    if let destination = selectedDestination,
                       destination.name == "我的水杯" {
                        Image("我的水杯")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(10)
                            .padding()
                            .onAppear {
                                print("尝试加载图片：我的水杯")
                            }
                    }
                    
                    Text("当前选择的目的地: \(selectedDestination?.name ?? "无")")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)
                    
                    VStack(spacing: 20) {
                        Button(action: {
                            if let destination = selectedDestination {
                                startNavigation(to: destination)
                            } else {
                                showingDestinationPicker = true
                            }
                        }) {
                            Text(selectedDestination == nil ? "选择目的地" : "开始导航")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        
                        if selectedDestination != nil {
                            Button(action: {
                                selectedDestination = nil
                            }) {
                                Text("重新选择")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.gray)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingDestinationPicker) {
            DestinationPickerView(selectedDestination: $selectedDestination)
        }
        .sheet(isPresented: $showingFullMap) {
            FullMapView(isPresented: $showingFullMap)
        }
        .onAppear {
            locationService.requestLocationPermission()
        }
    }
    
    private func startNavigation(to destination: LocationData) {
        navigationService.setDestination(destination)
        isNavigating = true
        locationService.startUpdatingLocation()
    }
}

struct FullMapView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Image("室内地图")
                    .resizable()
                    .scaledToFit()
            }
            .navigationTitle("室内地图")
            .navigationBarItems(
                trailing: Button("关闭") {
                    isPresented = false
                }
            )
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration)
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

struct ARNavigationView: UIViewControllerRepresentable {
    @Binding var navigationInstructions: String
    @Binding var isNavigating: Bool
    let destination: LocationData
    
    func makeUIViewController(context: Context) -> ARNavigationViewController {
        let controller = ARNavigationViewController(destination: destination)
        controller.delegate = context.coordinator
        controller.onClose = {
            isNavigating = false
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ARNavigationViewController, context: Context) {
        uiViewController.updateDestination(destination)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARNavigationViewControllerDelegate {
        var parent: ARNavigationView
        
        init(_ parent: ARNavigationView) {
            self.parent = parent
        }
        
        func navigationViewController(_ controller: ARNavigationViewController, didUpdateInstructions instructions: String) {
            parent.navigationInstructions = instructions
        }
    }
}

struct DestinationPickerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var destinationStore: DestinationStore
    @Binding var selectedDestination: LocationData?
    @Environment(\.presentationMode) var presentationMode
    @State private var showingAddForm = false
    @State private var newDestinationName = ""
    @State private var newDestinationLatitude = ""
    @State private var newDestinationLongitude = ""
    @State private var newDestinationNotes = ""
    
    init(selectedDestination: Binding<LocationData?>) {
        self._selectedDestination = selectedDestination
        self._destinationStore = StateObject(wrappedValue: DestinationStore(context: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(destinationStore.destinations) { destination in
                    Button(action: {
                        let name = destination.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        print("选择目的地：\(name)")
                        selectedDestination = LocationData(
                            coordinate: CLLocationCoordinate2D(
                                latitude: destination.latitude,
                                longitude: destination.longitude
                            ),
                            name: name,
                            description: destination.notes
                        )
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        VStack(alignment: .leading) {
                            Text(destination.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "未命名位置")
                                .font(.headline)
                            Text("经度: \(destination.longitude), 纬度: \(destination.latitude)")
                                .font(.subheadline)
                            if let notes = destination.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let destination = destinationStore.destinations[index]
                        destinationStore.deleteDestination(destination)
                    }
                }
            }
            .navigationTitle("选择目的地")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    showingAddForm = true
                }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $showingAddForm) {
                NavigationView {
                    Form {
                        TextField("名称", text: $newDestinationName)
                        TextField("纬度", text: $newDestinationLatitude)
                            .keyboardType(.decimalPad)
                        TextField("经度", text: $newDestinationLongitude)
                            .keyboardType(.decimalPad)
                        TextField("备注", text: $newDestinationNotes)
                    }
                    .navigationTitle("添加目的地")
                    .navigationBarItems(
                        leading: Button("取消") {
                            showingAddForm = false
                        },
                        trailing: Button("保存") {
                            saveNewDestination()
                        }
                    )
                }
            }
        }
    }
    
    private func saveNewDestination() {
        guard let latitude = Double(newDestinationLatitude),
              let longitude = Double(newDestinationLongitude) else {
            return
        }
        
        let name = newDestinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        destinationStore.addDestination(
            name: name,
            latitude: latitude,
            longitude: longitude,
            notes: newDestinationNotes
        )
        
        // 重置表单
        newDestinationName = ""
        newDestinationLatitude = ""
        newDestinationLongitude = ""
        newDestinationNotes = ""
        showingAddForm = false
    }
}

protocol ARNavigationViewControllerDelegate: AnyObject {
    func navigationViewController(_ controller: ARNavigationViewController, didUpdateInstructions instructions: String)
}

class ARNavigationViewController: UIViewController {
    weak var delegate: ARNavigationViewControllerDelegate?
    var onClose: (() -> Void)?
    private var arView: ARSCNView!
    private let navigationService = NavigationService.shared
    private var destination: LocationData
    private var instructionsLabel: UILabel!
    private var guideSpheres: [SCNNode] = []
    private var isInitialSetupComplete = false
    private var initialGuideSphere: SCNNode?
    private var guideTextNode: SCNNode?
    
    // MARK: - Lifecycle
    
    init(destination: LocationData) {
        self.destination = destination
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupNavigation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupARSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isInitialSetupComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.initializeGuideSpheres()
                self?.isInitialSetupComplete = true
            }
        } else {
            restoreGuideSpheres()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    // MARK: - Setup Methods
    
    private func setupARView() {
        arView = ARSCNView(frame: view.bounds)
        arView.delegate = self
        arView.session.delegate = self
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        let scene = SCNScene()
        arView.scene = scene
        arView.automaticallyUpdatesLighting = true
        
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 1000
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
    }
    
    private func setupNavigation() {
        navigationService.setDestination(destination)
        
        // 添加导航指示标签
        instructionsLabel = UILabel(frame: CGRect(x: 20, y: 100,
                                               width: view.bounds.width - 40, height: 50))
        instructionsLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        instructionsLabel.textColor = .white
        instructionsLabel.textAlignment = .center
        instructionsLabel.numberOfLines = 0
        instructionsLabel.layer.cornerRadius = 10
        instructionsLabel.layer.masksToBounds = true
        instructionsLabel.font = .systemFont(ofSize: 18, weight: .medium)
        view.addSubview(instructionsLabel)
        updateNavigationInstructions()
        
        // 添加关闭按钮
        let closeButton = UIButton(frame: CGRect(x: 20, y: 40, width: 44, height: 44))
        closeButton.setTitle("×", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 22
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        addNavigationNodes()
    }
    
    private func setupARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // MARK: - Guide Spheres Management
    
    private func initializeGuideSpheres() {
        removeAllGuideSpheres()
        createInitialGuideSphere()
        createGuideSpheres()
    }
    
    private func removeAllGuideSpheres() {
        guideSpheres.forEach { $0.removeFromParentNode() }
        guideSpheres.removeAll()
        initialGuideSphere?.removeFromParentNode()
        initialGuideSphere = nil
        guideTextNode?.removeFromParentNode()
        guideTextNode = nil
    }
    
    private func restoreGuideSpheres() {
        // 恢复初始引导球
        if let initialSphere = initialGuideSphere, initialSphere.parent == nil {
            arView.scene.rootNode.addChildNode(initialSphere)
        }
        initialGuideSphere?.isHidden = false
        
        // 恢复文本节点
        if let textNode = guideTextNode, textNode.parent == nil {
            arView.scene.rootNode.addChildNode(textNode)
        }
        guideTextNode?.isHidden = false
        
        // 恢复其他引导球
        guideSpheres.forEach { sphere in
            if sphere.parent == nil {
                arView.scene.rootNode.addChildNode(sphere)
            }
            sphere.isHidden = false
        }
    }
    
    private func createInitialGuideSphere() {
        // 创建球体容器节点（用于动画）
        let sphereContainer = SCNNode()
        sphereContainer.position = SCNVector3(1, 0, 1)
        
        // 创建初始引导球
        let sphereGeometry = SCNSphere(radius: 0.08)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.8)
        material.emission.contents = UIColor.systemBlue.withAlphaComponent(0.5)
        material.lightingModel = .physicallyBased
        material.roughness.contents = 0.0
        material.metalness.contents = 1.0
        sphereGeometry.materials = [material]
        
        let sphereNode = SCNNode(geometry: sphereGeometry)
        sphereNode.name = "initialGuideSphere"
        
        // 添加发光效果
        let light = SCNLight()
        light.type = .omni
        light.color = UIColor.systemBlue
        light.intensity = 1000
        light.attenuationStartDistance = 0.1
        light.attenuationEndDistance = 0.5
        light.categoryBitMask = 2
        sphereNode.light = light
        
        // 将球体添加到容器中
        sphereContainer.addChildNode(sphereNode)
        
        // 只对球体应用缩放动画
        addPulseAnimation(to: sphereNode, withDelay: 0)
        
        // 创建文本容器节点（独立于球体动画）
        let textContainerNode = SCNNode()
        textContainerNode.position = SCNVector3(0, 0.2, 0)
        
        // 创建"请跟随小球到达"文本
        let followText = SCNText(string: "请跟随小球到达", extrusionDepth: 0.1)
        followText.font = UIFont.systemFont(ofSize: 0.3)
        followText.flatness = 0.1
        let followMaterial = SCNMaterial()
        followMaterial.diffuse.contents = UIColor.white
        followMaterial.isDoubleSided = true
        followText.materials = [followMaterial]
        
        let followTextNode = SCNNode(geometry: followText)
        followTextNode.scale = SCNVector3(0.225, 0.225, 0.225)
        
        // 创建目的地名称文本
        let destinationText = SCNText(string: destination.name, extrusionDepth: 0.1)
        destinationText.font = UIFont.systemFont(ofSize: 0.3)
        destinationText.flatness = 0.1
        let destinationMaterial = SCNMaterial()
        destinationMaterial.diffuse.contents = UIColor.systemBlue
        destinationMaterial.isDoubleSided = true
        destinationText.materials = [destinationMaterial]
        
        let destinationTextNode = SCNNode(geometry: destinationText)
        destinationTextNode.scale = SCNVector3(0.225, 0.225, 0.225)
        
        // 计算文本宽度并居中对齐
        let followBounds = followText.boundingBox
        let followWidth = followBounds.max.x - followBounds.min.x
        followTextNode.position = SCNVector3(-followWidth * 0.1125, 0.15, 0)
        
        let destBounds = destinationText.boundingBox
        let destWidth = destBounds.max.x - destBounds.min.x
        destinationTextNode.position = SCNVector3(-destWidth * 0.1125, 0.05, 0)
        
        // 将文本添加到容器节点
        textContainerNode.addChildNode(followTextNode)
        textContainerNode.addChildNode(destinationTextNode)
        
        // 创建并添加 Billboard 约束
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = .Y
        textContainerNode.constraints = [billboardConstraint]
        
        // 将文本容器添加到主场景
        sphereContainer.addChildNode(textContainerNode)
        
        // 保存引用并添加到场景
        initialGuideSphere = sphereContainer
        guideTextNode = textContainerNode
        
        arView.scene.rootNode.addChildNode(sphereContainer)
    }
    
    private func createGuideSpheres() {
        let positions = [
            (position: SCNVector3(2, 0, 2), name: "guideSphere1"),
            (position: SCNVector3(3, 0, 1), name: "guideSphere2"),
            (position: SCNVector3(4, 0, 0), name: "guideSphere3"),
            (position: SCNVector3(3, 0, -1), name: "guideSphere4"),
            (position: SCNVector3(4, 0, -2), name: "guideSphere5")
        ]
        
        for (index, sphereData) in positions.enumerated() {
            let sphere = createGuideSphere(at: sphereData.position, named: sphereData.name, index: index)
            arView.scene.rootNode.addChildNode(sphere)
            guideSpheres.append(sphere)
        }
    }
    
    private func createGuideSphere(at position: SCNVector3, named: String, index: Int) -> SCNNode {
        let sphereGeometry = SCNSphere(radius: 0.05)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.8)
        material.emission.contents = UIColor.systemBlue.withAlphaComponent(0.5)
        material.lightingModel = .physicallyBased
        material.roughness.contents = 0.0
        material.metalness.contents = 1.0
        sphereGeometry.materials = [material]
        
        let sphereNode = SCNNode(geometry: sphereGeometry)
        sphereNode.position = position
        sphereNode.name = named
        
        // 添加发光效果
        let light = SCNLight()
        light.type = .omni
        light.color = UIColor.systemBlue
        light.intensity = 800
        light.attenuationStartDistance = 0.1
        light.attenuationEndDistance = 0.5
        light.categoryBitMask = 2
        sphereNode.light = light
        
        // 添加动画
        addPulseAnimation(to: sphereNode, withDelay: TimeInterval(index) * 0.2)
        
        return sphereNode
    }
    
    private func addPulseAnimation(to node: SCNNode, withDelay delay: TimeInterval) {
        // 创建缩放动作
        let scaleUp = SCNAction.scale(to: 1.2, duration: 0.5)
        let scaleDown = SCNAction.scale(to: 1.0, duration: 0.5)
        let pulseSequence = SCNAction.sequence([scaleUp, scaleDown])
        let repeatPulse = SCNAction.repeatForever(pulseSequence)
        
        // 如果节点已经有动画，先移除
        node.removeAllActions()
        
        // 添加新的动画
        node.runAction(
            SCNAction.sequence([
                SCNAction.wait(duration: delay),
                repeatPulse
            ])
        )
    }
    
    private func addNavigationNodes() {
        // 添加目标位置标记
        let destinationNode = SCNNode()
        destinationNode.name = "destinationNode"
        
        // 创建目标位置的3D文本
        let textGeometry = SCNText(string: destination.name, extrusionDepth: 0.1)
        textGeometry.font = UIFont.systemFont(ofSize: 0.3)
        textGeometry.flatness = 0.1
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.name = "destinationText"
        textNode.scale = SCNVector3(0.1, 0.1, 0.1)
        
        // 计算文本的边界框以居中放置
        let min = textNode.boundingBox.min
        let max = textNode.boundingBox.max
        textNode.pivot = SCNMatrix4MakeTranslation(
            (max.x - min.x)/2,
            min.y,
            0.0
        )
        
        // 设置文本位置和材质
        textNode.position = SCNVector3(0, 0.3, 0)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        textGeometry.materials = [material]
        
        destinationNode.addChildNode(textNode)
        arView.scene.rootNode.addChildNode(destinationNode)
    }
    
    private func updateNavigationInstructions() {
        instructionsLabel.text = "正在前往\(destination.name)"
    }
    
    @objc private func closeButtonTapped() {
        onClose?()
    }
    
    func updateDestination(_ newDestination: LocationData) {
        destination = newDestination
        navigationService.setDestination(newDestination)
        
        // 清除现有的导航节点
        arView.scene.rootNode.childNodes.forEach { node in
            if node.name == "destinationNode" || node.name == "destinationText" {
                node.removeFromParentNode()
            }
        }
        
        // 重新添加导航节点
        addNavigationNodes()
        updateNavigationInstructions()
    }
}

// MARK: - AR Session Delegate
extension ARNavigationViewController: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session Error: \(error.localizedDescription)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.setupARSession()
            self?.restoreGuideSpheres()
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("AR Session Interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("AR Session Interruption Ended")
        setupARSession()
        restoreGuideSpheres()
    }
}

// MARK: - AR Scene View Delegate
extension ARNavigationViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 确保初始引导球可见
            if let initialSphere = self.initialGuideSphere, initialSphere.parent == nil {
                self.arView.scene.rootNode.addChildNode(initialSphere)
            }
            self.initialGuideSphere?.isHidden = false
            
            // 确保文本节点可见
            if let textNode = self.guideTextNode, textNode.parent == nil {
                self.arView.scene.rootNode.addChildNode(textNode)
            }
            self.guideTextNode?.isHidden = false
            
            // 确保其他引导球可见
            self.guideSpheres.forEach { sphere in
                if sphere.parent == nil {
                    self.arView.scene.rootNode.addChildNode(sphere)
                }
                sphere.isHidden = false
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // 当检测到平面时确保引导球可见
        DispatchQueue.main.async { [weak self] in
            self?.restoreGuideSpheres()
        }
    }
}

#Preview {
    IndoorNavigationView()
} 