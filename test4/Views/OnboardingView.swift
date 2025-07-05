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
            image: "启动页1",
            title: "记忆卡片",
            description: "随时随地，浏览记忆卡片。从卡片中找回物品的专属记忆。"
        ),
        OnboardingPage(
            image: "启动页2",
            title: "室内导航",
            description: "通过客制化的AR室内导航系统，轻松找到您的物品"
        ),
        OnboardingPage(
            image: "启动页3",
            title: "智能物体识别",
            description: "运用AI技术，快速识别拍摄的物品"
        ),
        OnboardingPage(
            image: "启动页4",
            title: "贴心服务",
            description: "专为阿尔茨海默病患者设计的记忆辅助功能"
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
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
            
            Spacer()
            
            // 使用TabView来实现滑动
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack {
                        Image(pages[index].image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .padding(.horizontal, 24)
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
            HStack(spacing: 12) {
                ForEach(0..<pages.count) { index in
                    let isCurrentPage = index == currentPage
                    let dotFill: AnyShapeStyle = isCurrentPage ? 
                        AnyShapeStyle(
                            LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]), 
                                         startPoint: .leading, 
                                         endPoint: .trailing)
                        ) : 
                        AnyShapeStyle(Color.gray.opacity(0.3))
                    let dotWidth = isCurrentPage ? 12.0 : 8.0
                    let dotScale = isCurrentPage ? 1.2 : 1.0
                    
                    Circle()
                        .fill(dotFill)
                        .frame(width: dotWidth, height: dotWidth)
                        .scaleEffect(dotScale)
                        .animation(.spring(), value: currentPage)
                }
            }
            .padding(.bottom, 28)
            
            // Get Started 按钮
            // 导航按钮
            NavigationButtonView(
                currentPage: $currentPage, 
                pagesCount: pages.count, 
                onFinish: { dismiss() }
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.95), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// 导航按钮组件
struct NavigationButtonView: View {
    @Binding var currentPage: Int
    let pagesCount: Int
    let onFinish: () -> Void
    
    private var isLastPage: Bool {
        currentPage == pagesCount - 1
    }
    
    var body: some View {
        Button(action: {
            if !isLastPage {
                withAnimation {
                    currentPage += 1
                }
            } else {
                onFinish()
            }
        }) {
            HStack {
                Text(isLastPage ? "开始使用" : "下一页")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Image(systemName: isLastPage ? "checkmark.circle" : "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple, Color.blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
            .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    OnboardingView()
}
