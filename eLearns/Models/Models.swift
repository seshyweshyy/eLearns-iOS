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

enum WeatherCondition: String, Codable, CaseIterable, Identifiable {
    case fine, rain, snow, icy, fog
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .fine: return "sun.max.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .icy: return "snowflake"
        case .fog: return "cloud.fog.fill"
        }
    }
}

enum TrafficLevel: String, Codable, CaseIterable, Identifiable {
    case light, moderate, heavy
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .light: return "car"
        case .moderate: return "car.2"
        case .heavy: return "car.2.fill"
        }
    }
}

enum DriveFeel: String, Codable, CaseIterable, Identifiable {
    case awful, bad, meh, good, great
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .awful: return "hand.thumbsdown.fill"
        case .bad:   return "hand.thumbsdown"
        case .meh:   return "minus.circle.fill"
        case .good:  return "hand.thumbsup"
        case .great: return "hand.thumbsup.fill"
        }
    }
}

enum LogRoadType: String, Codable, CaseIterable, Identifiable {
    case sealed, unsealed, quietStreet, mainRoad, multiLaned
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .sealed:      return "Sealed"
        case .unsealed:    return "Unsealed"
        case .quietStreet: return "Quiet Street"
        case .mainRoad:    return "Main Road"
        case .multiLaned:  return "Multi-laned"
        }
    }
    var icon: String {
        switch self {
        case .sealed:      return "road.lanes"
        case .unsealed:    return "mountain.2"
        case .quietStreet: return "house"
        case .mainRoad:    return "light.beacon.max"
        case .multiLaned:  return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }
}

struct LogEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var startTime: Date = Date()
    var endTime: Date = Date().addingTimeInterval(1800)
    var startSuburb: String = ""
    var endSuburb: String = ""
    var startOdometer: Double = 0
    var endOdometer: Double = 0
    var isNight: Bool = false
    var supervisorName: String = ""
    var weather: WeatherCondition = .fine
    var roadTypes: Set<LogRoadType> = []
    var traffic: TrafficLevel = .light
    var feel: DriveFeel = .good
    var notes: String = ""
    var attachedRouteId: UUID?

    var durationMinutes: Int {
        max(0, Int(endTime.timeIntervalSince(startTime) / 60))
    }
    var distanceKm: Double {
        max(0, endOdometer - startOdometer)
    }
}
