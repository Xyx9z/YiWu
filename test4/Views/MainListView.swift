import SwiftUI

struct MainListView: View {
    @StateObject private var cardStore = MemoryCardStore()
    @State private var showingAddCard = false
    @State private var selectedCard: MemoryCard?
    @State private var showingDeleteAlert = false
    @State private var cardToDelete: MemoryCard?
    // 新增：顶部Tab切换
    @State private var selectedTab: Int = 0 // 0-物品，1-事件
    
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
                                ForEach(cardStore.cards) { card in
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
                        }
                    } else {
                        // 事件Tab内容（占位）
                        VStack {
                            Spacer()
                            Text("这里是事件Tab内容")
                                .foregroundColor(.secondary)
                                .font(.title3)
                            Spacer()
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
                    CardEditView(cardStore: cardStore)
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

// 更新卡片样式
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

#Preview {
    MainListView()
} 