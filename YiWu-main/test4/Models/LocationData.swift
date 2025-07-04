import Foundation
import CoreLocation
import CoreData

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
    
    func addDestination(name: String, latitude: Double, longitude: Double, notes: String = "") {
        let destination = Destination(context: context)
        destination.id = UUID()
        destination.name = name
        destination.latitude = latitude
        destination.longitude = longitude
        destination.notes = notes
        destination.timestamp = Date()
        
        save()
        fetchDestinations()
    }
    
    func updateDestination(_ destination: Destination, name: String, latitude: Double, longitude: Double, notes: String) {
        destination.name = name
        destination.latitude = latitude
        destination.longitude = longitude
        destination.notes = notes
        
        save()
        fetchDestinations()
    }
    
    func deleteDestination(_ destination: Destination) {
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