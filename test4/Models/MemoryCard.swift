import SwiftUI

enum CardType: String, Codable {
    case item = "item"      // 物品
    case event = "event"    // 事件
}

enum ReminderFrequency: String, Codable, CaseIterable {
    case none = "none"      // 不提醒
    case once = "once"      // 仅一次
    case daily = "daily"    // 每天
    case weekly = "weekly"  // 每周
    case monthly = "monthly" // 每月
    
    var displayName: String {
        switch self {
        case .none: return "不提醒"
        case .once: return "仅一次"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .monthly: return "每月"
        }
    }
}

struct MemoryCard: Identifiable, Codable {
    var id: UUID
    var title: String
    var content: String
    var images: [ImageData]
    var timestamp: Date
    var type: CardType
    
    // 提醒相关属性
    var reminderEnabled: Bool = false
    var reminderTime: Date? = nil
    var reminderFrequency: ReminderFrequency = .none
    var reminderMessage: String = ""
    var lastNotified: Date? = nil  // 记录上次通知时间，用于避免重复通知
    
    init(id: UUID = UUID(), title: String = "", content: String = "", images: [ImageData] = [], timestamp: Date = Date(), type: CardType = .item) {
        self.id = id
        self.title = title
        self.content = content
        self.images = images
        self.timestamp = timestamp
        self.type = type
    }
}

struct ImageData: Identifiable, Codable {
    var id: UUID
    var imageData: Data
    
    init(id: UUID = UUID(), imageData: Data) {
        self.id = id
        self.imageData = imageData
    }
}

class MemoryCardStore: ObservableObject {
    @Published var cards: [MemoryCard] = []
    
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                  in: .userDomainMask,
                                  appropriateFor: nil,
                                  create: false)
        .appendingPathComponent("memorycards.data")
    }
    
    func load() async throws {
        let task = Task<[MemoryCard], Error> {
            let fileURL = try Self.fileURL()
            guard let data = try? Data(contentsOf: fileURL) else {
                return []
            }
            
            do {
                let cards = try JSONDecoder().decode([MemoryCard].self, from: data)
                return cards
            } catch {
                print("解码卡片数据时出错: \(error.localizedDescription)")
                return []
            }
        }
        
        let cards = try await task.value
        DispatchQueue.main.async {
            self.cards = cards
        }
    }
    
    func save() async throws {
        let task = Task {
            do {
                let data = try JSONEncoder().encode(cards)
                let outfile = try Self.fileURL()
                try data.write(to: outfile)
            } catch {
                print("保存卡片数据时出错: \(error.localizedDescription)")
                throw error
            }
        }
        _ = try await task.value
    }
    
    // 检查并返回需要提醒的卡片
    func getCardsToRemind() -> [MemoryCard] {
        let now = Date()
        let calendar = Calendar.current
        
        return cards.filter { card in
            // 只处理启用了提醒的事件类型卡片
            guard card.type == .event && card.reminderEnabled, let reminderTime = card.reminderTime else {
                return false
            }
            
            // 获取提醒时间的小时和分钟
            let reminderHour = calendar.component(.hour, from: reminderTime)
            let reminderMinute = calendar.component(.minute, from: reminderTime)
            
            // 获取当前时间的小时和分钟
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            
            // 检查是否应该提醒
            switch card.reminderFrequency {
            case .once:
                // 仅一次提醒，检查日期是否匹配且未通知过
                let sameDay = calendar.isDate(reminderTime, inSameDayAs: now)
                let timeMatches = reminderHour == currentHour && reminderMinute == currentMinute
                let notNotifiedYet = card.lastNotified == nil
                return sameDay && timeMatches && notNotifiedYet
                
            case .daily:
                // 每天提醒，检查小时和分钟是否匹配
                let timeMatches = reminderHour == currentHour && reminderMinute == currentMinute
                
                // 检查今天是否已经提醒过
                let notifiedToday = card.lastNotified != nil && calendar.isDate(card.lastNotified!, inSameDayAs: now)
                return timeMatches && !notifiedToday
                
            case .weekly:
                // 每周提醒，检查星期几、小时和分钟是否匹配
                let reminderWeekday = calendar.component(.weekday, from: reminderTime)
                let currentWeekday = calendar.component(.weekday, from: now)
                let timeMatches = reminderHour == currentHour && reminderMinute == currentMinute && reminderWeekday == currentWeekday
                
                // 检查本周是否已经提醒过
                let notifiedThisWeek = card.lastNotified != nil && 
                    calendar.isDate(card.lastNotified!, equalTo: now, toGranularity: .weekOfYear)
                return timeMatches && !notifiedThisWeek
                
            case .monthly:
                // 每月提醒，检查日期、小时和分钟是否匹配
                let reminderDay = calendar.component(.day, from: reminderTime)
                let currentDay = calendar.component(.day, from: now)
                let timeMatches = reminderHour == currentHour && reminderMinute == currentMinute && reminderDay == currentDay
                
                // 检查本月是否已经提醒过
                let notifiedThisMonth = card.lastNotified != nil && 
                    calendar.isDate(card.lastNotified!, equalTo: now, toGranularity: .month)
                return timeMatches && !notifiedThisMonth
                
            case .none:
                return false
            }
        }
    }
    
    // 更新卡片的最后通知时间
    func updateLastNotifiedTime(for cardID: UUID) {
        if let index = cards.firstIndex(where: { $0.id == cardID }) {
            cards[index].lastNotified = Date()
            Task {
                try? await save()
            }
        }
    }
} 