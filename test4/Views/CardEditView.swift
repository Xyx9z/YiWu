import SwiftUI
import PhotosUI
import CoreData
import CoreLocation

// 辅助函数，用于判断设备类型
func isCompactDevice() -> Bool {
    // iPhone 14 Pro及类似尺寸设备的特殊处理
    return UIScreen.main.bounds.height < 900 && UIScreen.main.bounds.width < 500
}

// 辅助函数，计算主图片高度
func mainImageHeight() -> CGFloat {
    return isCompactDevice() ? min(UIScreen.main.bounds.height * 0.3, 240) : min(UIScreen.main.bounds.height * 0.35, 280)
}

// 主图片视图组件
struct MainImageView: View {
    let image: UIImage?
    let onTapImage: () -> Void
    let onSelectNewImage: (PhotosPickerItem?) -> Void
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = image {
                    GeometryReader { geo in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: mainImageHeight())
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture(perform: onTapImage)
                    }
                    .frame(height: mainImageHeight())
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: mainImageHeight())
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
                                                                .frame(width: isCompactDevice() ? 80 : min(UIScreen.main.bounds.width * 0.25, 100), 
                                               height: isCompactDevice() ? 80 : min(UIScreen.main.bounds.width * 0.25, 100))
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                    }
                    
                    ForEach(images.dropFirst()) { imageData in
                        if let uiImage = UIImage(data: imageData.imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: isCompactDevice() ? 80 : min(UIScreen.main.bounds.width * 0.25, 100), 
                                       height: isCompactDevice() ? 80 : min(UIScreen.main.bounds.width * 0.25, 100))
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
            .frame(height: isCompactDevice() ? 100 : min(UIScreen.main.bounds.height * 0.18, 120))
            .padding(.bottom, isCompactDevice() ? 4 : 8)
        }
    }
}

// 位置信息编辑组件
struct LocationEditView: View {
    @Binding var latitude: String
    @Binding var longitude: String
    @Binding var notes: String
    let cardTitle: String
    @Environment(\.managedObjectContext) private var viewContext
    @State private var existingDestination: Destination?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("位置信息")
                    .font(.title3.bold())
                    .foregroundColor(.black)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            VStack(spacing: 12) {
                // 纬度输入
                HStack {
                    Text("纬度:")
                        .font(.body)
                        .foregroundColor(.gray)
                        .frame(width: 60, alignment: .leading)
                    
                    TextField("纬度坐标", text: $latitude)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // 经度输入
                HStack {
                    Text("经度:")
                        .font(.body)
                        .foregroundColor(.gray)
                        .frame(width: 60, alignment: .leading)
                    
                    TextField("经度坐标", text: $longitude)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // 备注输入
                HStack {
                    Text("备注:")
                        .font(.body)
                        .foregroundColor(.gray)
                        .frame(width: 60, alignment: .leading)
                        .alignmentGuide(.leading) { d in d[.leading] }
                    
                    TextEditor(text: $notes)
                        .frame(height: isCompactDevice() ? 60 : min(UIScreen.main.bounds.height * 0.12, 80))
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }
        .onAppear {
            loadExistingDestination()
        }
    }
    
    private func loadExistingDestination() {
        let fetchRequest = NSFetchRequest<Destination>(entityName: "Destination")
        fetchRequest.predicate = NSPredicate(format: "name == %@", cardTitle.trimmingCharacters(in: .whitespacesAndNewlines))
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let destination = results.first {
                existingDestination = destination
                latitude = String(destination.latitude)
                longitude = String(destination.longitude)
                notes = destination.notes ?? ""
            }
        } catch {
            print("Error fetching destination: \(error)")
        }
    }
}

// 提醒设置组件
struct ReminderSettingsView: View {
    @Binding var reminderEnabled: Bool
    @Binding var reminderTime: Date
    @Binding var reminderFrequency: ReminderFrequency
    @Binding var reminderMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("提醒设置")
                    .font(.title3.bold())
                    .foregroundColor(.black)
                
                Spacer()
                
                Toggle("", isOn: $reminderEnabled)
                    .labelsHidden()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            if reminderEnabled {
                VStack(spacing: 12) {
                    // 提醒频率选择
                    HStack {
                        Text("频率:")
                            .font(.body)
                            .foregroundColor(.gray)
                            .frame(width: 60, alignment: .leading)
                        
                        Picker("提醒频率", selection: $reminderFrequency) {
                            ForEach(ReminderFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    // 提醒时间选择
                    HStack {
                        Text("时间:")
                            .font(.body)
                            .foregroundColor(.gray)
                            .frame(width: 60, alignment: .leading)
                        
                        DatePicker("", selection: $reminderTime, displayedComponents: reminderFrequency == .once ? [.date, .hourAndMinute] : [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    
                    // 提醒内容输入
                    VStack(alignment: .leading, spacing: 4) {
                        Text("提醒内容:")
                            .font(.body)
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $reminderMessage)
                            .frame(height: isCompactDevice() ? 60 : min(UIScreen.main.bounds.height * 0.12, 80))
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                Group {
                                    if reminderMessage.isEmpty {
                                        Text("输入提醒内容，例如\"上好喊妈妈\"")
                                            .foregroundColor(Color.gray.opacity(0.7))
                                            .padding(.leading, 8)
                                            .padding(.top, 8)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                .transition(.opacity)
                .animation(.easeInOut, value: reminderEnabled)
            }
        }
    }
}

struct CardEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ObservedObject var cardStore: MemoryCardStore
    @State private var card: MemoryCard
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mainImageItem: PhotosPickerItem?
    @State private var showingImagePicker = false
    @State private var isLoading = false
    @State private var isShowingFullScreenImage = false
    @State private var latitude: String = ""
    @State private var longitude: String = ""
    @State private var locationNotes: String = ""
    @State private var keyboardHeight: CGFloat = 0
    
    // 提醒相关状态
    @State private var reminderEnabled: Bool = false
    @State private var reminderTime: Date = Date()
    @State private var reminderFrequency: ReminderFrequency = .none
    @State private var reminderMessage: String = ""
    
    // 音频相关状态
    @State private var audioData: Data?
    @State private var audioFileName: String?
    
    init(cardStore: MemoryCardStore, card: MemoryCard? = nil, initialCardType: CardType = .item) {
        self.cardStore = cardStore
        if let existingCard = card {
            _card = State(initialValue: existingCard)
            _reminderEnabled = State(initialValue: existingCard.reminderEnabled)
            _reminderTime = State(initialValue: existingCard.reminderTime ?? Date())
            _reminderFrequency = State(initialValue: existingCard.reminderFrequency)
            _reminderMessage = State(initialValue: existingCard.reminderMessage)
            _audioData = State(initialValue: existingCard.audioData)
            _audioFileName = State(initialValue: existingCard.audioFileName)
        } else {
            _card = State(initialValue: MemoryCard(type: initialCardType))
        }
    }
    
    // 针对iPhone 14 Pro的优化尺寸
    private var contentSpacing: CGFloat {
        isCompactDevice() ? min(UIScreen.main.bounds.height * 0.02, 15) : min(UIScreen.main.bounds.height * 0.025, 20)
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: contentSpacing) {
                    // 主图片区域
                    MainImageView(
                        image: card.images.first.flatMap { UIImage(data: $0.imageData) },
                        onTapImage: { isShowingFullScreenImage = true },
                        onSelectNewImage: { item in mainImageItem = item }
                    )
                    
                    VStack(spacing: isCompactDevice() ? 12 : min(UIScreen.main.bounds.height * 0.02, 16)) {
                        // 卡片类型选择器
                        Picker("卡片类型", selection: $card.type) {
                            Text("物品").tag(CardType.item)
                            Text("事件").tag(CardType.event)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .onChange(of: card.type) { newType in
                            // 如果切换到物品类型，禁用提醒
                            if newType == .item {
                                reminderEnabled = false
                            }
                        }
                        
                        // 标题输入框
                        TextField("输入卡片标题", text: $card.title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: isCompactDevice() ? 24 : min(UIScreen.main.bounds.width * 0.06, 28)))
                            .frame(height: isCompactDevice() ? 50 : min(UIScreen.main.bounds.height * 0.07, 60))
                            .padding(.horizontal)
                        
                        // 内容编辑区
                        TextEditor(text: $card.content)
                            .frame(height: isCompactDevice() ? 80 : min(UIScreen.main.bounds.height * 0.15, 100))
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
                        
                        // 音频录制区域
                        AudioRecordButton(audioData: $audioData, audioFileName: $audioFileName)
                        
                        // 位置信息编辑区域
                        LocationEditView(
                            latitude: $latitude,
                            longitude: $longitude,
                            notes: $locationNotes,
                            cardTitle: card.title
                        )
                        
                        // 事件类型才显示提醒设置
                        if card.type == .event {
                            ReminderSettingsView(
                                reminderEnabled: $reminderEnabled,
                                reminderTime: $reminderTime,
                                reminderFrequency: $reminderFrequency,
                                reminderMessage: $reminderMessage
                            )
                        }
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
            .onAppear {
                loadExistingDestination()
                // 添加键盘通知观察器
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                        keyboardHeight = keyboardSize.height
                    }
                }
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    keyboardHeight = 0
                }
            }
            .onDisappear {
                // 移除键盘观察器
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
            }
            .onChange(of: card.title) { newTitle in
                loadExistingDestination()
            }
            // 添加额外的底部padding以防止内容被键盘遮挡
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 50 : 0)
        }
    }
    
    private func loadExistingDestination() {
        let fetchRequest = NSFetchRequest<Destination>(entityName: "Destination")
        fetchRequest.predicate = NSPredicate(format: "name == %@", card.title.trimmingCharacters(in: .whitespacesAndNewlines))
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let destination = results.first {
                latitude = String(destination.latitude)
                longitude = String(destination.longitude)
                locationNotes = destination.notes ?? ""
            }
        } catch {
            print("Error fetching destination: \(error)")
        }
    }
    
    private func deleteImage(_ image: ImageData) {
        if let index = card.images.firstIndex(where: { $0.id == image.id }) {
            card.images.remove(at: index)
        }
    }
    
    private func saveCard() {
        // 清理观察者
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // 检查是否是编辑现有卡片
        let isExistingCard = cardStore.cards.contains(where: { $0.id == card.id })
        
        // 只在创建新卡片时设置时间戳，编辑现有卡片时保留原时间戳
        if !isExistingCard {
            card.timestamp = Date()
        }
        
        // 保存提醒设置
        if card.type == .event {
            card.reminderEnabled = reminderEnabled
            card.reminderTime = reminderEnabled ? reminderTime : nil
            card.reminderFrequency = reminderEnabled ? reminderFrequency : .none
            card.reminderMessage = reminderEnabled ? reminderMessage : ""
        } else {
            card.reminderEnabled = false
            card.reminderTime = nil
            card.reminderFrequency = .none
            card.reminderMessage = ""
        }
        
        // 保存音频数据
        card.audioData = audioData
        card.audioFileName = audioFileName
        
        if let index = cardStore.cards.firstIndex(where: { $0.id == card.id }) {
            cardStore.cards[index] = card
        } else {
            cardStore.cards.append(card)
        }
        
        // 保存卡片对应的目的地信息
        saveDestination()
        
        Task {
            do {
                try await cardStore.save()
                
                // 如果启用了提醒，设置本地通知
                if card.type == .event && card.reminderEnabled {
                    ReminderManager.shared.scheduleReminder(for: card)
                }
            } catch {
                print("保存卡片失败: \(error.localizedDescription)")
            }
        }
        
        dismiss()
    }
    
    private func saveDestination() {
        guard !card.title.isEmpty,
              let lat = Double(latitude),
              let long = Double(longitude) else {
            return
        }
        
        let trimmedTitle = card.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fetchRequest = NSFetchRequest<Destination>(entityName: "Destination")
        fetchRequest.predicate = NSPredicate(format: "name == %@", trimmedTitle)
        
        // 获取卡片的第一张图片数据（如果有）
        let imageData = card.images.first?.imageData
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            let destination: Destination
            
            if let existingDestination = results.first {
                // 更新现有目的地
                destination = existingDestination
            } else {
                // 创建新目的地
                destination = Destination(context: viewContext)
                destination.id = UUID()
                destination.name = trimmedTitle
                destination.timestamp = Date()
            }
            
            destination.latitude = lat
            destination.longitude = long
            destination.notes = locationNotes
            
            try viewContext.save()
            
            // 保存图片到目的地
            if let id = destination.id?.uuidString {
                DestinationImageManager.shared.saveImage(imageData, for: id)
            }
        } catch {
            print("保存目的地失败: \(error)")
        }
    }
}

#Preview {
    CardEditView(cardStore: MemoryCardStore())
} 