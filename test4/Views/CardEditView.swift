import SwiftUI
import PhotosUI

struct CardEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cardStore: MemoryCardStore
    @State private var card: MemoryCard
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingImagePicker = false
    @State private var isLoading = false
    
    init(cardStore: MemoryCardStore, card: MemoryCard? = nil) {
        self.cardStore = cardStore
        _card = State(initialValue: card ?? MemoryCard())
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // 标题输入框
                TextField("输入卡片标题", text: $card.title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.headline)
                    .padding(.horizontal)
                
                // 内容编辑区
                TextEditor(text: $card.content)
                    .frame(height: 200)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                // 图片区域
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // 添加图片按钮
                        PhotosPicker(selection: $selectedItems,
                                   maxSelectionCount: 4,
                                   matching: .images) {
                            VStack {
                                Image(systemName: "plus.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                Text("添加图片")
                                    .font(.caption)
                            }
                            .frame(width: 100, height: 100)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // 已选图片预览
                        ForEach(card.images) { imageData in
                            if let uiImage = UIImage(data: imageData.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        Button(action: {
                                            deleteImage(imageData)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .padding(4)
                                        }
                                        .offset(x: 6, y: -6),
                                        alignment: .topTrailing
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 120)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCard()
                    }
                    .disabled(card.title.isEmpty)
                }
            }
            .onChange(of: selectedItems) { items in
                Task {
                    isLoading = true
                    var newImages: [ImageData] = []
                    
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            newImages.append(ImageData(imageData: data))
                        }
                    }
                    
                    card.images.append(contentsOf: newImages)
                    selectedItems = []
                    isLoading = false
                }
            }
            .overlay(
                Group {
                    if isLoading {
                        ProgressView("正在处理图片...")
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(8)
                    }
                }
            )
        }
    }
    
    private func deleteImage(_ image: ImageData) {
        if let index = card.images.firstIndex(where: { $0.id == image.id }) {
            card.images.remove(at: index)
        }
    }
    
    private func saveCard() {
        card.timestamp = Date()
        if let index = cardStore.cards.firstIndex(where: { $0.id == card.id }) {
            cardStore.cards[index] = card
        } else {
            cardStore.cards.append(card)
        }
        
        // 保存到本地存储
        Task {
            try? await cardStore.save()
        }
        
        dismiss()
    }
}

#Preview {
    CardEditView(cardStore: MemoryCardStore())
} 