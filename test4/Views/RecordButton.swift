import SwiftUI

struct RecordButton: View {
    @Binding var isRecording: Bool
    @Binding var audioLevel: CGFloat
    @Binding var recordingDuration: TimeInterval
    var onTap: () -> Void
    
    // 渐变色定义
    private let gradientStart = Color(red: 0.1, green: 0.2, blue: 0.9)
    private let gradientEnd = Color(red: 0.3, green: 0.5, blue: 1.0)
    private let recordingColor = Color.red
    
    // 动画状态
    @State private var pulseAnimation = false
    @State private var scaleAnimation = false
    
    private var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // 拆分波纹视图为单独的组件
    private func waveCircle(index: Int) -> some View {
        let opacity = 0.3 - Double(index) * 0.1
        let scale = pulseAnimation ? 1.0 + CGFloat(index) * 0.4 + audioLevel * 0.5 : 1.0
        let circleOpacity = pulseAnimation ? 0.2 : 0.8
        let animationDuration = 1.2
        let animationDelay = Double(index) * 0.2
        
        return Circle()
            .stroke(recordingColor.opacity(opacity), lineWidth: 2)
            .scaleEffect(scale)
            .opacity(circleOpacity)
            .animation(
                Animation.easeInOut(duration: animationDuration)
                    .repeatForever(autoreverses: false)
                    .delay(animationDelay),
                value: pulseAnimation
            )
    }
    
    // 拆分时长指示器为单独的组件
    private func durationIndicator() -> some View {
        VStack {
            Spacer()
            
            Text(formattedDuration)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                )
                .offset(y: 70)
        }
    }
    
    // 拆分按钮背景为单独的组件
    private func buttonBackground() -> some View {
        let fillContent: AnyShapeStyle = isRecording ? 
            AnyShapeStyle(recordingColor) : 
            AnyShapeStyle(
                LinearGradient(
                    gradient: Gradient(colors: [gradientStart, gradientEnd]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        
        let shadowColor = isRecording ? 
            recordingColor.opacity(0.5) : 
            gradientEnd.opacity(0.5)
        
        return Circle()
            .fill(fillContent)
            .frame(width: 60, height: 60)
            .shadow(
                color: shadowColor,
                radius: 10,
                x: 0,
                y: 5
            )
            .scaleEffect(scaleAnimation ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: scaleAnimation)
    }
    
    // 拆分按钮图标为单独的组件
    private func buttonIcon() -> some View {
        let iconName = isRecording ? "stop.fill" : "mic.fill"
        let fontSize = isRecording ? 20 : 24
        
        return Image(systemName: iconName)
            .font(.system(size: CGFloat(fontSize), weight: .bold))
            .foregroundColor(.white)
            .symbolEffect(.pulse, options: .repeating, value: isRecording)
    }
    
    // 拆分录音指示器为单独的组件
    private func recordingIndicator() -> some View {
        Circle()
            .stroke(Color.white.opacity(0.8), lineWidth: 3)
            .frame(width: 68, height: 68)
    }
    
    var body: some View {
        ZStack {
            // 录音时的波纹动画效果
            if isRecording {
                // 外圈波纹
                ForEach(0..<3, id: \.self) { i in
                    waveCircle(index: i)
                }
                
                // 时长指示器
                durationIndicator()
            }
            
            // 主按钮
            Button(action: onTap) {
                ZStack {
                    // 按钮背景
                    buttonBackground()
                    
                    // 麦克风图标
                    buttonIcon()
                    
                    // 录音中的动态指示器
                    if isRecording {
                        recordingIndicator()
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(width: 80, height: 80)
        .onAppear {
            pulseAnimation = true
        }
        .onChange(of: isRecording) { newValue in
            withAnimation {
                scaleAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scaleAnimation = false
                }
            }
        }
    }
}

// 按钮按下效果
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
} 