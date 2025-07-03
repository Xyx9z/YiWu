import Foundation
import AVFoundation
import Accelerate

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: CGFloat = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    private var audioLevelTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.wav")
        print("录音文件路径：\(audioFilename.path)")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // 确保录音文件目录存在
            try FileManager.default.createDirectory(at: getDocumentsDirectory(), withIntermediateDirectories: true)
            
            // 如果已经存在录音文件，先删除
            if FileManager.default.fileExists(atPath: audioFilename.path) {
                try FileManager.default.removeItem(at: audioFilename)
            }
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            if audioRecorder?.record() == false {
                print("录音启动失败")
                return
            }
            
            print("开始录音")
            isRecording = true
            startTime = Date()
            
            // 开始计时
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if let start = self.startTime {
                    self.recordingDuration = Date().timeIntervalSince(start)
                    
                    // 检查是否超过30秒
                    if self.recordingDuration >= 30.0 {
                        self.stopRecording()
                    }
                }
            }
            
            // 更新音量级别
            audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateAudioLevel()
            }
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
            print("Error details: \(error)")
        }
    }
    
    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        guard isRecording, let recorder = audioRecorder else { return nil }
        
        let fileURL = recorder.url
        recorder.stop()
        isRecording = false
        recordingDuration = 0
        startTime = nil
        
        // 验证文件是否存在并且有效
        if FileManager.default.fileExists(atPath: fileURL.path) {
            print("录音文件已保存：\(fileURL.path)")
            return fileURL
        } else {
            print("录音文件未找到：\(fileURL.path)")
            return nil
        }
    }
    
    private func updateAudioLevel() {
        audioRecorder?.updateMeters()
        let level = audioRecorder?.averagePower(forChannel: 0) ?? -160
        // 将分贝值转换为0-1的范围
        let normalizedLevel = pow(10, level / 20)
        audioLevel = CGFloat(normalizedLevel)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        } else {
            print("Recording finished successfully")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error.localizedDescription)")
        }
    }
} 