import SwiftUI
import AVFoundation

struct AudioRecordButton: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var showRecordingControls = false
    @State private var showDeleteConfirmation = false
    @Binding var audioData: Data?
    @Binding var audioFileName: String?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("录音")
                    .font(.title3.bold())
                    .foregroundColor(.black)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            if audioData != nil {
                // 已有录音
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                        Text(audioFileName ?? "录音文件")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("长按删除")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onLongPressGesture {
                        showDeleteConfirmation = true
                    }
                    .alert("删除录音", isPresented: $showDeleteConfirmation) {
                        Button("取消", role: .cancel) {}
                        Button("删除", role: .destructive) {
                            withAnimation {
                                audioData = nil
                                audioFileName = nil
                            }
                        }
                    } message: {
                        Text("确定要删除这段录音吗？此操作无法撤销。")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
                .padding(.horizontal)
            } else {
                // 无录音，显示录制按钮
                HStack {
                    Spacer()
                    
                    if !showRecordingControls {
                        // 开始录制按钮
                        Button(action: {
                            withAnimation {
                                showRecordingControls = true
                                audioRecorder.startRecording()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "mic.circle.fill")
                                    .font(.system(size: 22))
                                Text("开始录音")
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(
                                Capsule()
                                    .fill(Color.blue)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 5)
                            )
                        }
                    } else {
                        // 录音中控件
                        VStack(spacing: 12) {
                            // 音波动画
                            HStack(spacing: 3) {
                                ForEach(0..<10, id: \.self) { index in
                                    Rectangle()
                                        .fill(Color.red)
                                        .frame(width: 3, 
                                               height: 10 + CGFloat.random(in: 5...25) * audioRecorder.audioLevel)
                                        .cornerRadius(1.5)
                                }
                            }
                            .frame(height: 35)
                            .animation(.easeInOut(duration: 0.2), value: audioRecorder.audioLevel)
                            
                            // 计时器
                            Text(timeString(from: audioRecorder.recordingDuration))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            // 录音控制按钮
                            Button(action: {
                                if let url = audioRecorder.stopRecording() {
                                    do {
                                        let data = try Data(contentsOf: url)
                                        audioData = data
                                        audioFileName = "录音_\(Date().formatted(.dateTime.year().month().day().hour().minute()))"
                                        showRecordingControls = false
                                    } catch {
                                        print("无法读取录音数据: \(error)")
                                    }
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 60, height: 60)
                                        .shadow(color: Color.red.opacity(0.3), radius: 5)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white)
                                        .frame(width: 20, height: 20)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct AudioPlayButton: View {
    @StateObject private var audioPlayer = AudioPlayer()
    let audioData: Data?
    
    var body: some View {
        if let data = audioData {
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    Button(action: {
                        if audioPlayer.isPlaying {
                            audioPlayer.pause()
                        } else {
                            audioPlayer.play()
                        }
                    }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                    
                    // 进度条
                    ProgressView(value: audioPlayer.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                    
                    // 时间
                    Text(timeString(from: audioPlayer.duration * audioPlayer.progress))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 45, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .onAppear {
                audioPlayer.loadAudio(data: data)
            }
        } else {
            EmptyView()
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 