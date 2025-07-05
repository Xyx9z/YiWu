import Foundation

struct TextMatchingService {
    // 文本标准化：去除标点、空格、换行
    static func normalizeText(_ text: String) -> String {
        // 移除标点符号
        let punctuationSet = CharacterSet.punctuationCharacters
        // 移除空白字符（包括空格和换行）
        let whitespaceSet = CharacterSet.whitespacesAndNewlines
        
        return text.components(separatedBy: punctuationSet)
            .joined()
            .components(separatedBy: whitespaceSet)
            .joined()
    }
    
    // 匹配文本与卡片
    static func findMatchingCards(transcribedText: String, cards: [MemoryCard]) -> [MemoryCard] {
        let normalizedTranscription = normalizeText(transcribedText)
        
        return cards.filter { card in
            let normalizedTitle = normalizeText(card.title)
            return normalizedTranscription.contains(normalizedTitle)
        }
    }
    
    // 匹配结果模型
    struct MatchResult {
        let card: MemoryCard
        let matchedText: String
        let confidence: Double
        
        // 计算匹配置信度（可以根据需要调整算法）
        static func calculateConfidence(normalizedTitle: String, normalizedTranscription: String) -> Double {
            guard !normalizedTitle.isEmpty else { return 0.0 }
            
            // 简单实现：根据标题在转写文本中的位置计算置信度
            // 如果标题出现在转写文本的开头，给予更高的置信度
            if normalizedTranscription.hasPrefix(normalizedTitle) {
                return 1.0
            }
            
            // 如果标题完整出现在转写文本中，给予中等置信度
            if normalizedTranscription.contains(normalizedTitle) {
                return 0.8
            }
            
            return 0.0
        }
    }
    
    // 带置信度的匹配查找
    static func findMatchingCardsWithConfidence(transcribedText: String, cards: [MemoryCard]) -> [MatchResult] {
        let normalizedTranscription = normalizeText(transcribedText)
        
        return cards.compactMap { card in
            let normalizedTitle = normalizeText(card.title)
            let confidence = MatchResult.calculateConfidence(
                normalizedTitle: normalizedTitle,
                normalizedTranscription: normalizedTranscription
            )
            
            // 只返回有匹配的结果
            if confidence > 0 {
                return MatchResult(
                    card: card,
                    matchedText: normalizedTitle,
                    confidence: confidence
                )
            }
            return nil
        }.sorted { $0.confidence > $1.confidence } // 按置信度降序排序
    }
    
    // 新增：检查是否包含"寻务助手"指令
    static func checkNavigationAssistantCommand(text: String) -> Bool {
        let normalizedText = normalizeText(text)
        
        // 检查多种可能的表达方式
        let commands = ["寻务助手", "打开寻务助手", "启动寻务助手", "进入寻务助手", "切换到寻务助手", "我要找东西"]
        
        for command in commands {
            let normalizedCommand = normalizeText(command)
            if normalizedText.contains(normalizedCommand) {
                return true
            }
        }
        
        return false
    }
    
    // 新增：检查是否包含"物品识别"指令
    static func checkObjectDetectionCommand(text: String) -> Bool {
        let normalizedText = normalizeText(text)
        
        // 检查多种可能的表达方式
        let commands = ["物品识别", "打开物品识别", "启动物品识别", "进入物品识别", "切换到物品识别", "识别物品", "扫描物品"]
        
        for command in commands {
            let normalizedCommand = normalizeText(command)
            if normalizedText.contains(normalizedCommand) {
                return true
            }
        }
        
        return false
    }
    
    // 新增：检查是否包含"编辑我的水杯"指令
    static func checkEditWaterBottleCommand(text: String) -> Bool {
        let normalizedText = normalizeText(text)
        
        // 检查多种可能的表达方式
        let commands = ["编辑我的水杯", "修改我的水杯", "更新我的水杯", "修改水杯信息", "编辑水杯卡片"]
        
        for command in commands {
            let normalizedCommand = normalizeText(command)
            if normalizedText.contains(normalizedCommand) {
                return true
            }
        }
        
        return false
    }
} 