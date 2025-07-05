import UIKit
// import ARKit // 不再强依赖 ARKit

class BoundingBoxView: UIView {
    let titleLabel = UILabel()
    var objectID: String = ""
    var onLabelTapped: ((String) -> Void)?
    var onLabelLongPressed: ((String) -> Void)?
    
    init(frame: CGRect, label: String, confidence: Float) {
        super.init(frame: frame)
        setup(label: label, confidence: confidence)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup(label: String, confidence: Float) {
        // 根据置信度调整颜色
        let boxColor: UIColor
        if confidence >= 0.8 {
            boxColor = UIColor.systemGreen
        } else if confidence >= 0.6 {
            boxColor = UIColor.systemYellow
        } else {
            boxColor = UIColor.systemOrange
        }
        
        // 改进的边框样式
        self.layer.borderColor = boxColor.withAlphaComponent(0.85).cgColor
        self.layer.borderWidth = 3.5
        self.layer.cornerRadius = 10.0
        self.layer.masksToBounds = true
        self.backgroundColor = UIColor.clear
        
        // 添加半透明背景使边框更加明显
        let backgroundView = UIView(frame: self.bounds)
        backgroundView.backgroundColor = boxColor.withAlphaComponent(0.15)
        backgroundView.layer.cornerRadius = 10.0
        self.insertSubview(backgroundView, at: 0)
        
        // 增强边框视觉效果
        self.layer.shadowColor = boxColor.cgColor
        self.layer.shadowOpacity = 0.4
        self.layer.shadowOffset = CGSize(width: 0, height: 3)
        self.layer.shadowRadius = 8
        self.isUserInteractionEnabled = true
        
        // 关键：不裁剪子视图
        self.clipsToBounds = false
        
        // 改进的label样式
        // 仅在高置信度时显示百分比
        let displayText = confidence >= 0.65 ? 
            "\(label)  \(String(format: "%.0f%%", confidence * 100))" : 
            label
        
        titleLabel.text = displayText
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = boxColor
        
        // 给标签添加渐变背景
        titleLabel.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        titleLabel.layer.cornerRadius = 8
        titleLabel.layer.masksToBounds = true
        titleLabel.textAlignment = .center
        titleLabel.sizeToFit()
        
        // 调整标签尺寸，使其更加明显
        let labelHeight: CGFloat = 32
        let labelWidth = max(titleLabel.frame.width + 20, 70)
        
        // 微调y坐标，确保label在边框正上方且不会被裁剪
        titleLabel.frame = CGRect(x: (self.bounds.width-labelWidth)/2, y: -8, width: labelWidth, height: labelHeight)
        
        // 添加阴影效果使标签更加醒目
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.3
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        // 支持点击
        titleLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(labelTapped))
        titleLabel.addGestureRecognizer(tap)
        self.addSubview(titleLabel)
        
        // 增加整个边框的点击手势
        let boxTap = UITapGestureRecognizer(target: self, action: #selector(labelTapped))
        self.addGestureRecognizer(boxTap)
        
        // 添加长按手势
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(labelLongPressed))
        longPress.minimumPressDuration = 0.8 // 设置长按时间为0.8秒
        self.addGestureRecognizer(longPress)
        
        // 为标签也添加长按手势
        let labelLongPress = UILongPressGestureRecognizer(target: self, action: #selector(labelLongPressed))
        labelLongPress.minimumPressDuration = 0.8
        titleLabel.addGestureRecognizer(labelLongPress)
    }
    
    @objc private func labelTapped() {
        print("[BoundingBoxView] labelTapped 被触发, objectID: \(objectID)")
        onLabelTapped?(objectID)
    }
    
    @objc private func labelLongPressed(_ gesture: UILongPressGestureRecognizer) {
        // 只在手势开始时触发一次
        if gesture.state == .began {
            print("[BoundingBoxView] labelLongPressed 被触发, objectID: \(objectID)")
            onLabelLongPressed?(objectID)
            
            // 添加触觉反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
}

class ARLabelManager {
    private var detectedObjectBoxes: [String: BoundingBoxView] = [:]
    private let parentView: UIView
    // 标签点击回调
    var onLabelTapped: ((String) -> Void)?
    // 新增：标签长按回调
    var onLabelLongPressed: ((String) -> Void)?
    
    init(parentView: UIView) {
        self.parentView = parentView
    }
    
    func clearAllBoundingBoxes() {
        detectedObjectBoxes.values.forEach { $0.removeFromSuperview() }
        detectedObjectBoxes.removeAll()
    }
    
    // 保存上一次检测结果，用于平滑过渡
    private var lastBoundingBoxes: [String: CGRect] = [:]
    private var smoothingFactor: CGFloat = 0.7 // 平滑因子，越高平滑效果越强
    
    func addBoundingBox(for objectID: String, at boundingBox: CGRect, label: String, confidence: Float, baseRect: CGRect? = nil) {
        let viewRect: CGRect
        if let baseRect = baseRect {
            viewRect = baseRect
        } else if let imageView = parentView as? UIImageView, let imageFrame = imageView.imageFrame() {
            viewRect = imageFrame
        } else {
            viewRect = parentView.bounds
        }
        
        // 获取当前界面方向
        let isPortrait: Bool
        if #available(iOS 15.0, *) {
            let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            let orientation = windowScene?.interfaceOrientation ?? .portrait
            isPortrait = orientation == .portrait || orientation == .portraitUpsideDown
        } else {
            let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
            isPortrait = orientation == .portrait || orientation == .portraitUpsideDown
        }
        
        // 修正坐标映射逻辑
        var boxFrame = CGRect(
            x: viewRect.origin.x + boundingBox.origin.x * viewRect.width,
            y: viewRect.origin.y + boundingBox.origin.y * viewRect.height,
            width: boundingBox.width * viewRect.width,
            height: boundingBox.height * viewRect.height
        )
        
        // 应用平滑处理，减少边界框抖动
        if let lastBox = lastBoundingBoxes[objectID] {
            // 使用插值平滑过渡
            boxFrame = CGRect(
                x: lastBox.origin.x * smoothingFactor + boxFrame.origin.x * (1 - smoothingFactor),
                y: lastBox.origin.y * smoothingFactor + boxFrame.origin.y * (1 - smoothingFactor),
                width: lastBox.width * smoothingFactor + boxFrame.width * (1 - smoothingFactor),
                height: lastBox.height * smoothingFactor + boxFrame.height * (1 - smoothingFactor)
            )
        }
        
        // 保存当前边界框位置，用于下次平滑
        lastBoundingBoxes[objectID] = boxFrame
        
        // 检查是否已存在该物体的边界框
        if let existingBox = detectedObjectBoxes[objectID] {
            // 平滑过渡动画更新边界框位置
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                existingBox.frame = boxFrame
            } completion: { _ in
                // 更新标签内容，但保持位置平滑
                if let boxView = self.detectedObjectBoxes[objectID] as? BoundingBoxView {
                    // 只在必要时重新创建视图
                    if abs(existingBox.frame.width - boxFrame.width) > 30 ||
                       abs(existingBox.frame.height - boxFrame.height) > 30 {
                        existingBox.removeFromSuperview()
                        self.createNewBoxView(objectID: objectID, boxFrame: boxFrame, label: label, confidence: confidence)
                    }
                }
            }
        } else {
            // 创建新的边界框视图
            createNewBoxView(objectID: objectID, boxFrame: boxFrame, label: label, confidence: confidence)
        }
    }
    
    private func createNewBoxView(objectID: String, boxFrame: CGRect, label: String, confidence: Float) {
        let boxView = BoundingBoxView(frame: boxFrame, label: label, confidence: confidence)
        boxView.objectID = objectID
        boxView.onLabelTapped = { [weak self] id in
            self?.onLabelTapped?(id)
        }
        boxView.onLabelLongPressed = { [weak self] id in
            self?.onLabelLongPressed?(id)
        }
        boxView.alpha = 0
        boxView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: []) {
            boxView.alpha = 1
            boxView.transform = .identity
        }
        
        parentView.addSubview(boxView)
        detectedObjectBoxes[objectID] = boxView
    }
    
    func getCustomName(for objectID: String) -> String? {
        let customNames = UserDefaults.standard.dictionary(forKey: "CustomObjectNames") as? [String: String]
        return customNames?[objectID]
    }
    
    func saveCustomName(_ name: String, for objectID: String) {
        var customNames = UserDefaults.standard.dictionary(forKey: "CustomObjectNames") as? [String: String] ?? [:]
        customNames[objectID] = name
        UserDefaults.standard.set(customNames, forKey: "CustomObjectNames")
    }
    
    func refreshBoundingBox(for objectID: String, confidence: Float) {
        if let box = detectedObjectBoxes[objectID] {
            box.removeFromSuperview()
            detectedObjectBoxes.removeValue(forKey: objectID)
        }
        let boundingBox = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
        let label = getCustomName(for: objectID) ?? objectID
        addBoundingBox(for: objectID, at: boundingBox, label: label, confidence: confidence)
    }
}

// MARK: - UIImageView 辅助扩展
extension UIImageView {
    func imageFrame() -> CGRect? {
        guard let image = self.image else { return nil }
        let imageRatio = image.size.width / image.size.height
        let viewRatio = self.bounds.width / self.bounds.height
        if imageRatio > viewRatio {
            // 图片宽度撑满
            let width = self.bounds.width
            let height = width / imageRatio
            let y = (self.bounds.height - height) / 2
            return CGRect(x: 0, y: y, width: width, height: height)
        } else {
            // 图片高度撑满
            let height = self.bounds.height
            let width = height * imageRatio
            let x = (self.bounds.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: height)
        }
    }
} 
