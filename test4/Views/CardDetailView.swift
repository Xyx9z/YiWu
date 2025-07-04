import SwiftUI
import CoreData
import CoreLocation

struct CardDetailView: View {
    let card: MemoryCard
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageIndex: Int = 0
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingEditSheet = false
    @StateObject private var cardStore = MemoryCardStore()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部图片轮播
                if !card.images.isEmpty {
                    ZStack(alignment: .topTrailing) {
                        TabView(selection: $selectedImageIndex) {
                            ForEach(card.images.indices, id: \.self) { idx in
                                if let uiImage = UIImage(data: card.images[idx].imageData) {
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
                        if card.images.count > 1 {
                            Text("\(selectedImageIndex+1)/\(card.images.count)")
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
                    if card.images.count > 1 {
                        HStack(spacing: 7) {
                            ForEach(card.images.indices, id: \.self) { idx in
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
                Text(card.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 0)
                    .padding(.horizontal, 18)
                // 详细内容
                if !card.content.isEmpty {
                    Text(card.content)
                        .font(.system(size: 17))
                        .foregroundColor(Color(.label))
                        .lineSpacing(7)
                        .padding(.all, 18)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                }
                // 时间戳上方增加导航按钮
                Button(action: {
                    let fetchRequest = NSFetchRequest<Destination>(entityName: "Destination")
                    do {
                        let destinations = try viewContext.fetch(fetchRequest)
                        let matchingDestination = destinations.first { destination in
                            return destination.name?.trimmingCharacters(in: .whitespacesAndNewlines) == card.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if let destination = matchingDestination {
                            alertMessage = "正在导航到：\(card.title)"
                        } else {
                            alertMessage = "未检索到物品"
                        }
                        showAlert = true
                    } catch {
                        alertMessage = "检索目的地时出错"
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
                // 时间戳
                Text("创建时间：\(card.timestamp, formatter: itemFormatter)")
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
        .sheet(isPresented: $showingEditSheet) {
            CardEditView(cardStore: cardStore, card: card)
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}() 
