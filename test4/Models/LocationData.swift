import Foundation
import CoreLocation
import CoreData
import SwiftUI

struct LocationData {
    var coordinate: CLLocationCoordinate2D
    var name: String
    var description: String?
    
    init(coordinate: CLLocationCoordinate2D, name: String, description: String? = nil) {
        self.coordinate = coordinate
        self.name = name
        self.description = description
    }
}

// 目的地图片管理器
class DestinationImageManager {
    static let shared = DestinationImageManager()
    private let userDefaults = UserDefaults.standard
    private let imagePrefix = "destination_image_"
    
    private init() {}
    
    // 保存目的地的图片
    func saveImage(_ imageData: Data?, for destinationID: String) {
        guard let imageData = imageData else {
            // 如果没有图片数据，删除已有的
            userDefaults.removeObject(forKey: "\(imagePrefix)\(destinationID)")
            return
        }
        
        userDefaults.set(imageData, forKey: "\(imagePrefix)\(destinationID)")
    }
    
    // 获取目的地的图片
    func getImage(for destinationID: String) -> UIImage? {
        guard let imageData = userDefaults.data(forKey: "\(imagePrefix)\(destinationID)") else {
            return nil
        }
        return UIImage(data: imageData)
    }
    
    // 删除目的地的图片
    func removeImage(for destinationID: String) {
        userDefaults.removeObject(forKey: "\(imagePrefix)\(destinationID)")
    }
}

@MainActor
class DestinationStore: ObservableObject {
    private let context: NSManagedObjectContext
    @Published private(set) var destinations: [Destination] = []
    
    init(context: NSManagedObjectContext) {
        self.context = context
        fetchDestinations()
    }
    
    private func fetchDestinations() {
        let request = NSFetchRequest<Destination>(entityName: "Destination")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Destination.timestamp, ascending: false)]
        
        do {
            destinations = try context.fetch(request)
        } catch {
            print("Error fetching destinations: \(error)")
        }
    }
    
    func addDestination(name: String, latitude: Double, longitude: Double, notes: String = "", imageData: Data? = nil) {
        let destination = Destination(context: context)
        destination.id = UUID()
        destination.name = name
        destination.latitude = latitude
        destination.longitude = longitude
        destination.notes = notes
        destination.timestamp = Date()
        
        // 如果提供了图片数据，保存它
        if let imageData = imageData, let id = destination.id?.uuidString {
            DestinationImageManager.shared.saveImage(imageData, for: id)
        }
        
        save()
        fetchDestinations()
    }
    
    func updateDestination(_ destination: Destination, name: String, latitude: Double, longitude: Double, notes: String, imageData: Data? = nil) {
        destination.name = name
        destination.latitude = latitude
        destination.longitude = longitude
        destination.notes = notes
        
        // 更新图片数据
        if let id = destination.id?.uuidString {
            DestinationImageManager.shared.saveImage(imageData, for: id)
        }
        
        save()
        fetchDestinations()
    }
    
    func deleteDestination(_ destination: Destination) {
        // 删除关联的图片
        if let id = destination.id?.uuidString {
            DestinationImageManager.shared.removeImage(for: id)
        }
        
        context.delete(destination)
        save()
        fetchDestinations()
    }
    
    private func save() {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
} 