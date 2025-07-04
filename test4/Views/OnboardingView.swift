import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let image: String
    let title: String
    let description: String
}

struct OnboardingView: View {
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    
    // 定义所有页面的内容
    let pages: [OnboardingPage] = [
        OnboardingPage(
            image: "开屏图片",
            title: "记忆卡片",
            description: "随时随地，浏览记忆卡片。从卡片中找回物品的专属记忆。"
        ),
        OnboardingPage(
            image: "室内地图",
            title: "室内导航",
            description: "通过客制化的AR室内导航系统，轻松找到您的物品"
        ),
        OnboardingPage(
            image: "我的水杯",
            title: "智能物体识别",
            description: "运用AI技术，快速识别拍摄的物品"
        )
    ]
    
    var body: some View {
        VStack {
            // Skip 按钮
            HStack {
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Text("跳过")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            
            Spacer()
            
            // 使用TabView来实现滑动
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack {
                        Image(pages[index].image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250)
                            .padding(.bottom, 40)
                        
                        Text(pages[index].title)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text(pages[index].description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            Spacer()
            
            // 分页指示器
            HStack(spacing: 8) {
                ForEach(0..<pages.count) { index in
                    Circle()
                        .fill(index == currentPage ? Color.purple : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)
            
            // Get Started 按钮
            Button(action: {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    dismiss()
                }
            }) {
                Text(currentPage < pages.count - 1 ? "下一页" : "开始使用")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.white)
    }
}

#Preview {
    OnboardingView()
} 
