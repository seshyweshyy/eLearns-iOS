import Foundation
import CoreLocation
import GoogleMaps
import Combine

class RouteService: ObservableObject {

    static let shared = RouteService()

    private let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
    private let baseURL = "https://maps.googleapis.com/maps/api/directions/json"

    // MARK: - Generate route from preferences

    func generateRoutes(
        from origin: CLLocationCoordinate2D,
        preferences: RoutePreferences,
        count: Int = 3
    ) async throws -> [GeneratedRoute] {

        var routes: [GeneratedRoute] = []

        for _ in 0..<count {
            // Build intermediate waypoints based on preferences
            let waypoints = buildWaypoints(
                origin: origin,
                preferences: preferences
            )

            let route = try await fetchRoute(
                origin: origin,
                destination: preferences.isLoop ? origin : (preferences.waypoints.last?.coordinate ?? origin),
                waypoints: waypoints,
                preferences: preferences
            )
            routes.append(route)
        }

        return routes
    }

    // MARK: - Fetch a single route from Directions API

    func fetchRoute(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D] = [],
        preferences: RoutePreferences
    ) async throws -> GeneratedRoute {

        var components = URLComponents(string: baseURL)!

        let originStr = "\(origin.latitude),\(origin.longitude)"
        let destStr   = "\(destination.latitude),\(destination.longitude)"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "origin",      value: originStr),
            URLQueryItem(name: "destination", value: destStr),
            URLQueryItem(name: "mode",        value: "driving"),
            URLQueryItem(name: "key",         value: apiKey),
            URLQueryItem(name: "region",      value: "au"),
            URLQueryItem(name: "units",       value: "metric"),
        ]

        if !waypoints.isEmpty {
            let wpStr = "optimize:true|" + waypoints.map {
                "\($0.latitude),\($0.longitude)"
            }.joined(separator: "|")
            queryItems.append(URLQueryItem(name: "waypoints", value: wpStr))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw RouteError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RouteError.networkError
        }

        let decoded = try JSONDecoder().decode(DirectionsResponse.self, from: data)

        guard decoded.status == "OK", let leg = decoded.routes.first?.legs.first else {
            throw RouteError.noRouteFound(decoded.status)
        }

        // Parse steps
        let steps = (decoded.routes.first?.legs ?? []).flatMap { $0.steps }.map { step -> RouteStep in
            RouteStep(
                instruction: step.html_instructions.strippingHTML(),
                distanceMetres: Double(step.distance.value),
                durationSeconds: Double(step.duration.value),
                maneuverType: step.maneuver ?? "straight",
                startLocation: CoordPair(latitude: step.start_location.lat, longitude: step.start_location.lng),
                endLocation: CoordPair(latitude: step.end_location.lat, longitude: step.end_location.lng),
                polylinePoints: step.polyline.points
            )
        }

        let totalDistance = Double(leg.distance.value) / 1000.0
        let totalDuration = Double(leg.duration.value) / 60.0

        return GeneratedRoute(
            distanceKm: totalDistance,
            durationMinutes: totalDuration,
            polylinePoints: decoded.routes.first?.overview_polyline.points ?? "",
            steps: steps,
            waypoints: preferences.waypoints,
            startCoordinate: CoordPair(origin),
            endCoordinate: CoordPair(destination),
            preferences: preferences
        )
    }

    // MARK: - Build intermediate waypoints based on road type preferences

    private func buildWaypoints(
        origin: CLLocationCoordinate2D,
        preferences: RoutePreferences
    ) -> [CLLocationCoordinate2D] {
        // Generate bearing-spread waypoints at varying distances
        // to create loop diversity. In a full implementation this
        // would use the Places API to find roads matching the
        // selected road types.
        let radius = preferences.radiusKm * 0.6
        let bearings = [45.0, 135.0, 225.0, 315.0]
        let selectedBearings = bearings.shuffled().prefix(
            preferences.selectedRoadTypes.count > 2 ? 3 : 2
        )

        return selectedBearings.map { bearing in
            let latOffset  = (radius / 111.0) * cos(bearing * .pi / 180)
            let lngOffset  = (radius / (111.0 * cos(origin.latitude * .pi / 180))) * sin(bearing * .pi / 180)
            return CLLocationCoordinate2D(
                latitude:  origin.latitude  + latOffset,
                longitude: origin.longitude + lngOffset
            )
        }
    }

    // MARK: - Decode polyline to coordinates

    func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        GMSPath(fromEncodedPath: encoded)?.coordinates() ?? []
    }
}

// MARK: - Errors

enum RouteError: LocalizedError {
    case invalidURL
    case networkError
    case noRouteFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "Invalid URL"
        case .networkError:      return "Network error — check your connection"
        case .noRouteFound(let s): return "No route found (\(s))"
        }
    }
}

// MARK: - Directions API response models

struct DirectionsResponse: Codable {
    let status: String
    let routes: [DirectionsRoute]
}

struct DirectionsRoute: Codable {
    let overview_polyline: EncodedPolyline
    let legs: [DirectionsLeg]
}

struct DirectionsLeg: Codable {
    let distance: ValueText
    let duration: ValueText
    let steps: [DirectionsStep]
    let start_location: LatLng
    let end_location: LatLng
}

struct DirectionsStep: Codable {
    let html_instructions: String
    let distance: ValueText
    let duration: ValueText
    let start_location: LatLng
    let end_location: LatLng
    let polyline: EncodedPolyline
    let maneuver: String?
}

struct ValueText: Codable {
    let value: Int
    let text: String
}

struct LatLng: Codable {
    let lat: Double
    let lng: Double
}

struct EncodedPolyline: Codable {
    let points: String
}

// MARK: - GMSPath extension

extension GMSPath {
    func coordinates() -> [CLLocationCoordinate2D] {
        (0..<count()).map { coordinate(at: $0) }
    }
}

// MARK: - HTML stripping

extension String {
    func strippingHTML() -> String {
        guard let data = data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return (try? NSAttributedString(data: data, options: options, documentAttributes: nil))?.string ?? self
    }
}
