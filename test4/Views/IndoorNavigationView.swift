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
                                Image("室内地图")
                                    .resizable()
                                    .scaledToFill()
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
                            Text(selectedDestination == nil ? "选择所寻物品" : "开始导航")
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
            
            // 从NavigationService获取已设置的目的地
            if let destination = navigationService.getDestination() {
                self.selectedDestination = destination
                print("已获取到设置的目的地: \(destination.name), 坐标: \(destination.coordinate.latitude), \(destination.coordinate.longitude)")
                // 只设置目的地，不自动开始导航
            } else {
                print("未获取到目的地，等待用户选择")
            }
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
                    .cornerRadius(20)
                    .padding()
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
    @State private var showingDeleteAlert = false
    @State private var destinationToDelete: Destination?
    
    // 定义网格布局
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    init(selectedDestination: Binding<LocationData?>) {
        self._selectedDestination = selectedDestination
        self._destinationStore = StateObject(wrappedValue: DestinationStore(context: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景图片
                Image("SunsetBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .opacity(0.7)
                    .overlay(
                        Color.black.opacity(0.1)
                    )
                
                // 装饰性气泡
                Circle()
                    .fill(Color(hex: "#EDFFC9"))
                    .opacity(0.7)
                    .frame(width: 180, height: 180)
                    .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 0)
                    .position(x: 50, y: 100)
                
                Circle()
                    .fill(Color(hex: "#EDFFC9"))
                    .opacity(0.7)
                    .frame(width: 120, height: 120)
                    .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 0)
                    .position(x: UIScreen.main.bounds.width - 40, y: 200)
                
                // 主要内容
                VStack(spacing: 0) {
                    // 记忆卡片样式显示目的地
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(destinationStore.destinations) { destination in
                                DestinationCard(destination: destination) {
                                    // 点击选择目的地
                                    let name = destination.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                    selectedDestination = LocationData(
                                        coordinate: CLLocationCoordinate2D(
                                            latitude: destination.latitude,
                                            longitude: destination.longitude
                                        ),
                                        name: name,
                                        description: destination.notes
                                    )
                                    presentationMode.wrappedValue.dismiss()
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        destinationToDelete = destination
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("选择所寻物品")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white, Color(hex: "#E0ECFF")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 2)
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 1)
                            .padding(.top, 4)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddForm = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
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
            .alert("删除目的地", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let destination = destinationToDelete {
                        destinationStore.deleteDestination(destination)
                    }
                }
            } message: {
                Text("确定要删除这个目的地吗？此操作无法撤销。")
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

// 目的地卡片组件
struct DestinationCard: View {
    let destination: Destination
    let onTap: () -> Void
    @State private var destinationImage: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 图片区域
                ZStack {
                    if let image = destinationImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 140)
                            .overlay(
                                Image(systemName: "mappin.and.ellipse")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 50)
                                    .foregroundColor(.blue.opacity(0.7))
                            )
                    }
                    
                    // 位置坐标展示
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(String(format: "%.4f, %.4f", destination.latitude, destination.longitude))
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                                .padding(8)
                        }
                    }
                }
                .cornerRadius(8, corners: [.topLeft, .topRight])
                
                // 标题和内容区域
                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "未命名位置")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let notes = destination.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadDestinationImage()
        }
    }
    
    private func loadDestinationImage() {
        if let id = destination.id?.uuidString {
            destinationImage = DestinationImageManager.shared.getImage(for: id)
        }
    }
}

// 圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
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
        print("ARNavigationViewController初始化: 目的地=\(destination.name), 坐标=\(destination.coordinate.latitude), \(destination.coordinate.longitude)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupNavigation()
        print("ARNavigationViewController.viewDidLoad: 目的地=\(destination.name)")
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
        // 移除所有导航球
        guideSpheres.forEach { $0.removeFromParentNode() }
        guideSpheres.removeAll()
        
        // 移除初始引导球
        initialGuideSphere?.removeFromParentNode()
        initialGuideSphere = nil
        guideTextNode?.removeFromParentNode()
        guideTextNode = nil
        
        // 移除所有箭头节点
        arView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name?.contains("arrow") == true {
                node.removeFromParentNode()
            }
        }
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
        
        // 重新创建引导球之间的箭头
        // 首先移除现有箭头
        arView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name?.contains("arrow") == true {
                node.removeFromParentNode()
            }
        }
        
        // 如果有两个或更多球，就在它们之间添加箭头
        if guideSpheres.count >= 2 {
            for i in 0..<(guideSpheres.count - 1) {
                let startSphere = guideSpheres[i]
                let endSphere = guideSpheres[i+1]
                
                let arrow = createArrow(from: startSphere.position, to: endSphere.position, named: "arrow\(i+1)")
                arView.scene.rootNode.addChildNode(arrow)
            }
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
            (position: SCNVector3(1, 0, 1), name: "guideSphere0"),
            (position: SCNVector3(2, 0, 2), name: "guideSphere1"),
            (position: SCNVector3(3, 0, 1), name: "guideSphere2"),
            (position: SCNVector3(4, 0, 0), name: "guideSphere3"),
            (position: SCNVector3(3, 0, -1), name: "guideSphere4")
            // 已删除最后一个导航球: (position: SCNVector3(4, 0, -2), name: "guideSphere5")
        ]
        
        // 创建所有球体
        for (index, sphereData) in positions.enumerated() {
            let sphere = createGuideSphere(at: sphereData.position, named: sphereData.name, index: index)
            arView.scene.rootNode.addChildNode(sphere)
            guideSpheres.append(sphere)
            
            // 为特定小球添加文字提示
            if index == 1 { // 第二个小球（索引为1，是guideSphere1）
                addTextLabel(text: "请向左转", at: sphereData.position, yOffset: 0.2)
            } else if index == 3 { // 第四个小球（索引为3，是guideSphere3）
                addTextLabel(text: "请向左转", at: sphereData.position, yOffset: 0.2)
            } else if index == positions.count - 1 { // 最后一个小球
                addTextLabel(text: destination.name, at: sphereData.position, yOffset: 0.2)
            }
        }
        
        // 添加球体之间的箭头 (除了最后一个球不需要添加箭头)
        for i in 0..<(positions.count - 1) {
            let startPosition = positions[i].position
            let endPosition = positions[i+1].position
            
            let arrow = createArrow(from: startPosition, to: endPosition, named: "arrow\(i+1)")
            arView.scene.rootNode.addChildNode(arrow)
        }
    }
    
    // 添加文字标签，始终朝向用户
    private func addTextLabel(text: String, at position: SCNVector3, yOffset: Float) {
        // 创建文本几何体
        let textGeometry = SCNText(string: text, extrusionDepth: 0.01)
        textGeometry.font = UIFont.systemFont(ofSize: 0.4) // 放大5倍，从0.08改为0.4
        textGeometry.flatness = 0.1
        textGeometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        
        // 设置文本材质
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.emission.contents = UIColor.white.withAlphaComponent(0.5) // 添加轻微发光效果
        textGeometry.materials = [material]
        
        // 创建文本节点
        let textNode = SCNNode(geometry: textGeometry)
        
        // 计算文本边界以便居中
        let min = textNode.boundingBox.min
        let max = textNode.boundingBox.max
        textNode.pivot = SCNMatrix4MakeTranslation(
            (max.x - min.x)/2 + min.x,
            min.y,
            min.z
        )
        
        // 缩放文本到合适大小
        textNode.scale = SCNVector3(0.5, 0.5, 0.5) // 放大5倍，从0.1改为0.5
        
        // 将文本定位在小球上方
        let labelPosition = SCNVector3(position.x, position.y + yOffset, position.z)
        textNode.position = labelPosition
        
        // 添加Billboard约束，使文本始终朝向用户
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.X, .Y, .Z] // 所有轴都自由旋转，确保始终面向用户
        textNode.constraints = [billboardConstraint]
        
        // 添加发光效果
        let light = SCNLight()
        light.type = .ambient
        light.color = UIColor.white
        light.intensity = 500
        textNode.light = light
        
        // 将文本节点添加到场景
        arView.scene.rootNode.addChildNode(textNode)
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
    
    // 创建从一个点指向另一个点的箭头
    private func createArrow(from startPoint: SCNVector3, to endPoint: SCNVector3, named: String) -> SCNNode {
        // 创建箭头容器节点
        let arrowNode = SCNNode()
        arrowNode.name = named
        
        // 计算两点之间的向量和距离
        let direction = SCNVector3(endPoint.x - startPoint.x, 0, endPoint.z - startPoint.z)
        let distance = sqrt(pow(direction.x, 2) + pow(direction.z, 2))
        
        // 创建箭头杆（圆柱体）
        let shaftLength = distance * 0.8 // 箭头杆占总长度的80%
        let shaftGeometry = SCNCylinder(radius: 0.01, height: CGFloat(shaftLength))
        let shaftMaterial = SCNMaterial()
        shaftMaterial.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.8)
        shaftMaterial.emission.contents = UIColor.systemBlue.withAlphaComponent(0.5)
        shaftGeometry.materials = [shaftMaterial]
        
        let shaftNode = SCNNode(geometry: shaftGeometry)
        // 注意：圆柱体默认是沿Y轴的，我们需要将其旋转到Z轴
        shaftNode.eulerAngles.x = Float.pi / 2
        
        // 创建箭头头部（圆锥体）
        let headLength = distance * 0.2 // 箭头头部占总长度的20%
        let headGeometry = SCNCone(topRadius: 0.0, bottomRadius: 0.025, height: CGFloat(headLength))
        let headMaterial = SCNMaterial()
        headMaterial.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.8)
        headMaterial.emission.contents = UIColor.systemBlue.withAlphaComponent(0.5)
        headGeometry.materials = [headMaterial]
        
        let headNode = SCNNode(geometry: headGeometry)
        // 定位箭头头部到杆的末端
        headNode.position = SCNVector3(0, 0, shaftLength / 2 + headLength / 2)
        // 注意：圆锥体默认也是沿Y轴的，需要旋转
        headNode.eulerAngles.x = Float.pi / 2
        
        // 将箭头杆和头部添加到容器节点
        arrowNode.addChildNode(shaftNode)
        arrowNode.addChildNode(headNode)
        
        // 计算箭头位置（两点之间的中点）
        let midPoint = SCNVector3(
            (startPoint.x + endPoint.x) / 2,
            0.02, // 稍微抬高一点以避免与地面重叠
            (startPoint.z + endPoint.z) / 2
        )
        arrowNode.position = midPoint
        
        // 重新实现方向计算 - 使用向量方向直接确定旋转角度
        // 我们需要找到在XZ平面上从起点指向终点的方向
        
        // 归一化方向向量
        let length = sqrt(direction.x * direction.x + direction.z * direction.z)
        let normalized = SCNVector3(direction.x / length, 0, direction.z / length)
        
        // 计算与Z轴的角度（Z轴作为参考，因为我们的箭头默认沿Z轴）
        let angleFromZ = atan2(normalized.x, normalized.z)
        arrowNode.eulerAngles.y = angleFromZ
        
        // 为箭头添加淡淡的发光效果
        let light = SCNLight()
        light.type = .ambient
        light.color = UIColor.systemBlue
        light.intensity = 300
        arrowNode.light = light
        
        return arrowNode
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