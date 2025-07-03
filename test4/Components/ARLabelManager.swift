import UIKit
// import ARKit // 不再强依赖 ARKit

class BoundingBoxView: UIView {
    let titleLabel = UILabel()
    var objectID: String = ""
    var onLabelTapped: ((String) -> Void)?
    
    init(frame: CGRect, label: String, confidence: Float) {
        super.init(frame: frame)
        setup(label: label, confidence: confidence)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup(label: String, confidence: Float) {
        // 边框样式
        self.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.85).cgColor
        self.layer.borderWidth = 3.5
        self.layer.cornerRadius = 8.0
        self.layer.masksToBounds = true
        self.backgroundColor = UIColor.clear
        self.layer.shadowColor = UIColor.systemGreen.cgColor
        self.layer.shadowOpacity = 0.25
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowRadius = 6
        self.isUserInteractionEnabled = true
        // 关键：不裁剪子视图
        self.clipsToBounds = false
        // label样式
        titleLabel.text = "\(label)  \(String(format: "%.0f%%", confidence * 100))"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 15)
        titleLabel.textColor = UIColor.systemGreen
        titleLabel.backgroundColor = UIColor.white.withAlphaComponent(0.85)
        titleLabel.layer.cornerRadius = 6
        titleLabel.layer.masksToBounds = true
        titleLabel.textAlignment = .center
        titleLabel.sizeToFit()
        let labelHeight: CGFloat = 28
        let labelWidth = max(titleLabel.frame.width + 16, 60)
        // 微调y坐标，确保label在边框正上方且不会被裁剪
        titleLabel.frame = CGRect(x: (self.bounds.width-labelWidth)/2, y: 0, width: labelWidth, height: labelHeight)
        // 支持点击
        titleLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(labelTapped))
        titleLabel.addGestureRecognizer(tap)
        self.addSubview(titleLabel)
    }
    
    @objc private func labelTapped() {
        print("[BoundingBoxView] labelTapped 被触发, objectID: \(objectID)")
        onLabelTapped?(objectID)
    }
}

class ARLabelManager {
    private var detectedObjectBoxes: [String: BoundingBoxView] = [:]
    private let parentView: UIView
    // 新增：标签点击回调
    var onLabelTapped: ((String) -> Void)?
    
    init(parentView: UIView) {
        self.parentView = parentView
    }
    
    func clearAllBoundingBoxes() {
        detectedObjectBoxes.values.forEach { $0.removeFromSuperview() }
        detectedObjectBoxes.removeAll()
    }
    
    func addBoundingBox(for objectID: String, at boundingBox: CGRect, label: String, confidence: Float, baseRect: CGRect? = nil) {
        let viewRect: CGRect
        if let baseRect = baseRect {
            viewRect = baseRect
        } else if let imageView = parentView as? UIImageView, let imageFrame = imageView.imageFrame() {
            viewRect = imageFrame
        } else {
            viewRect = parentView.bounds
        }
        // 修正坐标映射逻辑
        let boxFrame = CGRect(
            x: viewRect.origin.x + boundingBox.origin.x * viewRect.width,
            y: viewRect.origin.y + (1 - boundingBox.origin.y - boundingBox.height) * viewRect.height,
            width: boundingBox.width * viewRect.width,
            height: boundingBox.height * viewRect.height
        )
        detectedObjectBoxes[objectID]?.removeFromSuperview()
        let boxView = BoundingBoxView(frame: boxFrame, label: label, confidence: confidence)
        boxView.objectID = objectID
        boxView.onLabelTapped = { [weak self] id in
            self?.onLabelTapped?(id)
        }
        boxView.alpha = 0
        UIView.animate(withDuration: 0.25) {
            boxView.alpha = 1
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