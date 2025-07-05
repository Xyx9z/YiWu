//
//  ContentView.swift
//  test4
//
//  Created by student10 on 2025/7/2.
//

import SwiftUI
import CoreData

struct TabSelectionKey: EnvironmentKey {
    static var defaultValue: Binding<Int> = .constant(0)
}

extension EnvironmentValues {
    var tabSelection: Binding<Int> {
        get { self[TabSelectionKey.self] }
        set { self[TabSelectionKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    @State private var showOnboarding = true  // 添加状态变量控制启动页显示
    @EnvironmentObject private var reminderManager: ReminderManager

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
        ZStack {
            Color.white.ignoresSafeArea()
            TabView(selection: $selectedTab) {
                MainListView()
                    .tabItem {
                        Label("记忆卡片", systemImage: "list.bullet")
                    }
                    .tag(0)
                
                IndoorNavigationView()
                    .tabItem {
                        Label("寻物助手", systemImage: "map")
                    }
                    .tag(1)
                
                CameraView(tabSelected: selectedTab == 2)
                    .tabItem {
                        Label("物品识别", systemImage: "camera")
                    }
                    .tag(2)
            }
           .edgesIgnoringSafeArea(.bottom)
           .environment(\.tabSelection, $selectedTab)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .alert(item: reminderAlertItem) { alertItem in
            Alert(
                title: Text(alertItem.title),
                message: Text(alertItem.message),
                primaryButton: .default(Text("确认")) {
                    if let cardID = alertItem.cardID {
                        reminderManager.confirmReminder(cardID: cardID)
                    }
                },
                secondaryButton: .cancel(Text("稍后提醒")) {
                    if let cardID = alertItem.cardID {
                        reminderManager.remindLater(cardID: cardID)
                    }
                }
            )
        }
        .onAppear {
            // 应用启动时检查提醒
            reminderManager.checkReminders()
            
            // 设置通知监听器，用于从其他视图切换标签
            setupNotificationObservers()
        }
        .onDisappear {
            // 移除观察者
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // 设置通知监听器
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SwitchToNavigationTab"), 
            object: nil, 
            queue: .main
        ) { _ in
            // 切换到寻物助手标签页
            selectedTab = 1
        }
        
        // 添加物品识别标签页的通知监听器
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SwitchToObjectDetectionTab"),
            object: nil,
            queue: .main
        ) { _ in
            // 切换到物品识别标签页
            selectedTab = 2
        }
    }
    
    // 创建提醒对话框的绑定
    private var reminderAlertItem: Binding<ReminderAlertItem?> {
        Binding<ReminderAlertItem?>(
            get: {
                if reminderManager.showingReminderAlert, let card = reminderManager.currentReminderCard {
                    return ReminderAlertItem(
                        id: card.id.uuidString,
                        cardID: card.id,
                        title: card.title,
                        message: card.reminderMessage.isEmpty ? "您有一个事件需要处理" : card.reminderMessage
                    )
                }
                return nil
            },
            set: { _ in }
        )
    }
}

// 用于提醒对话框的可识别项
struct ReminderAlertItem: Identifiable {
    let id: String
    let cardID: UUID?
    let title: String
    let message: String
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
