import Foundation
import UserNotifications
import SwiftUI

class ReminderManager: ObservableObject {
    static let shared = ReminderManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    @Published var pendingReminders: [MemoryCard] = []
    @Published var activeReminders: [MemoryCard] = []
    @Published var showingReminderAlert = false
    @Published var currentReminderCard: MemoryCard?
    
    private init() {
        // 请求通知权限
        requestNotificationPermission()
        
        // 设置定时检查
        setupPeriodicCheck()
    }
    
    // 请求通知权限
    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("请求通知权限失败: \(error.localizedDescription)")
                return
            }
            
            if granted {
                print("通知权限已授权")
            } else {
                print("通知权限被拒绝")
            }
        }
    }
    
    // 设置定时检查
    private func setupPeriodicCheck() {
        // 每分钟检查一次是否有需要提醒的事件
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkReminders()
        }
        
        // 立即执行一次检查
        checkReminders()
    }
    
    // 检查是否有需要提醒的事件
    func checkReminders() {
        Task {
            do {
                let cardStore = MemoryCardStore()
                try await cardStore.load()
                
                let cardsToRemind = cardStore.getCardsToRemind()
                
                if !cardsToRemind.isEmpty {
                    DispatchQueue.main.async {
                        self.pendingReminders = cardsToRemind
                        
                        // 将新的提醒添加到活动提醒列表
                        for card in cardsToRemind {
                            if !self.activeReminders.contains(where: { $0.id == card.id }) {
                                self.activeReminders.append(card)
                            }
                        }
                        
                        // 显示提醒通知
                        self.showReminders()
                        
                        // 如果没有正在显示的提醒对话框，则显示第一个提醒
                        if !self.showingReminderAlert && self.currentReminderCard == nil {
                            self.showNextReminder()
                        }
                    }
                    
                    // 更新最后通知时间
                    for card in cardsToRemind {
                        cardStore.updateLastNotifiedTime(for: card.id)
                    }
                }
            } catch {
                print("检查提醒时出错: \(error.localizedDescription)")
            }
        }
    }
    
    // 显示提醒通知
    private func showReminders() {
        for card in pendingReminders {
            // 创建本地通知
            let content = UNMutableNotificationContent()
            content.title = card.title
            content.body = card.reminderMessage.isEmpty ? "您有一个事件需要处理" : card.reminderMessage
            content.sound = .default
            
            // 设置通知类别，以便添加操作按钮
            content.categoryIdentifier = "REMINDER_CATEGORY"
            
            // 立即触发通知
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            
            // 创建请求
            let request = UNNotificationRequest(
                identifier: card.id.uuidString,
                content: content,
                trigger: trigger
            )
            
            // 添加通知请求
            notificationCenter.add(request) { error in
                if let error = error {
                    print("添加通知请求失败: \(error.localizedDescription)")
                }
            }
        }
        
        // 确保通知中心已设置好操作按钮
        setupNotificationActions()
    }
    
    // 设置通知操作按钮
    private func setupNotificationActions() {
        // 确认按钮
        let confirmAction = UNNotificationAction(
            identifier: "CONFIRM_ACTION",
            title: "确认",
            options: .foreground
        )
        
        // 稍后提醒按钮
        let remindLaterAction = UNNotificationAction(
            identifier: "REMIND_LATER_ACTION",
            title: "稍后提醒",
            options: .foreground
        )
        
        // 创建通知类别
        let reminderCategory = UNNotificationCategory(
            identifier: "REMINDER_CATEGORY",
            actions: [confirmAction, remindLaterAction],
            intentIdentifiers: [],
            options: []
        )
        
        // 注册通知类别
        notificationCenter.setNotificationCategories([reminderCategory])
    }
    
    // 显示下一个提醒对话框
    func showNextReminder() {
        if !activeReminders.isEmpty {
            currentReminderCard = activeReminders.first
            showingReminderAlert = true
        } else {
            currentReminderCard = nil
            showingReminderAlert = false
        }
    }
    
    // 确认提醒
    func confirmReminder(cardID: UUID) {
        activeReminders.removeAll { $0.id == cardID }
        currentReminderCard = nil
        showingReminderAlert = false
        
        // 延迟一下再显示下一个提醒，避免UI闪烁
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showNextReminder()
        }
    }
    
    // 稍后提醒
    func remindLater(cardID: UUID) {
        // 将该提醒移到列表末尾
        if let index = activeReminders.firstIndex(where: { $0.id == cardID }) {
            let card = activeReminders.remove(at: index)
            activeReminders.append(card)
        }
        
        currentReminderCard = nil
        showingReminderAlert = false
        
        // 延迟一下再显示下一个提醒，避免UI闪烁
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showNextReminder()
        }
    }
    
    // 清除特定提醒
    func clearReminder(cardID: UUID) {
        pendingReminders.removeAll { $0.id == cardID }
        activeReminders.removeAll { $0.id == cardID }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [cardID.uuidString])
        
        if currentReminderCard?.id == cardID {
            currentReminderCard = nil
            showingReminderAlert = false
            
            // 显示下一个提醒
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showNextReminder()
            }
        }
    }
    
    // 清除所有提醒
    func clearAllReminders() {
        pendingReminders.removeAll()
        activeReminders.removeAll()
        currentReminderCard = nil
        showingReminderAlert = false
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    // 为特定卡片设置提醒
    func scheduleReminder(for card: MemoryCard) {
        // 只处理启用了提醒的事件类型卡片
        guard card.type == .event && card.reminderEnabled, let reminderTime = card.reminderTime else {
            return
        }
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = card.title
        content.body = card.reminderMessage.isEmpty ? "您有一个事件需要处理" : card.reminderMessage
        content.sound = .default
        content.categoryIdentifier = "REMINDER_CATEGORY"
        
        // 根据提醒频率设置触发器
        var trigger: UNNotificationTrigger
        
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)
        
        switch card.reminderFrequency {
        case .once:
            // 仅一次，使用完整日期
            dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
        case .daily:
            // 每天，只使用小时和分钟
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
        case .weekly:
            // 每周，添加星期几
            dateComponents.weekday = calendar.component(.weekday, from: reminderTime)
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
        case .monthly:
            // 每月，添加日期
            dateComponents.day = calendar.component(.day, from: reminderTime)
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
        case .none:
            return
        }
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: card.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        // 添加通知请求
        notificationCenter.add(request) { error in
            if let error = error {
                print("添加通知请求失败: \(error.localizedDescription)")
            } else {
                print("成功为事件 '\(card.title)' 设置提醒")
            }
        }
        
        // 确保通知中心已设置好操作按钮
        setupNotificationActions()
    }
} 