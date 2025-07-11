import SwiftUI
import PhotosUI
import CoreData
import CoreLocation
import UIKit

// 添加一个全局点击手势识别器到UIWindow
extension UIWindow {
    static func addTapGestureToHideKeyboard() {
        guard let window = UIApplication.shared.windows.first else { return }
        
        // 移除之前可能存在的手势识别器
        for recognizer in window.gestureRecognizers ?? [] {
            window.removeGestureRecognizer(recognizer)
        }
        
        // 添加新的手势识别器
        let tapGesture = UITapGestureRecognizer(target: window, action: #selector(UIWindow.endEditing))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = TapGestureDelegate.shared
        window.addGestureRecognizer(tapGesture)
        
        print("全局点击手势已添加到UIWindow")
    }
}

// 手势识别器代理，确保不干扰其他控件的点击事件
class TapGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = TapGestureDelegate()
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 如果点击的是UIControl（按钮等），不处理该点击事件
        if touch.view is UIControl {
            return false
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// 自定义TextField和TextView，点击空白区域自动隐藏键盘
class CustomUITextField: UITextField {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.resignFirstResponder()
        super.touchesBegan(touches, with: event)
    }
}

class CustomUITextView: UITextView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !self.isFirstResponder {
            self.superview?.touchesBegan(touches, with: event)
        }
        super.touchesBegan(touches, with: event)
    }
}

// 自定义TextField，支持点击空白区域隐藏键盘
struct CustomTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var font: UIFont = .systemFont(ofSize: 16)
    
    func makeUIView(context: Context) -> CustomUITextField {
        let textField = CustomUITextField(frame: .zero)
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.font = font
        textField.delegate = context.coordinator
        textField.backgroundColor = .clear
        return textField
    }
    
    func updateUIView(_ uiView: CustomUITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CustomTextField
        
        init(_ parent: CustomTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

// 自定义TextEditor，支持点击空白区域隐藏键盘
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont = .systemFont(ofSize: 16)
    
    func makeUIView(context: Context) -> CustomUITextView {
        let textView = CustomUITextView()
        textView.font = font
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        return textView
    }
    
    func updateUIView(_ uiView: CustomUITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

// 简单直接的键盘隐藏扩展
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

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
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
            .padding(.horizontal)
            
            // 编辑按钮
            PhotosPicker(selection: .init(get: { nil }, set: onSelectNewImage),
                        matching: .images) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 40, height: 40)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .padding([.bottom, .trailing], 16)
            }
        }
        .padding(.top, 12)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("附加图片", systemImage: "photo.stack.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                PhotosPicker(selection: .init(get: { [] }, set: onSelectImages),
                           maxSelectionCount: 4,
                           matching: .images) {
                    Label("添加", systemImage: "plus")
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .stroke(Color.blue, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(images.dropFirst()) { imageData in
                        if let uiImage = UIImage(data: imageData.imageData) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: isCompactDevice() ? 80 : min(UIScreen.main.bounds.width * 0.25, 100), 
                                           height: isCompactDevice() ? 80 : min(UIScreen.main.bounds.width * 0.25, 100))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                
                                Button(action: { onDeleteImage(imageData) }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 22, height: 22)
                                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                        
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 20))
                                    }
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    
                    if images.count <= 1 {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: isCompactDevice() ? 80 : min(UIScreen.main.bounds.width * 0.25, 100), 
                                   height: isCompactDevice() ? 80 : min(UIScreen.main.bounds.width * 0.25, 100))
                            .overlay(
                                Text("无附加图片")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: isCompactDevice() ? 100 : min(UIScreen.main.bounds.height * 0.18, 120))
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
        )
        .padding(.horizontal)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("位置信息", systemImage: "mappin.and.ellipse")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                // 纬度输入
                HStack {
                    Text("纬度:")
                        .font(.callout)
                        .foregroundColor(.gray)
                        .frame(width: 60, alignment: .leading)
                    
                    CustomTextField(
                        text: $latitude,
                        placeholder: "纬度坐标",
                        keyboardType: .decimalPad,
                        font: .systemFont(ofSize: 16)
                    )
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // 经度输入
                HStack {
                    Text("经度:")
                        .font(.callout)
                        .foregroundColor(.gray)
                        .frame(width: 60, alignment: .leading)
                    
                    CustomTextField(
                        text: $longitude,
                        placeholder: "经度坐标",
                        keyboardType: .decimalPad,
                        font: .systemFont(ofSize: 16)
                    )
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // 备注输入
                VStack(alignment: .leading, spacing: 6) {
                    Text("备注:")
                        .font(.callout)
                        .foregroundColor(.gray)
                    
                    CustomTextEditor(
                        text: $notes,
                        font: .systemFont(ofSize: 16)
                    )
                    .frame(height: isCompactDevice() ? 60 : min(UIScreen.main.bounds.height * 0.12, 80))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
        )
        .padding(.horizontal)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("提醒设置", systemImage: "bell.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $reminderEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .scaleEffect(0.85)
            }
            .padding(.horizontal)
            
            if reminderEnabled {
                VStack(spacing: 12) {
                    // 提醒频率选择
                    HStack {
                        Text("频率:")
                            .font(.callout)
                            .foregroundColor(.gray)
                            .frame(width: 60, alignment: .leading)
                        
                        Picker("提醒频率", selection: $reminderFrequency) {
                            ForEach(ReminderFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    // 提醒时间选择
                    HStack {
                        Text("时间:")
                            .font(.callout)
                            .foregroundColor(.gray)
                            .frame(width: 60, alignment: .leading)
                        
                        DatePicker("", selection: $reminderTime, displayedComponents: reminderFrequency == .once ? [.date, .hourAndMinute] : [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    
                    // 提醒内容输入
                    VStack(alignment: .leading, spacing: 6) {
                        Text("提醒内容:")
                            .font(.callout)
                            .foregroundColor(.gray)
                        
                        ZStack(alignment: .topLeading) {
                            CustomTextEditor(
                                text: $reminderMessage,
                                font: .systemFont(ofSize: 16)
                            )
                            .frame(height: isCompactDevice() ? 60 : min(UIScreen.main.bounds.height * 0.12, 80))
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            
                            if reminderMessage.isEmpty {
                                Text("输入提醒内容，例如\"上好喊妈妈\"")
                                    .foregroundColor(Color.gray.opacity(0.7))
                                    .font(.system(size: 16))
                                    .padding(16)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .transition(.opacity)
                .animation(.easeInOut, value: reminderEnabled)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
        )
        .padding(.horizontal)
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
        isCompactDevice() ? min(UIScreen.main.bounds.height * 0.02, 12) : min(UIScreen.main.bounds.height * 0.025, 16)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景层
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // 内容层
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: contentSpacing) {
                        // 主图片区域
                        MainImageView(
                            image: card.images.first.flatMap { UIImage(data: $0.imageData) },
                            onTapImage: { isShowingFullScreenImage = true },
                            onSelectNewImage: { item in mainImageItem = item }
                        )
                        
                        VStack(spacing: contentSpacing) {
                            // 卡片类型选择器
                            VStack(alignment: .leading, spacing: 8) {
                                Text("卡片类型")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                Picker("卡片类型", selection: $card.type) {
                                    Text("物品").tag(CardType.item)
                                    Text("事件").tag(CardType.event)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .padding(.horizontal)
                                .onChange(of: card.type) { newType in
                                    if newType == .item {
                                        reminderEnabled = false
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            // 标题输入区域
                            VStack(alignment: .leading, spacing: 8) {
                                Text("标题")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
                                    
                                    CustomTextField(
                                        text: $card.title, 
                                        placeholder: "输入卡片标题",
                                        font: .systemFont(ofSize: isCompactDevice() ? 20 : 22, weight: .medium)
                                    )
                                    .padding()
                                }
                                .padding(.horizontal)
                            }
                            
                            // 内容编辑区
                            VStack(alignment: .leading, spacing: 8) {
                                Text("内容")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                // 内容编辑区域
                                VStack {
                                    ZStack(alignment: .topLeading) {
                                        // 背景和框架
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemBackground))
                                            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
                                        
                                        // 内容编辑器 - 使用自定义TextEditor
                                        CustomTextEditor(
                                            text: $card.content,
                                            font: .systemFont(ofSize: 16)
                                        )
                                        .padding(12)
                                        
                                        // 占位符文本
                                        if card.content.isEmpty {
                                            Text("添加描述内容...")
                                                .foregroundColor(Color.gray.opacity(0.7))
                                                .font(.body)
                                                .padding(18)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }
                                .frame(height: isCompactDevice() ? 100 : min(UIScreen.main.bounds.height * 0.15, 120))
                                .padding(.horizontal)
                            }
                            
                            // 附加图片区域
                            AdditionalImagesView(
                                images: card.images,
                                onSelectImages: { items in selectedItems = items },
                                onDeleteImage: deleteImage,
                                cardTitle: card.title
                            )
                            
                            // 音频录制区域
                            VStack(alignment: .leading, spacing: 8) {
                                Label("语音记录", systemImage: "mic.fill")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                AudioRecordButton(audioData: $audioData, audioFileName: $audioFileName)
                                    .padding(.horizontal)
                            }
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
                            )
                            .padding(.horizontal)
                            
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
                            
                            // 底部间距
                            Spacer()
                                .frame(height: 30)
                        }
                    }
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 50 : 0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("取消")
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("记忆卡片")
                        .font(.headline)
                }
                
                // 保存按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // 键盘隐藏按钮
                        Button(action: {
                            hideKeyboard()
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundColor(.gray)
                        }
                        
                        // 保存按钮
                        Button(action: {
                            hideKeyboard()
                            if !card.title.isEmpty {
                                saveCard()
                            }
                        }) {
                            Text("保存")
                                .fontWeight(.medium)
                                .foregroundColor(card.title.isEmpty ? .gray : .blue)
                        }
                        .disabled(card.title.isEmpty)
                    }
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
                        LoadingOverlay()
                    }
                }
            )
            .fullScreenCover(isPresented: $isShowingFullScreenImage) {
                if let firstImage = card.images.first,
                   let uiImage = UIImage(data: firstImage.imageData) {
                    FullScreenImageView(image: uiImage, isPresented: $isShowingFullScreenImage)
                }
            }
            .onAppear {
                loadExistingDestination()
                // 添加全局点击手势
                UIWindow.addTapGestureToHideKeyboard()
                
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



// 加载指示器组件
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text("处理图片中...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
            )
        }
    }
}

// 全屏图像查看组件
struct FullScreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.7))
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

