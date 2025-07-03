import SwiftUI

struct RecordButton: View {
    @Binding var isRecording: Bool
    let duration: TimeInterval
    
    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack {
            if isRecording {
                Text(formattedDuration)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.bottom, 4)
            }
            
            Image(systemName: "mic.fill")
                .font(.system(size: 24))
                .foregroundColor(isRecording ? .red : .white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.6))
                )
                .overlay(
                    Circle()
                        .stroke(isRecording ? Color.red : Color.white, lineWidth: 2)
                        .scaleEffect(isRecording ? 1.2 : 1.0)
                )
                .animation(.easeInOut(duration: 0.3), value: isRecording)
        }
    }
} 