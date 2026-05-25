import Foundation
import CoreLocation
import GoogleMaps
import Combine

class RouteService: ObservableObject {

    static let shared = RouteService()

    @Published var generationProgress: Double = 0 // 0.0 to 1.0

    private let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
    private let osrmEndpoints = [
        "https://router.project-osrm.org/route/v1/driving/",
        "https://routing.openstreetmap.de/routed-car/route/v1/driving/"
    ]

    // MARK: - Generate routes via OSRM

    func generateRoutes(
        from origin: CLLocationCoordinate2D,
        preferences: RoutePreferences,
        count: Int = 3
    ) async throws -> [GeneratedRoute] {

        let targetKm = (Double(preferences.durationMinutes) / 60.0) * 25.0
        let calcRad = targetKm / 2.5
        var shrink = min(calcRad / max(Double(preferences.radiusKm), 0.1), 0.98)
        shrink = max(shrink, 0.35)

        let baseAngle = Double.random(in: 0...(2 * .pi))
        var routes: [GeneratedRoute] = []
        var attempt = 0
        let maxAttempts = 28

        await MainActor.run { generationProgress = 0 }

        while routes.count < count && attempt < maxAttempts {
            attempt += 1
            await MainActor.run {
                generationProgress = Double(routes.count) / Double(count)
            }

            let wps = makeLoopWaypoints(
                origin: origin,
                preferences: preferences,
                shrink: shrink,
                attempt: attempt,
                baseAngle: baseAngle
            )

            guard let osrmRoute = try? await fetchOSRM(waypoints: [origin] + wps + [origin]) else {
                continue
            }

            let distKm = osrmRoute.distance / 1000.0
            let durMins = osrmRoute.duration / 60.0

            if distKm < 0.3 { continue }

            let isDup = routes.contains { abs($0.distanceKm - distKm) < 0.5 }
            if isDup { continue }

            let steps = parseOSRMSteps(osrmRoute)
            let polyline = encodePolyline(osrmRoute.geometry.coordinates)

            let route = GeneratedRoute(
                distanceKm: distKm,
                durationMinutes: durMins,
                polylinePoints: polyline,
                steps: steps,
                waypoints: preferences.waypoints,
                startCoordinate: CoordPair(origin),
                endCoordinate: CoordPair(origin),
                preferences: preferences
            )

            routes.append(route)

            // Adaptive shrink feedback
            let ratio = durMins / Double(preferences.durationMinutes)
            if ratio < 0.5 {
                shrink = min(shrink * (1.0 / ratio) * 0.7, 0.98)
            } else if ratio < 0.75 {
                shrink = min(shrink * 1.4, 0.98)
            } else if ratio > 1.5 {
                shrink *= 0.6
            } else if ratio > 1.2 {
                shrink *= 0.82
            }
        }

        if routes.isEmpty {
            throw RouteError.noRouteFound("Could not generate routes")
        }

        routes.sort { a, b in
            abs(a.durationMinutes - Double(preferences.durationMinutes)) < abs(b.durationMinutes - Double(preferences.durationMinutes))
        }

        await MainActor.run { generationProgress = 1.0 }

        return routes
    }

    // MARK: - Sample navigation waypoints from OSRM polyline for Google Navigation

    func navigationWaypoints(for route: GeneratedRoute, sampleCount: Int = 6) -> [CLLocationCoordinate2D] {
        guard let path = GMSPath(fromEncodedPath: route.polylinePoints) else {
            return route.waypoints.map { $0.coordinate }
        }
        let total = Int(path.count())
        guard total > 2 else { return [] }

        let count = min(sampleCount, total / 4)
        guard count > 0 else { return [] }

        let step = total / (count + 1)
        return (1...count).map { i in
            path.coordinate(at: UInt(i * step))
        }
    }

    // MARK: - OSRM fetch

    private func fetchOSRM(waypoints: [CLLocationCoordinate2D]) async throws -> OSRMRoute {
        let coords = waypoints.map { "\($0.longitude),\($0.latitude)" }.joined(separator: ";")

        for endpoint in osrmEndpoints {
            let urlString = "\(endpoint)\(coords)?overview=full&geometries=geojson&steps=true&continue_straight=false"
            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
                let decoded = try JSONDecoder().decode(OSRMResponse.self, from: data)
                guard decoded.code == "Ok", let route = decoded.routes.first else { continue }
                return route
            } catch {
                continue
            }
        }

        throw RouteError.noRouteFound("OSRM unavailable")
    }

    // MARK: - Loop waypoint generation (mirrors web makeLoopWps)

    private func makeLoopWaypoints(
        origin: CLLocationCoordinate2D,
        preferences: RoutePreferences,
        shrink: Double,
        attempt: Int,
        baseAngle: Double
    ) -> [CLLocationCoordinate2D] {

        let targetKm = (Double(preferences.durationMinutes) / 60.0) * 25.0
        let calcRad = targetKm / 2.5
        let useRad = min(calcRad, Double(preferences.radiusKm)) * shrink

        let prefCount = preferences.selectedRoadTypes.count
        let diff = max(1, min(5, prefCount))
        let waypointCount = min(2 + diff, 7)

        let dir: Double = attempt % 2 == 0 ? 1.0 : -1.0
        let sweepBase = 0.8 + Double(diff) * 0.25
        let sweep = Double.pi * (sweepBase + Double.random(in: 0...0.4))

        let prefIntensity = Double(prefCount) / 6.0
        let radMultiplier = 0.7 + prefIntensity * 0.6

        var waypoints: [CLLocationCoordinate2D] = []

        for j in 0..<waypointCount {
            let frac = Double(j + 1) / Double(waypointCount + 1)
            var angle = baseAngle + dir * sweep * frac
            if diff >= 4 {
                angle += Double.random(in: -0.3...0.3)
            }
            let dist = useRad * radMultiplier * Double.random(in: 0.5...1.0)
            let latOffset = (dist * sin(angle)) / 110.574
            let lngOffset = (dist * cos(angle)) / (111.320 * cos(origin.latitude * .pi / 180))

            waypoints.append(CLLocationCoordinate2D(
                latitude: origin.latitude + latOffset,
                longitude: origin.longitude + lngOffset
            ))
        }

        return waypoints
    }

    // MARK: - Parse OSRM steps

    private func parseOSRMSteps(_ route: OSRMRoute) -> [RouteStep] {
        return route.legs.flatMap { $0.steps }.map { step in
            let type = step.maneuver.type ?? "straight"
            let modifier = step.maneuver.modifier ?? ""
            let maneuverType = modifier.isEmpty ? type : "\(type)-\(modifier)"
            let loc = step.maneuver.location
            let coord = CoordPair(latitude: loc.count >= 2 ? loc[1] : 0,
                                  longitude: loc.count >= 2 ? loc[0] : 0)
            return RouteStep(
                instruction: step.name.isEmpty ? type.capitalized : step.name,
                distanceMetres: step.distance,
                durationSeconds: step.duration,
                maneuverType: maneuverType,
                startLocation: coord,
                endLocation: coord,
                polylinePoints: encodePolyline(step.geometry?.coordinates ?? [])
            )
        }
    }

    // MARK: - Encode GeoJSON [lon, lat] coords to Google encoded polyline

    func encodePolyline(_ coords: [[Double]]) -> String {
        var output = ""
        var prevLat = 0
        var prevLng = 0

        func encodeValue(_ value: Int) {
            var v = value < 0 ? ~(value << 1) : (value << 1)
            while v >= 0x20 {
                output.append(Character(UnicodeScalar((0x20 | (v & 0x1f)) + 63)!))
                v >>= 5
            }
            output.append(Character(UnicodeScalar(v + 63)!))
        }

        for coord in coords {
            guard coord.count >= 2 else { continue }
            let lat = Int(round(coord[1] * 1e5))
            let lng = Int(round(coord[0] * 1e5))
            encodeValue(lat - prevLat)
            encodeValue(lng - prevLng)
            prevLat = lat
            prevLng = lng
        }

        return output
    }

    // MARK: - Decode polyline

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
        case .invalidURL:              return "Invalid URL"
        case .networkError:            return "Network error — check your connection"
        case .noRouteFound(let s):     return "No route found (\(s))"
        }
    }
}

// MARK: - OSRM response models

struct OSRMResponse: Codable {
    let code: String
    let routes: [OSRMRoute]
}

struct OSRMRoute: Codable {
    let distance: Double
    let duration: Double
    let geometry: OSRMGeometry
    let legs: [OSRMLeg]
}

struct OSRMGeometry: Codable {
    let coordinates: [[Double]]
}

struct OSRMLeg: Codable {
    let steps: [OSRMStep]
}

struct OSRMStep: Codable {
    let distance: Double
    let duration: Double
    let name: String
    let maneuver: OSRMManeuver
    let geometry: OSRMGeometry?
}

struct OSRMManeuver: Codable {
    let location: [Double]
    let type: String?
    let modifier: String?
}

// MARK: - GMSPath extension

extension GMSPath {
    func coordinates() -> [CLLocationCoordinate2D] {
        (0..<count()).map { coordinate(at: $0) }
    }
}

// MARK: - HTML stripping (kept for any legacy use)

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
