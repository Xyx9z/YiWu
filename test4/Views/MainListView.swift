import SwiftUI
import AVFoundation
import CoreLocation

struct MainListView: View {
    @StateObject private var cardStore = MemoryCardStore()
    @State private var showingAddCard = false
    @State private var selectedCard: MemoryCard?
    @State private var showingDeleteAlert = false
    @State private var cardToDelete: MemoryCard?
    // Tab切换
    @State private var selectedTab: Int = 0 // 0-物品，1-事件
    
    // 语音识别相关状态
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var transcriptionText: String = ""
    @State private var isTranscribing: Bool = false
    @State private var showingTranscription: Bool = false
    @State private var transcriptionService = TranscriptionService(apiKey: "sk-pnyyswesfdoqkbqmxfpsiykxwglhupcqtpoldurutopocajv")
    @State private var navigateToCard: MemoryCard? = nil
    @State private var showMatchAlert: Bool = false
    @State private var matchedCards: [TextMatchingService.MatchResult] = []
    
    // 水杯卡片编辑相关
    @State private var showingEditWaterBottleCard: Bool = false
    @State private var waterBottleCard: MemoryCard? = nil
    
    // 寻物助手导航相关
    @State private var navigateToWaterBottleFinder: Bool = false
    @State private var waterBottleDestination = LocationData(
        coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        name: "我的水杯",
        description: "个人水杯位置"
    )
    
    // 动画状态
    @State private var animateBackground = false
    @State private var animateCards = false
    
    // 定义网格布局
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // 渐变色定义
    private let gradientStart = Color.white
    private let gradientEnd = Color.white.opacity(0.9)
    // 蓝色渐变定义（用于Tab切换）
    private let blueGradientStart = Color(hex: "#4A6FFF")
    private let blueGradientEnd = Color(hex: "#77BDFF")
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Image("SunsetBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                
                // 已移除装饰性元素，使用SunsetBackground图片作为背景
                
                // 主要内容
                VStack(spacing: 0) {
                    // 顶部Tab切换
                    HStack(spacing: 0) {
                        ForEach(["物品", "事件"], id: \.self) { tab in
                            let isSelected = (tab == "物品" && selectedTab == 0) || (tab == "事件" && selectedTab == 1)
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab == "物品" ? 0 : 1
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Text(tab)
                                        .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(isSelected ? blueGradientStart : .gray)
                                    
                                    // 下划线指示器
                                    Rectangle()
                                        .fill(isSelected ? blueGradientStart : Color.clear)
                                        .frame(height: 3)
                                        .cornerRadius(1.5)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.white.opacity(0.7))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, y: 3)
                    )
                    
                    // Tab内容区
                    TabView(selection: $selectedTab) {
                        // 物品Tab内容
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(cardStore.cards.filter { $0.type == .item }) { card in
                                    NavigationLink(destination: CardDetailViewContainer(card: card, cardStore: cardStore)) {
                                        CardGridItem(card: card)
                                            .opacity(animateCards ? 1 : 0)
                                            .offset(y: animateCards ? 0 : 20)
                                            .animation(
                                                .spring(response: 0.5, dampingFraction: 0.8)
                                                .delay(Double(cardStore.cards.firstIndex(where: { $0.id == card.id }) ?? 0) * 0.05),
                                                value: animateCards
                                            )
                                    }
                                    .simultaneousGesture(LongPressGesture().onEnded { _ in
                                        cardToDelete = card
                                        showingDeleteAlert = true
                                    })
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 100) // 为底部麦克风按钮留出空间
                        }
                        .tag(0)
                        
                        // 事件Tab内容
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(cardStore.cards.filter { $0.type == .event }) { card in
                                    NavigationLink(destination: CardDetailViewContainer(card: card, cardStore: cardStore)) {
                                        EventCardListItem(card: card)
                                            .opacity(animateCards ? 1 : 0)
                                            .offset(y: animateCards ? 0 : 20)
                                            .animation(
                                                .spring(response: 0.5, dampingFraction: 0.8)
                                                .delay(Double(cardStore.cards.firstIndex(where: { $0.id == card.id }) ?? 0) * 0.05),
                                                value: animateCards
                                            )
                                    }
                                    .simultaneousGesture(LongPressGesture().onEnded { _ in
                                        cardToDelete = card
                                        showingDeleteAlert = true
                                    })
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 100) // 为底部麦克风按钮留出空间
                        }
                        .tag(1)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // 居中标题
                    ToolbarItem(placement: .principal) {
                        Text("记忆卡片")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [gradientStart, gradientEnd]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    // 右侧添加按钮
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAddCard = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [gradientStart, gradientEnd]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
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
                
                // 底部麦克风按钮
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
                    .padding(.bottom, 20)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                }
                
                // 转录结果显示
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
            // 导航链接
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
            // 寻物导航链接
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
            // 匹配结果提示
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
        .onAppear {
            // 启动动画
            withAnimation {
                animateBackground = true
                
                // 延迟一点启动卡片动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateCards = true
                }
            }
            
            // 加载数据
            Task {
                do {
                    try await cardStore.load()
                } catch {
                    print("加载卡片失败：\(error)")
                }
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
                    // 检测"编辑我的水杯"指令
                    else if TextMatchingService.checkEditWaterBottleCommand(text: text) {
                        // 查找"我的水杯"卡片并打开编辑页面
                        self.findAndEditWaterBottleCard()
                        self.showingTranscription = false // 隐藏转写窗口
                    }
                    // 检测"寻务助手"指令
                    else if TextMatchingService.checkNavigationAssistantCommand(text: text) {
                        // 如果是寻务助手指令，发送通知切换到寻务助手标签页
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToNavigationTab"), object: nil)
                        self.showingTranscription = false // 隐藏转写窗口
                    } 
                    // 检测"物品识别"指令
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
    
    // 检查是否是寻找水杯的指令
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
    
    // 查找并编辑水杯卡片
    private func findAndEditWaterBottleCard() {
        // 查找标题为"我的水杯"的卡片
        if let waterBottleCard = cardStore.cards.first(where: { $0.title == "我的水杯" }) {
            // 保存找到的卡片
            self.waterBottleCard = waterBottleCard
            // 显示编辑页面
            self.showingEditWaterBottleCard = true
        } else {
            // 未找到水杯卡片，显示提示
            self.transcriptionText = "未找到\"我的水杯\"卡片"
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

// 物品卡片（网格样式）
struct CardGridItem: View {
    let card: MemoryCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图片区域
            ZStack(alignment: .topTrailing) {
                if !card.images.isEmpty, let uiImage = UIImage(data: card.images[0].imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "#F0F4F8"), Color(hex: "#E0E6EA")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 150)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.7))
                        )
                }
                
                // 右上角标签 - 如果有音频
                if card.audioData != nil {
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .medium))
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                        .foregroundColor(.blue)
                        .padding(8)
                }
            }
            
            // 标题和内容区域
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .padding(.top, 10)
                
                if !card.content.isEmpty {
                    Text(card.content)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.bottom, 2)
                }
                
                // 时间戳
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    Text(formatDate(card.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
}

// 事件卡片（列表样式）
struct EventCardListItem: View {
    let card: MemoryCard
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧图片
            ZStack(alignment: .bottomTrailing) {
                if !card.images.isEmpty, let uiImage = UIImage(data: card.images[0].imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#FFB347"), Color(hex: "#FFCC80")]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.7)
                        .frame(width: 90, height: 90)
                        .overlay(
                            Image(systemName: "calendar")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                
                // 音频指示器
                if card.audioData != nil {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.white, Color.blue)
                        .background(Circle().fill(Color.white))
                        .offset(x: -4, y: -4)
                }
            }
            
            // 右侧内容
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if !card.content.isEmpty {
                    Text(card.content)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // 底部信息栏
                HStack(spacing: 12) {
                    // 日期时间
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#FF9500"))
                        
                        Text(formatDate(card.timestamp))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#FF9500"))
                    }
                    
                    // 提醒状态
                    if card.reminderEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#30B0C7"))
                            
                            Text(formatReminderFrequency(card.reminderFrequency))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#30B0C7"))
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 8)
            
            Spacer()
            
            // 右侧箭头指示器
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray.opacity(0.6))
                .padding(.trailing, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .frame(maxWidth: .infinity)
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
    
    // 格式化提醒频率
    private func formatReminderFrequency(_ frequency: ReminderFrequency) -> String {
        switch frequency {
        case .once:
            return "单次提醒"
        case .daily:
            return "每日提醒"
        case .weekly:
            return "每周提醒"
        case .monthly:
            return "每月提醒"
        case .none:
            return ""
        }
    }
}

#Preview {
    MainListView()
} 
