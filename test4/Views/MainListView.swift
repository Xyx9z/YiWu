import SwiftUI

struct MainListView: View {
    @StateObject private var cardStore = MemoryCardStore()
    @State private var showingAddCard = false
    @State private var selectedCard: MemoryCard?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(cardStore.cards) { card in
                    CardRow(card: card)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCard = card
                        }
                }
                .onDelete(perform: deleteCards)
            }
            .navigationTitle("记忆卡片")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddCard = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddCard) {
                CardEditView(cardStore: cardStore)
            }
            .sheet(item: $selectedCard) { card in
                CardEditView(cardStore: cardStore, card: card)
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
    
    private func deleteCards(at offsets: IndexSet) {
        cardStore.cards.remove(atOffsets: offsets)
        Task {
            try? await cardStore.save()
        }
    }
}

struct CardRow: View {
    let card: MemoryCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text(card.title)
                .font(.headline)
            
            // 内容预览
            if !card.content.isEmpty {
                Text(card.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // 图片预览
            if !card.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(card.images.prefix(4)) { imageData in
                            if let uiImage = UIImage(data: imageData.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }
            
            // 时间戳
            Text(card.timestamp, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MainListView()
} 