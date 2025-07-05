import SwiftUI
import CoreData
import CoreLocation

// 包装器组件，用于从环境获取tabSelection
struct CardDetailViewContainer: View {
    let card: MemoryCard
    let cardStore: MemoryCardStore
    @Environment(\.tabSelection) private var tabSelection
    
    var body: some View {
        CardDetailView(card: card, cardStore: cardStore, tabSelection: tabSelection)
    }
}

struct CardDetailView: View {
    let card: MemoryCard
    @ObservedObject var cardStore: MemoryCardStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageIndex: Int = 0
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingEditSheet = false
    @State private var updatedCard: MemoryCard
    @Binding var tabSelection: Int
    @State private var destination: Destination?
    @State private var showFullContent = false
    
    init(card: MemoryCard, cardStore: MemoryCardStore, tabSelection: Binding<Int>) {
        self.card = card
        self.cardStore = cardStore
        self._updatedCard = State(initialValue: card)
        self._tabSelection = tabSelection
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部图片轮播
                if !updatedCard.images.isEmpty {
                    ZStack(alignment: .bottomTrailing) {
                        TabView(selection: $selectedImageIndex) {
                            ForEach(updatedCard.images.indices, id: \.self) { idx in
                                if let uiImage = UIImage(data: updatedCard.images[idx].imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 260)
                                        .clipped()
                                        .tag(idx)
                                }
                            }
                        }
                        .frame(height: 260)
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                    }
                    .padding(.top, 16)
                }
                
                // 主要内容区域
                VStack(alignment: .leading, spacing: 16) {
                    // 标题和标签区域
                    HStack(alignment: .center) {
                        Text(updatedCard.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Text(updatedCard.type == .item ? "物品" : "事件")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                updatedCard.type == .item ? Color.blue : Color.orange,
                                                updatedCard.type == .item ? Color.blue.opacity(0.7) : Color.orange.opacity(0.7)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // 详细内容
                    if !updatedCard.content.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(showFullContent || updatedCard.content.count < 100 ? updatedCard.content : String(updatedCard.content.prefix(100) + "..."))
                                .font(.system(size: 17))
                                .foregroundColor(Color(.label))
                                .lineSpacing(5)
                            
                            if updatedCard.content.count > 100 {
                                Button(action: {
                                    withAnimation(.easeInOut) {
                                        showFullContent.toggle()
                                    }
                                }) {
                                    Text(showFullContent ? "收起" : "查看更多")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 分隔线
                    Divider()
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    // 音频播放区域
                    if updatedCard.audioData != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "headphones")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                                Text("语音记录")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            AudioPlayButton(audioData: updatedCard.audioData)
                                .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6).opacity(0.7))
                        )
                        .padding(.horizontal)
                    }
                    
                    // 位置信息显示
                    if let dest = destination, dest.latitude != 0 || dest.longitude != 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.red)
                                    .font(.system(size: 20))
                                Text("位置信息")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Image(systemName: "location.circle")
                                    .foregroundColor(.red)
                                    .font(.system(size: 16))
                                    .frame(width: 24)
                                Text("经度: \(String(format: "%.6f", dest.longitude)), 纬度: \(String(format: "%.6f", dest.latitude))")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                            
                            if let notes = dest.notes, !notes.isEmpty {
                                HStack(alignment: .top) {
                                    Image(systemName: "text.bubble")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16))
                                        .frame(width: 24)
                                    Text(notes)
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6).opacity(0.7))
                        )
                        .padding(.horizontal)
                    }
                    
                    // 只有在物品类型时才显示导航按钮
                    if updatedCard.type == .item {
                        Button(action: {
                            if let dest = destination, dest.latitude != 0 && dest.longitude != 0 {
                                alertMessage = "正在导航到：\(updatedCard.title)"
                                
                                // 设置目的地并跳转到IndoorNavigationView
                                let locationData = LocationData(
                                    coordinate: CLLocationCoordinate2D(
                                        latitude: dest.latitude,
                                        longitude: dest.longitude
                                    ),
                                    name: dest.name ?? updatedCard.title,
                                    description: dest.notes
                                )
                                
                                // 确保设置目的地
                                NavigationService.shared.setDestination(locationData)
                                print("已设置导航目的地: \(locationData.name), 坐标: \(locationData.coordinate.latitude), \(locationData.coordinate.longitude)")
                                
                                // 直接切换到IndoorNavigation标签页
                                tabSelection = 1
                            } else {
                                alertMessage = "该物品没有有效的位置信息"
                                showAlert = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    .font(.system(size: 20))
                                Text("导航到该物品")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.green.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .alert(alertMessage, isPresented: $showAlert) {
                            Button("确定", role: .cancel) {}
                        }
                    }
                    
                    // 时间戳
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.gray)
                        Text("创建时间：\(updatedCard.timestamp, formatter: itemFormatter)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingEditSheet = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: {
            // 当编辑视图关闭时，更新当前卡片
            if let index = cardStore.cards.firstIndex(where: { $0.id == card.id }) {
                updatedCard = cardStore.cards[index]
            }
            loadDestination() // 重新加载位置信息
        }) {
            CardEditView(cardStore: cardStore, card: updatedCard)
        }
        .onAppear {
            // 确保显示的是最新数据
            if let index = cardStore.cards.firstIndex(where: { $0.id == card.id }) {
                updatedCard = cardStore.cards[index]
            }
            loadDestination() // 加载位置信息
        }
    }
    
    private func loadDestination() {
        let fetchRequest = NSFetchRequest<Destination>(entityName: "Destination")
        fetchRequest.predicate = NSPredicate(format: "name == %@", updatedCard.title.trimmingCharacters(in: .whitespacesAndNewlines))
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            destination = results.first
        } catch {
            print("Error fetching destination: \(error)")
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}() 
