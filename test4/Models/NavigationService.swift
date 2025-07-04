import Foundation
import CoreLocation
import ARKit

class NavigationService {
    static let shared = NavigationService()
    
    private var currentLocation: CLLocation?
    private var destination: LocationData?
    
    private init() {
        // 设置一个初始位置
        self.currentLocation = CLLocation(latitude: 31.2304, longitude: 121.4737)
    }
    
    func setDestination(_ destination: LocationData) {
        self.destination = destination
    }
    
    func setCurrentLocation(_ location: CLLocation) {
        self.currentLocation = location
    }
    
    func getNavigationInstructions() -> String {
        guard let dest = destination else {
            return "请选择目的地"
        }
        
        return "正在前往\(dest.name)"
    }
} 