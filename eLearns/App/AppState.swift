import SwiftUI
import CoreLocation
import Combine

enum AppTab {
    case map, logbook, routes, profile
}

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var displayName: String {
        switch self {
        case .system: return "Match System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

class AppState: ObservableObject {

    // MARK: - Tab
    @Published var selectedTab: AppTab = .map

    // MARK: - Theme (stored in UserDefaults, published so views update)
    @Published var theme: AppTheme = {
        let raw = UserDefaults.standard.string(forKey: "el_theme") ?? "system"
        return AppTheme(rawValue: raw) ?? .system
    }() {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "el_theme")
        }
    }

    // MARK: - User
    @Published var profile = UserProfile()

    // MARK: - Routes
    @Published var savedRoutes: [SavedRoute] = []
    @Published var currentRoute: GeneratedRoute? = nil
    @Published var isNavigating: Bool = false

    // MARK: - Logbook
    @Published var logEntries: [LogEntry] = []

    // MARK: - Location
    @Published var userLocation: CLLocationCoordinate2D? = nil

    // MARK: - Persistence keys
    private let routesKey  = "el_saved_routes"
    private let logsKey    = "el_log_entries"
    private let profileKey = "el_profile"

    init() {
        loadAll()
    }

    // MARK: - Persistence

    func saveAll() {
        if let data = try? JSONEncoder().encode(savedRoutes) {
            UserDefaults.standard.set(data, forKey: routesKey)
        }
        if let data = try? JSONEncoder().encode(logEntries) {
            UserDefaults.standard.set(data, forKey: logsKey)
        }
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    private func loadAll() {
        if let data = UserDefaults.standard.data(forKey: routesKey),
           let decoded = try? JSONDecoder().decode([SavedRoute].self, from: data) {
            savedRoutes = decoded
        }
        if let data = UserDefaults.standard.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) {
            logEntries = decoded
        }
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        }
    }

    // MARK: - Logbook helpers

    func addLogEntry(_ entry: LogEntry) {
        logEntries.insert(entry, at: 0)
        saveAll()
    }

    func totalDayMinutes() -> Int {
        logEntries.filter { !$0.isNight }.reduce(0) { $0 + $1.durationMinutes }
        + profile.initialDayMinutes
    }

    func totalNightMinutes() -> Int {
        logEntries.filter { $0.isNight }.reduce(0) { $0 + $1.durationMinutes }
        + profile.initialNightMinutes
    }

    // MARK: - Route helpers

    func saveRoute(_ route: GeneratedRoute, name: String) {
        let saved = SavedRoute(id: UUID(), name: name, route: route, savedAt: Date())
        savedRoutes.insert(saved, at: 0)
        saveAll()
    }

    func deleteRoute(at offsets: IndexSet) {
        savedRoutes.remove(atOffsets: offsets)
        saveAll()
    }
}
