import SwiftUI
import AVFoundation
import Speech


// 实际相机模型
class CameraModel: ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isReady = false
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    
    // 标记相机是否已经设置过
    private var isConfigured = false
    
    init() {
        // 在初始化时就检查权限并设置相机
        checkPermission()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                if status {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                self.alert = true
            }
        }
    }
    
    func setupCamera() {
        // 如果相机已经配置过，则不需要重新配置
        if isConfigured {
            DispatchQueue.main.async {
                self.isReady = true
                // 确保会话启动
                self.startSession()
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { // 改用更高优先级的队列
            do {
                // 重置会话
                self.session.beginConfiguration()
                
                // 清除现有输入和输出
                for input in self.session.inputs {
                    self.session.removeInput(input)
                }
                
                for output in self.session.outputs {
                    self.session.removeOutput(output)
                }
                
                // 获取视频捕捉设备
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                         for: .video, 
                                                         position: .back) else {
                    print("没有找到相机")
                    return
                }
                
                // 创建输入
                let input = try AVCaptureDeviceInput(device: device)
                
                // 检查输入和输出是否可以添加到会话
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                
                self.session.commitConfiguration()
                self.isConfigured = true
                
                DispatchQueue.main.async {
                    self.isReady = true
                    // 配置完成后立即启动会话
                    self.startSession()
                }
            } catch {
                print("相机设置错误：\(error.localizedDescription)")
            }
        }
    }
    
    func takePic() {
        // 拍照
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: PhotoCapture())
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in // 改用更高优先级的队列
            guard let self = self else { return }
            
            if !self.session.isRunning {
                self.session.startRunning()
                print("相机会话已启动")
            }
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in // 改用更高优先级的队列
            guard let self = self else { return }
            
            if self.session.isRunning {
                self.session.stopRunning()
                print("相机会话已停止")
            }
        }
    }
    
    // 完全重启相机会话
    func restartSession() {
        stopSession()
        // 延迟一下再启动，避免潜在的冲突
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.startSession()
            print("相机会话已重启")
        }
    }
}

// 相机代理
class PhotoCapture: NSObject, AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("拍照错误：\(error.localizedDescription)")
            return
        }
        
        // 处理照片
        print("拍照成功")
    }
}

// 相机预览层
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // 确保相机已经初始化
        if !camera.session.isRunning {
            camera.startSession()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 确保预览层尺寸正确
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.frame
        }
    }
}

struct TranscriptionView: View {
    let text: String
    let isTranscribing: Bool
    var onClear: () -> Void
    
    // 动画状态
    @State private var animateText = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部指示条
            Rectangle()
                .fill(isTranscribing ? Color.blue : Color.green)
                .frame(height: 4)
                .animation(.easeInOut, value: isTranscribing)
            
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    // 状态指示
                    HStack(spacing: 8) {
                        // 录音/转写状态图标
                        Image(systemName: isTranscribing ? "waveform" : "text.bubble")
                            .foregroundColor(isTranscribing ? .blue : .green)
                            .font(.system(size: 16, weight: .semibold))
                            .opacity(animateText && isTranscribing ? 0.5 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true),
                                value: animateText
                            )
                        
                        // 状态文本
                        Text(isTranscribing ? "正在识别..." : "识别结果")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isTranscribing ? .blue : .green)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    
                    // 分隔线
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                    
                    // 文字内容
                    ScrollView {
                        Text(text)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .frame(maxHeight: UIScreen.main.bounds.height / 5)
                }
                
                // 清空按钮
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 22, height: 22)
                        .foregroundColor(.gray)
                        .background(Circle().fill(Color.white))
                        .padding([.top, .trailing], 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, y: 2)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.3), value: !text.isEmpty)
        .onAppear {
            animateText = isTranscribing
            
            // 如果不在转写状态，则设置2.5秒后自动关闭
            if !isTranscribing && !text.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    onClear()
                }
            }
        }
        .onChange(of: isTranscribing) { newValue in
            animateText = newValue
            
            // 当转写完成且有文本时，设置2.5秒后自动关闭
            if !newValue && !text.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    onClear()
                }
            }
        }
    }
}

struct ARObjectDetectionContainer: UIViewControllerRepresentable {
    var tabSelected: Bool

    func makeUIViewController(context: Context) -> ARObjectDetectionViewController {
        let vc = ARObjectDetectionViewController()
        return vc
    }

    func updateUIViewController(_ uiViewController: ARObjectDetectionViewController, context: Context) {
        // 根据tabSelected控制AR会话的启动和暂停
        if tabSelected {
            uiViewController.startARSession()
        } else {
            uiViewController.pauseARSession()
        }
    }
}

struct CameraView: View {
    var tabSelected: Bool
    
    var body: some View {
        ARObjectDetectionContainer(tabSelected: tabSelected)
            .ignoresSafeArea()
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(tabSelected: true)
    }
}
