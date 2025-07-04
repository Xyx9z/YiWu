//
//  ContentView.swift
//  test4
//
//  Created by student10 on 2025/7/2.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    @State private var showOnboarding = true  // 添加状态变量控制启动页显示
    
    // 添加初始化方法，设置全局TabBar外观
    init() {
        // 使用UIKit的方式设置全局TabBar外观
        let appearance = UITabBarAppearance()
        // 设置未选中图标颜色为不透明的灰色
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray.withAlphaComponent(1.0)
        // 设置选中图标颜色
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.blue
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // 确保图标始终不透明
        UITabBar.appearance().unselectedItemTintColor = UIColor.gray
        UITabBar.appearance().tintColor = UIColor.blue
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                MainListView()
                    .tabItem {
                        Label("记忆卡片", systemImage: "list.bullet")
                    }
                    .tag(0)
                
                IndoorNavigationView()
                    .tabItem {
                        Label("室内导航", systemImage: "map")
                    }
                    .tag(1)
                
                CameraView(tabSelected: selectedTab == 2)
                    .tabItem {
                        Label("摄像头", systemImage: "camera")
                    }
                    .tag(2)
            }
            
            // 添加分隔线
            VStack {
                Divider()
                    .background(Color.gray)
                    .frame(height: 0.5) // 非常细的线
                Spacer().frame(height: 49) // TabBar的高度
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
