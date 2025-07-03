import SwiftUI
import AVFoundation
import Speech

// 简化的语音识别器 - 避免所有复杂操作
class SimpleSpeechRecognizer: ObservableObject {
    @Published var text = ""
    @Published var isRecording = false
    
    // 获取用户输入的简化模拟实现
    func startRecording() {
        DispatchQueue.main.async {
            self.isRecording = true
            self.text = ""
            
            // 模拟识别过程
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.text = "正在识别中..."
            }
        }
    }
    
    func stopRecording() {
        DispatchQueue.main.async {
            self.isRecording = false
            self.text = "模拟的语音识别结果"
        }
    }
}

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
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 文字内容
            Text(text)
                .foregroundColor(.black)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: UIScreen.main.bounds.height / 5) // 改为屏幕高度的1/5
                .multilineTextAlignment(.leading)
            
            // 清空按钮 - 在识别过程中也显示
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.black)
                    .padding([.top, .trailing], 12)
            }
        }
        .background(Color.white.opacity(0.8))
        .animation(.easeInOut, value: !text.isEmpty)
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