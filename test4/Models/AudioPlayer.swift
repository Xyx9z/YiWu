import Foundation
import AVFoundation

class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    func loadAudio(data: Data) {
        do {
            self.audioPlayer = try AVAudioPlayer(data: data)
            self.audioPlayer?.prepareToPlay()
            self.audioPlayer?.delegate = self
            self.duration = audioPlayer?.duration ?? 0
            self.progress = 0
        } catch {
            print("音频加载失败: \(error.localizedDescription)")
        }
    }
    
    func loadAudioFromFile(url: URL) {
        do {
            self.audioPlayer = try AVAudioPlayer(contentsOf: url)
            self.audioPlayer?.prepareToPlay()
            self.audioPlayer?.delegate = self
            self.duration = audioPlayer?.duration ?? 0
            self.progress = 0
        } catch {
            print("音频加载失败: \(error.localizedDescription)")
        }
    }
    
    func play() {
        setupAudioSession()
        
        guard let player = audioPlayer, !isPlaying else { return }
        
        player.play()
        isPlaying = true
        
        // 启动计时器更新进度
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.progress = player.currentTime / player.duration
        }
    }
    
    func pause() {
        guard isPlaying else { return }
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        progress = 0
        timer?.invalidate()
        timer = nil
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("设置音频会话失败: \(error)")
        }
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        progress = 0
        timer?.invalidate()
        timer = nil
    }
} 