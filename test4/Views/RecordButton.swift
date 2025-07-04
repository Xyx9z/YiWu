import SwiftUI

struct RecordButton: View {
    @Binding var isRecording: Bool
    @Binding var audioLevel: CGFloat
    @Binding var recordingDuration: TimeInterval
    var onTap: () -> Void
    
    private var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // 录音时长显示
            if isRecording {
                Text(formattedDuration)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
            }
            
            // 麦克风按钮
            Button(action: onTap) {
                ZStack {
                    // 波纹动画 - 当录音时显示
                    if isRecording {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(Color.red.opacity(0.5), lineWidth: 2)
                                .scaleEffect(1.0 + CGFloat(i) * 0.3 + audioLevel * 0.5)
                                .opacity(0.8 - Double(i) * 0.2 - Double(audioLevel) * 0.2)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: false).delay(Double(i) * 0.2), value: audioLevel)
                        }
                    }
                    
                    // 主按钮
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "mic.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: isRecording ? Color.red.opacity(0.5) : Color.blue.opacity(0.5), radius: 8, x: 0, y: 4)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
} 