import SwiftUI

struct MainListView: View {
    @StateObject private var cardStore = MemoryCardStore()
    @State private var showingAddCard = false
    @State private var selectedCard: MemoryCard?
    @State private var showingDeleteAlert = false
    @State private var cardToDelete: MemoryCard?
    
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
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(cardStore.cards) { card in
                            CardGridItem(card: card)
                                .onTapGesture {
                                    selectedCard = card
                                }
                                .onLongPressGesture {
                                    cardToDelete = card
                                    showingDeleteAlert = true
                                }
                        }
                    }
                    .padding(.horizontal, 32) // 增加左右边距，给边缘留出更多空间
                    .padding(.top, 12)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAddCard = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.white) // 使加号按钮在深色背景上更显眼
                        }
                    }
                }
                .sheet(isPresented: $showingAddCard) {
                    CardEditView(cardStore: cardStore)
                }
                .sheet(item: $selectedCard) { card in
                    CardEditView(cardStore: cardStore, card: card)
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