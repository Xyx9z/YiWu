import SwiftUI

struct MemoryCard: Identifiable, Codable {
    var id: UUID
    var title: String
    var content: String
    var images: [ImageData]
    var timestamp: Date
    
    init(id: UUID = UUID(), title: String = "", content: String = "", images: [ImageData] = [], timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.images = images
        self.timestamp = timestamp
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
            let cards = try JSONDecoder().decode([MemoryCard].self, from: data)
            return cards
        }
        let cards = try await task.value
        DispatchQueue.main.async {
            self.cards = cards
        }
    }
    
    func save() async throws {
        let task = Task {
            let data = try JSONEncoder().encode(cards)
            let outfile = try Self.fileURL()
            try data.write(to: outfile)
        }
        _ = try await task.value
    }
} 