//
//  test4App.swift
//  test4
//
//  Created by student10 on 2025/7/2.
//

import SwiftUI
import UserNotifications

@main
struct test4App: App {
    let persistenceController = PersistenceController.shared
    private let queue = DispatchQueue(label: "com.speech.recognizer")
    @StateObject private var reminderManager = ReminderManager.shared
    
    // 添加通知中心代理
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        UITabBar.appearance().backgroundColor = UIColor.white
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(reminderManager)
                .onAppear {
                    // 应用启动时检查提醒
                    reminderManager.checkReminders()
                }
        }
    }
}

// 应用代理，处理通知
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // 设置通知代理
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // 应用处于前台时收到通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 即使应用在前台也显示通知
        completionHandler([.banner, .sound, .badge])
    }
    
    // 用户点击通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // 处理用户点击通知的行为
        let notificationID = response.notification.request.identifier
        print("用户点击了通知: \(notificationID)")
        
        // 根据用户选择的操作处理提醒
        switch response.actionIdentifier {
        case "CONFIRM_ACTION":
            // 用户确认了提醒
            if let uuid = UUID(uuidString: notificationID) {
                ReminderManager.shared.confirmReminder(cardID: uuid)
            }
            
        case "REMIND_LATER_ACTION":
            // 用户选择稍后提醒
            if let uuid = UUID(uuidString: notificationID) {
                ReminderManager.shared.remindLater(cardID: uuid)
            }
            
        default:
            // 用户直接点击了通知（没有选择特定操作）
            if let uuid = UUID(uuidString: notificationID) {
                // 在应用内显示提醒对话框
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let cardStore = MemoryCardStore()
                    Task {
                        try? await cardStore.load()
                        if let card = cardStore.cards.first(where: { $0.id.uuidString == notificationID }) {
                            DispatchQueue.main.async {
                                ReminderManager.shared.activeReminders.append(card)
                                if !ReminderManager.shared.showingReminderAlert {
                                    ReminderManager.shared.showNextReminder()
                                }
                            }
                        }
                    }
                }
            }
        }
        
        completionHandler()
    }
}
