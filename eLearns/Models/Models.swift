import Foundation
import CoreLocation

// MARK: - User Profile

struct UserProfile: Codable {
    var name: String = ""
    var licenceNumber: String = ""
    var licenceType: LicenceType = .learner
    var supervisorName: String = ""
    var initialDayMinutes: Int = 0
    var initialNightMinutes: Int = 0
}

enum LicenceType: String, Codable, CaseIterable {
    case learner = "L"
    case provisional = "P1"
    case provisional2 = "P2"

    var displayName: String {
        switch self {
        case .learner:      return "Learner (L)"
        case .provisional:  return "Provisional P1"
        case .provisional2: return "Provisional P2"
        }
    }

    var requiredHours: Int {
        switch self {
        case .learner:      return 120
        case .provisional:  return 0
        case .provisional2: return 0
        }
    }

    var requiredNightHours: Int {
        switch self {
        case .learner: return 20
        default:       return 0
        }
    }
}

// MARK: - Waypoint

struct Waypoint: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Road Types (for wizard)

enum RoadType: String, Codable, CaseIterable, Identifiable {
    case residential = "residential"
    case mainRoads   = "main-roads"
    case multiLane   = "multi-lane"
    case roundabouts = "roundabouts"
    case parking     = "parking"
    case hills       = "hills"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .residential: return "Residential"
        case .mainRoads:   return "Main Roads"
        case .multiLane:   return "Multi-Lane"
        case .roundabouts: return "Roundabouts"
        case .parking:     return "Parking"
        case .hills:       return "Hills"
        }
    }

    var subtitle: String {
        switch self {
        case .residential: return "Quiet suburban roads"
        case .mainRoads:   return "Arterial, traffic lights"
        case .multiLane:   return "Dual carriageways"
        case .roundabouts: return "Single & multi-lane"
        case .parking:     return "Reverse & angle"
        case .hills:       return "Steep grades"
        }
    }

    var systemImage: String {
        switch self {
        case .residential: return "house.fill"
        case .mainRoads:   return "road.lanes"
        case .multiLane:   return "arrow.up.and.down.and.arrow.left.and.right"
        case .roundabouts: return "arrow.clockwise"
        case .parking:     return "parkingsign"
        case .hills:       return "mountain.2.fill"
        }
    }

    var isRequired: Bool {
        switch self {
        case .residential, .mainRoads, .multiLane: return true
        default: return false
        }
    }
}

// MARK: - Route Wizard Preferences

struct RoutePreferences: Codable {
    var selectedRoadTypes: Set<RoadType> = [.residential, .mainRoads, .multiLane]
    var radiusKm: Double = 5.0
    var durationMinutes: Int = 60
    var isLoop: Bool = true
    var difficulty: Int = 2  // 1-3
    var waypoints: [Waypoint] = []
}

// MARK: - Generated Route

struct GeneratedRoute: Codable, Identifiable {
    var id: UUID = UUID()
    var distanceKm: Double
    var durationMinutes: Double
    var polylinePoints: String   // Encoded polyline from Google Directions
    var steps: [RouteStep]
    var waypoints: [Waypoint]
    var startCoordinate: CoordPair
    var endCoordinate: CoordPair
    var preferences: RoutePreferences
    var createdAt: Date = Date()
}

struct RouteStep: Codable, Identifiable {
    var id: UUID = UUID()
    var instruction: String
    var distanceMetres: Double
    var durationSeconds: Double
    var maneuverType: String    // "turn-left", "turn-right", "roundabout", etc.
    var startLocation: CoordPair
    var endLocation: CoordPair
    var polylinePoints: String
}

struct CoordPair: Codable {
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ coord: CLLocationCoordinate2D) {
        self.latitude = coord.latitude
        self.longitude = coord.longitude
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Saved Route

struct SavedRoute: Codable, Identifiable {
    var id: UUID
    var name: String
    var route: GeneratedRoute
    var savedAt: Date
}

// MARK: - Log Entry

struct LogEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var durationMinutes: Int
    var distanceKm: Double
    var isNight: Bool
    var supervisorName: String
    var roadTypes: [String]
    var notes: String
    var attachedRouteId: UUID?
}
