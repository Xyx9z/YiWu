import SwiftUI
import PhotosUI
import CoreData
import CoreLocation

// 主图片视图组件
struct MainImageView: View {
    let image: UIImage?
    let onTapImage: () -> Void
    let onSelectNewImage: (PhotosPickerItem?) -> Void
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: UIScreen.main.bounds.height * 0.4)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onTapImage)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: UIScreen.main.bounds.height * 0.4)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("添加封面图片")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        )
                }
            }
            .background(Color.white)
            
            // 编辑按钮
            PhotosPicker(selection: .init(get: { nil }, set: onSelectNewImage),
                        matching: .images) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .padding(8)
            }
        }
    }
}

// 附加图片视图组件
struct AdditionalImagesView: View {
    let images: [ImageData]
    let onSelectImages: ([PhotosPickerItem]) -> Void
    let onDeleteImage: (ImageData) -> Void
    let cardTitle: String
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("附加图片")
                    .font(.title3.bold())
                    .foregroundColor(.black)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    PhotosPicker(selection: .init(get: { [] }, set: onSelectImages),
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
                    
                    ForEach(images.dropFirst()) { imageData in
                        if let uiImage = UIImage(data: imageData.imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    Button(action: { onDeleteImage(imageData) }) {
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
            .padding(.bottom, 8)
        }
    }
}

struct CardEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var cardStore: MemoryCardStore
    @State private var card: MemoryCard
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mainImageItem: PhotosPickerItem?
    @State private var showingImagePicker = false
    @State private var isLoading = false
    @State private var isShowingFullScreenImage = false
    
    init(cardStore: MemoryCardStore, card: MemoryCard? = nil) {
        self.cardStore = cardStore
        _card = State(initialValue: card ?? MemoryCard())
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 主图片区域
                    MainImageView(
                        image: card.images.first.flatMap { UIImage(data: $0.imageData) },
                        onTapImage: { isShowingFullScreenImage = true },
                        onSelectNewImage: { item in mainImageItem = item }
                    )
                    
                    VStack(spacing: 16) {
                        // 标题输入框
                        TextField("输入卡片标题", text: $card.title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 32))
                            .frame(height: 60)
                            .padding(.horizontal)
                        
                        // 内容编辑区
                        TextEditor(text: $card.content)
                            .frame(height: 100)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        
                        // 附加图片区域
                        AdditionalImagesView(
                            images: card.images,
                            onSelectImages: { items in selectedItems = items },
                            onDeleteImage: deleteImage,
                            cardTitle: card.title
                        )
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("记忆卡片")
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCard()
                    }
                    .disabled(card.title.isEmpty)
                }
            }
            .onChange(of: selectedItems) { newItems in
                Task {
                    isLoading = true
                    var newImages: [ImageData] = []
                    
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            newImages.append(ImageData(imageData: data))
                        }
                    }
                    
                    card.images.append(contentsOf: newImages)
                    selectedItems = []
                    isLoading = false
                }
            }
            .onChange(of: mainImageItem) { newItem in
                Task {
                    isLoading = true
                    if let item = newItem,
                       let data = try? await item.loadTransferable(type: Data.self) {
                        let newImage = ImageData(imageData: data)
                        if card.images.isEmpty {
                            card.images.append(newImage)
                        } else {
                            card.images[0] = newImage
                        }
                    }
                    mainImageItem = nil
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
            .fullScreenCover(isPresented: $isShowingFullScreenImage) {
                if let firstImage = card.images.first,
                   let uiImage = UIImage(data: firstImage.imageData) {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    isShowingFullScreenImage = false
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(Color.red)
                                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                        )
                                }
                                .padding()
                            }
                            Spacer()
                        }
                    }
                    .statusBar(hidden: true)
                }
            }
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
        
        Task {
            do {
                try await cardStore.save()
            } catch {
                print("保存卡片失败: \(error.localizedDescription)")
            }
        }
        
        dismiss()
    }
}

#Preview {
    CardEditView(cardStore: MemoryCardStore())
} 