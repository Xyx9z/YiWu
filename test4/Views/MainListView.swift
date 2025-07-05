import SwiftUI
import AVFoundation
import CoreLocation

struct MainListView: View {
    @StateObject private var cardStore = MemoryCardStore()
    @State private var showingAddCard = false
    @State private var selectedCard: MemoryCard?
    @State private var showingDeleteAlert = false
    @State private var cardToDelete: MemoryCard?
    // 新增：顶部Tab切换
    @State private var selectedTab: Int = 0 // 0-物品，1-事件
    
    // 新增：语音识别相关状态
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var transcriptionText: String = ""
    @State private var isTranscribing: Bool = false
    @State private var showingTranscription: Bool = false
    @State private var transcriptionService = TranscriptionService(apiKey: "sk-pnyyswesfdoqkbqmxfpsiykxwglhupcqtpoldurutopocajv")
    @State private var navigateToCard: MemoryCard? = nil // 新增：用于导航到匹配的卡片
    @State private var showMatchAlert: Bool = false // 新增：显示匹配提示
    @State private var matchedCards: [TextMatchingService.MatchResult] = [] // 新增：匹配到的卡片结果
    
    // 新增：水杯卡片编辑相关
    @State private var showingEditWaterBottleCard: Bool = false
    @State private var waterBottleCard: MemoryCard? = nil
    
    // 新增：寻物助手导航相关
    @State private var navigateToWaterBottleFinder: Bool = false
    @State private var waterBottleDestination = LocationData(
        coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        name: "我的水杯",
        description: "个人水杯位置"
    )
    
    // 定义网格布局
    private let columns = [
        GridItem(.flexible(), spacing: 12), // 减小列间距
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景图片
                Image("SunsetBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .opacity(0.7) // 设置透明度为70%
                    .overlay(
                        Color.black.opacity(0.1) // 添加轻微的暗色遮罩使内容更易读
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
                
                Circle()
                    .fill(Color(hex: "#EDFFC9"))
                    .opacity(0.7)
                    .frame(width: 150, height: 150)
                    .shadow(color: .white.opacity(0.3), radius: 9, x: 0, y: 0)
                    .position(x: UIScreen.main.bounds.width - 80, y: UIScreen.main.bounds.height - 100)
                
                Circle()
                    .fill(Color(hex: "#EDFFC9"))
                    .opacity(0.7)
                    .frame(width: 100, height: 100)
                    .shadow(color: .white.opacity(0.3), radius: 7, x: 0, y: 0)
                    .position(x: 60, y: UIScreen.main.bounds.height - 200)
                
                // 主要内容
                VStack(spacing: 0) {
                    // 新版：顶部Tab切换，左对齐，白色字体
                    HStack(spacing: 28) {
                        Button(action: { selectedTab = 0 }) {
                            Text("物品")
                                .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                                .foregroundColor(.white)
                        }
                        Button(action: { selectedTab = 1 }) {
                            Text("事件")
                                .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .padding(.leading, 40)
                    .padding(.bottom, 4)
                    
                    // Tab内容区
                    if selectedTab == 0 {
                        // 物品Tab内容
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(cardStore.cards.filter { $0.type == .item }) { card in
                                    NavigationLink(destination: CardDetailViewContainer(card: card, cardStore: cardStore)) {
                                        CardGridItem(card: card)
                                    }
                                    .simultaneousGesture(LongPressGesture().onEnded { _ in
                                        cardToDelete = card
                                        showingDeleteAlert = true
                                    })
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.top, 12)
                            .padding(.bottom, 80) // 为底部麦克风按钮留出空间
                        }
                    } else {
                        // 事件Tab内容 - 一行一个的列表布局
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(cardStore.cards.filter { $0.type == .event }) { card in
                                    NavigationLink(destination: CardDetailViewContainer(card: card, cardStore: cardStore)) {
                                        EventCardListItem(card: card)
                                    }
                                    .simultaneousGesture(LongPressGesture().onEnded { _ in
                                        cardToDelete = card
                                        showingDeleteAlert = true
                                    })
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 80) // 为底部麦克风按钮留出空间
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // 居中美观标题
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text("我的记忆卡片")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.white, Color(hex: "#E0ECFF")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 2)
                            // 新增：标题下方分割线
                            Rectangle()
                                .fill(Color.white.opacity(0.18))
                                .frame(height: 1)
                                .padding(.top, 4)
                        }
                    }
                    // 右侧+按钮
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAddCard = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                        }
                    }
                }
                .sheet(isPresented: $showingAddCard) {
                    CardEditView(cardStore: cardStore, initialCardType: selectedTab == 0 ? .item : .event)
                }
                .sheet(isPresented: $showingEditWaterBottleCard) {
                    if let card = waterBottleCard {
                        CardEditView(cardStore: cardStore, card: card)
                    }
                }
                .alert("删除卡片", isPresented: $showingDeleteAlert) {
                    Button("取消", role: .cancel) {}
                    Button("删除", role: .destructive) {
                        if let card = cardToDelete,
                           let index = cardStore.cards.firstIndex(where: { $0.id == card.id }) {
                            cardStore.cards.remove(at: index)
                            Task {
                                try? await cardStore.save()
                            }
                        }
                    }
                } message: {
                    Text("确定要删除这张卡片吗？此操作无法撤销。")
                }
                
                // 新增：底部中央麦克风按钮
                VStack {
                    Spacer()
                    
                    RecordButton(
                        isRecording: $audioRecorder.isRecording,
                        audioLevel: $audioRecorder.audioLevel,
                        recordingDuration: $audioRecorder.recordingDuration,
                        onTap: {
                            handleMicButtonTap()
                        }
                    )
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                    .padding(.bottom, 20)
                }
                
                // 新增：转录结果显示
                if showingTranscription {
                    VStack {
                        TranscriptionView(
                            text: transcriptionText,
                            isTranscribing: isTranscribing,
                            onClear: {
                                transcriptionText = ""
                                showingTranscription = false
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        Spacer()
                    }
                }
            }
            // 新增：导航链接
            .background(
                NavigationLink(
                    destination: navigateToCard.map { card in
                        CardDetailViewContainer(card: card, cardStore: cardStore)
                    },
                    isActive: Binding(
                        get: { navigateToCard != nil },
                        set: { if !$0 { navigateToCard = nil } }
                    )
                ) {
                    EmptyView()
                }
            )
            // 新增：寻物导航链接
            .background(
                NavigationLink(
                    destination: IndoorNavigationView()
                        .onAppear {
                            // 设置目的地为"我的水杯"
                            NavigationService.shared.setDestination(waterBottleDestination)
                        },
                    isActive: $navigateToWaterBottleFinder
                ) {
                    EmptyView()
                }
            )
            // 新增：匹配结果提示
            .alert("找到匹配的记忆卡片", isPresented: $showMatchAlert) {
                // 如果只有一个匹配结果，直接提供打开按钮
                if matchedCards.count == 1 {
                    Button("打开") {
                        navigateToCard = matchedCards.first?.card
                    }
                    Button("取消", role: .cancel) {}
                } 
                // 如果有多个匹配结果，提供查看选项
                else if matchedCards.count > 1 {
                    Button("查看所有匹配") {
                        // 选择置信度最高的那个
                        navigateToCard = matchedCards.first?.card
                    }
                    Button("取消", role: .cancel) {}
                }
            } message: {
                if matchedCards.count == 1 {
                    Text("您说的「\(matchedCards[0].card.title)」似乎与卡片匹配")
                } else if matchedCards.count > 1 {
                    Text("找到\(matchedCards.count)个匹配的记忆卡片")
                }
            }
        }
        .task {
            do {
                try await cardStore.load()
            } catch {
                print("加载卡片失败：\(error)")
            }
        }
    }
    
    // 处理麦克风按钮点击
    private func handleMicButtonTap() {
        if audioRecorder.isRecording {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }
    
    // 开始录音
    private func startRecording() {
        audioRecorder.startRecording()
        isTranscribing = true
        showingTranscription = true
        transcriptionText = "正在录音..."
    }
    
    // 停止录音并转写
    private func stopRecordingAndTranscribe() {
        guard let audioURL = audioRecorder.stopRecording() else {
            transcriptionText = "录音失败"
            isTranscribing = false
            return
        }
        
        transcriptionText = "正在转写..."
        
        Task {
            do {
                let text = try await transcriptionService.transcribe(audioFileURL: audioURL)
                DispatchQueue.main.async {
                    self.transcriptionText = text
                    self.isTranscribing = false
                    
                    // 特殊指令检测：寻找水杯
                    if self.checkWaterBottleCommand(text: text) {
                        // 如果是寻找水杯的指令，发送通知切换到寻物助手标签
                        NavigationService.shared.setDestination(waterBottleDestination)
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToNavigationTab"), object: nil)
                        self.showingTranscription = false // 隐藏转写窗口
                    } 
                    // 新增：检测"编辑我的水杯"指令
                    else if TextMatchingService.checkEditWaterBottleCommand(text: text) {
                        // 查找"我的水杯"卡片并打开编辑页面
                        self.findAndEditWaterBottleCard()
                        self.showingTranscription = false // 隐藏转写窗口
                    }
                    // 新增：检测"寻务助手"指令
                    else if TextMatchingService.checkNavigationAssistantCommand(text: text) {
                        // 如果是寻务助手指令，发送通知切换到寻务助手标签页
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToNavigationTab"), object: nil)
                        self.showingTranscription = false // 隐藏转写窗口
                    } 
                    // 新增：检测"物品识别"指令
                    else if TextMatchingService.checkObjectDetectionCommand(text: text) {
                        // 如果是物品识别指令，发送通知切换到物品识别标签页
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToObjectDetectionTab"), object: nil)
                        self.showingTranscription = false // 隐藏转写窗口
                    }
                    else {
                        // 否则进行常规的卡片匹配
                        self.checkTextMatch(text: text)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.transcriptionText = "转写失败：\(error.localizedDescription)"
                    self.isTranscribing = false
                }
            }
        }
    }
    
    // 新增：检查是否是寻找水杯的指令
    private func checkWaterBottleCommand(text: String) -> Bool {
        // 归一化文本，去除空格和标点符号
        let normalizedText = TextMatchingService.normalizeText(text)
        
        // 检查多种可能的表达方式
        let waterBottleCommands = ["我的水杯在哪", "我的水杯在哪里", "我的水杯去哪了", "找水杯", "寻找水杯", "帮我找水杯"]
        
        for command in waterBottleCommands {
            let normalizedCommand = TextMatchingService.normalizeText(command)
            if normalizedText.contains(normalizedCommand) {
                return true
            }
        }
        
        return false
    }
    
    // 新增：查找并编辑水杯卡片
    private func findAndEditWaterBottleCard() {
        // 查找标题为"我的水杯"的卡片
        if let waterBottleCard = cardStore.cards.first(where: { $0.title == "我的水杯" }) {
            // 保存找到的卡片
            self.waterBottleCard = waterBottleCard
            // 显示编辑页面
            self.showingEditWaterBottleCard = true
        } else {
            // 未找到水杯卡片，显示提示
            self.transcriptionText = "未找到";"我的水杯";"卡片"
        }
    }
    
    // 检查文本匹配
    private func checkTextMatch(text: String) {
        // 使用TextMatchingService进行匹配
        let results = TextMatchingService.findMatchingCardsWithConfidence(
            transcribedText: text,
            cards: cardStore.cards
        )
        
        // 如果有匹配结果
        if !results.isEmpty {
            matchedCards = results
            showMatchAlert = true
        }
    }
}

// 添加 Color 扩展，支持十六进制颜色代码
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// 更新卡片样式 - 物品卡片（网格样式）
struct CardGridItem: View {
    let card: MemoryCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 图片区域
            if !card.images.isEmpty, let uiImage = UIImage(data: card.images[0].imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140) // 稍微减小图片高度
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 140) // 稍微减小占位图高度
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            // 标题和内容区域
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(2)
                
                if !card.content.isEmpty {
                    Text(card.content)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2) // 增加内容显示行数
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity) // 确保卡片宽度一致
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
    }
}

// 新增：事件卡片（列表样式）
struct EventCardListItem: View {
    let card: MemoryCard
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧图片
            if !card.images.isEmpty, let uiImage = UIImage(data: card.images[0].imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                    )
            }
            
            // 右侧内容
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.system(size: 18, weight: .medium))
                    .lineLimit(1)
                
                if !card.content.isEmpty {
                    Text(card.content)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // 时间戳 - 加亮显示
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.orange)
                    
                    Text(formatDate(card.timestamp))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        )
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 8)
            
            Spacer()
            
            // 右侧箭头
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .padding(.trailing, 8)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity)
    }
    
    // 格式化日期为更友好的显示
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    MainListView()
} 
