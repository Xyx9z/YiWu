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
                    ZStack(alignment: .topTrailing) {
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
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        // 页码指示器
                        if updatedCard.images.count > 1 {
                            Text("\(selectedImageIndex+1)/\(updatedCard.images.count)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.35))
                                .cornerRadius(12)
                                .padding(.top, 12)
                                .padding(.trailing, 16)
                        }
                    }
//                    小圆点指示器
                    if updatedCard.images.count > 1 {
                        HStack(spacing: 7) {
                            ForEach(updatedCard.images.indices, id: \.self) { idx in
                                Circle()
                                    .fill(idx == selectedImageIndex ? Color.gray.opacity(0.85) : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                }
                // 标题
                Text(updatedCard.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 0)
                    .padding(.horizontal, 18)
                
                // 类型标签
                HStack {
                    Text(updatedCard.type == .item ? "物品" : "事件")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(updatedCard.type == .item ? Color.blue : Color.orange)
                        )
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                
                // 详细内容
                if !updatedCard.content.isEmpty {
                    Text(updatedCard.content)
                        .font(.system(size: 17))
                        .foregroundColor(Color(.label))
                        .lineSpacing(7)
                        .padding(.all, 18)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                }
                
                // 位置信息显示
                if let dest = destination, dest.latitude != 0 || dest.longitude != 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("位置信息")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.bottom, 4)
                        
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 18))
                            Text("经度: \(String(format: "%.6f", dest.longitude)), 纬度: \(String(format: "%.6f", dest.latitude))")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        
                        if let notes = dest.notes, !notes.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "text.bubble")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                                    .padding(.top, 2)
                                Text(notes)
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(10)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
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
                        Text("导航到该物品")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.green)
                            )
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                    .alert(alertMessage, isPresented: $showAlert) {
                        Button("确定", role: .cancel) {}
                    }
                }
                
                // 时间戳
                Text("创建时间：\(updatedCard.timestamp, formatter: itemFormatter)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingEditSheet = true
                }) {
                    Image(systemName: "pencil")
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
