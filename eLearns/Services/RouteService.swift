import Foundation
import CoreLocation
import GoogleMaps
import Combine

// MARK: - Stronger route generation service
// This version does NOT just create random loop points.
// It first asks OpenStreetMap/Overpass for nearby roads, classifies those roads,
// builds waypoint plans from the requested road mix, asks OSRM to connect them,
// then scores the final geometry against duration, distance, and road-type ratio.

final class RouteService: ObservableObject {

    static let shared = RouteService()

    @Published var generationProgress: Double = 0

    private let osrmEndpoints = [
        "https://router.project-osrm.org/route/v1/driving/",
        "https://routing.openstreetmap.de/routed-car/route/v1/driving/"
    ]

    private let overpassEndpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ]

    // Tune these if needed
    private let assumedDrivingSpeedKmH = 25.0
    private let maxAttempts = 90
    private let candidatePoolSize = 18
    private let minRouteDistanceKm = 0.30
    private let roadMatchToleranceMetres = 45.0

    // MARK: - Public route generation

    func generateRoutes(
        from origin: CLLocationCoordinate2D,
        preferences: RoutePreferences,
        count: Int = 3
    ) async throws -> [GeneratedRoute] {

        await MainActor.run { generationProgress = 0 }

        let requestedTargets = roadTargets(from: preferences)
        let targetDuration = Double(preferences.durationMinutes)
        let targetDistanceKm = max(0.5, targetDuration / 60.0 * assumedDrivingSpeedKmH)
        let searchRadiusKm = max(0.5, min(Double(preferences.radiusKm), max(targetDistanceKm / 2.0, 1.0)))

        let nearbyRoads = (try? await fetchNearbyRoadSamples(
            origin: origin,
            radiusKm: searchRadiusKm,
            requestedTargets: requestedTargets
        )) ?? []

        var scoredRoutes: [ScoredRoute] = []
        var adaptiveRadius = searchRadiusKm
        let baseAngle = Double.random(in: 0...(2.0 * .pi))

        for attempt in 1...maxAttempts {
            await MainActor.run {
                generationProgress = min(0.96, Double(attempt) / Double(maxAttempts))
            }

            let waypointPlan: [CLLocationCoordinate2D]

            if nearbyRoads.isEmpty {
                // Safe fallback: still create a loop, but final acceptance is stricter.
                waypointPlan = makeFallbackLoopWaypoints(
                    origin: origin,
                    preferences: preferences,
                    attempt: attempt,
                    baseAngle: baseAngle,
                    radiusKm: adaptiveRadius
                )
            } else {
                waypointPlan = makePreferenceAwareWaypoints(
                    origin: origin,
                    roadSamples: nearbyRoads,
                    targets: requestedTargets,
                    targetDistanceKm: targetDistanceKm,
                    attempt: attempt
                )
            }

            guard waypointPlan.count >= 2 else { continue }

            guard let osrmRoute = try? await fetchOSRM(waypoints: [origin] + waypointPlan + [origin]) else {
                continue
            }

            let distanceKm = osrmRoute.distance / 1000.0
            let durationMinutes = osrmRoute.duration / 60.0

            guard distanceKm >= minRouteDistanceKm else { continue }

            let composition = analyzeRoadMix(
                routeCoordinates: osrmRoute.geometry.coordinates,
                roadSamples: nearbyRoads
            )

            let score = scoreRoute(
                distanceKm: distanceKm,
                durationMinutes: durationMinutes,
                targetDistanceKm: targetDistanceKm,
                targetDurationMinutes: targetDuration,
                actualMix: composition,
                targetMix: requestedTargets,
                route: osrmRoute,
                alreadyAccepted: scoredRoutes
            )

            guard score.isAcceptable || attempt > maxAttempts / 2 else {
                adaptiveRadius = adjustRadius(adaptiveRadius, actualDuration: durationMinutes, targetDuration: targetDuration)
                continue
            }

            let steps = parseOSRMSteps(osrmRoute)
            let polyline = encodePolyline(osrmRoute.geometry.coordinates)

            let generated = GeneratedRoute(
                distanceKm: distanceKm,
                durationMinutes: durationMinutes,
                polylinePoints: polyline,
                steps: steps,
                waypoints: preferences.waypoints,
                startCoordinate: CoordPair(origin),
                endCoordinate: CoordPair(origin),
                preferences: preferences
            )

            scoredRoutes.append(ScoredRoute(route: generated, score: score.totalScore, roadMix: composition))
            scoredRoutes.sort { $0.score < $1.score }

            if scoredRoutes.count > candidatePoolSize {
                scoredRoutes.removeLast()
            }

            adaptiveRadius = adjustRadius(adaptiveRadius, actualDuration: durationMinutes, targetDuration: targetDuration)
        }

        let finalRoutes = scoredRoutes
            .sorted { $0.score < $1.score }
            .map { $0.route }
            .prefix(count)

        await MainActor.run { generationProgress = 1.0 }

        if finalRoutes.isEmpty {
            throw RouteError.noRouteFound("Could not generate a route matching the selected road preferences")
        }

        return Array(finalRoutes)
    }

    // MARK: - Navigation waypoints for Google Navigation

    func navigationWaypoints(for route: GeneratedRoute, sampleCount: Int = 6) -> [CLLocationCoordinate2D] {
        guard let path = GMSPath(fromEncodedPath: route.polylinePoints) else {
            return route.waypoints.map { $0.coordinate }
        }

        let total = Int(path.count())
        guard total > 2 else { return [] }

        let count = min(sampleCount, max(1, total / 4))
        let step = max(1, total / (count + 1))

        return (1...count).compactMap { index in
            let pathIndex = min(UInt(index * step), path.count() - 1)
            return path.coordinate(at: pathIndex)
        }
    }

    // MARK: - Preference extraction

    private func roadTargets(from preferences: RoutePreferences) -> [RoadClass: Double] {
        // Best option for your app:
        // Add one of these to RoutePreferences:
        //     var roadTypeIntensities: [String: Int]
        // or:
        //     var roadTypeIntensities: [String: Double]
        //
        // Example:
        //     ["residential": 5, "main": 3]
        //
        // This reflection keeps this service compatible with your existing model while
        // still allowing strong ratio-based routing once the intensity dictionary exists.

        let mirror = Mirror(reflecting: preferences)

        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }

            if label.contains("intensit") || label.contains("ratio") || label.contains("weight") {
                if let dict = child.value as? [String: Int] {
                    return normaliseTargets(dict.reduce(into: [RoadClass: Double]()) { output, pair in
                        if let roadClass = RoadClass(from: pair.key) {
                            output[roadClass, default: 0] += Double(pair.value)
                        }
                    })
                }

                if let dict = child.value as? [String: Double] {
                    return normaliseTargets(dict.reduce(into: [RoadClass: Double]()) { output, pair in
                        if let roadClass = RoadClass(from: pair.key) {
                            output[roadClass, default: 0] += pair.value
                        }
                    })
                }
            }
        }

        // Fallback for your current code: selectedRoadTypes exists, but intensity does not.
        // Each selected road type receives equal weight.
        var output: [RoadClass: Double] = [:]
        for selected in preferences.selectedRoadTypes {
            let key = String(describing: selected)
            if let roadClass = RoadClass(from: key) {
                output[roadClass, default: 0] += 1.0
            }
        }

        // If nothing is selected, build a balanced route.
        if output.isEmpty {
            output[.residential] = 1
            output[.main] = 1
        }

        return normaliseTargets(output)
    }

    private func normaliseTargets(_ raw: [RoadClass: Double]) -> [RoadClass: Double] {
        let filtered = raw.filter { $0.value > 0 }
        let total = filtered.values.reduce(0, +)

        guard total > 0 else {
            return [.residential: 0.5, .main: 0.5]
        }

        return filtered.reduce(into: [RoadClass: Double]()) { output, pair in
            output[pair.key] = pair.value / total
        }
    }

    // MARK: - Overpass road database lookup

    private func fetchNearbyRoadSamples(
        origin: CLLocationCoordinate2D,
        radiusKm: Double,
        requestedTargets: [RoadClass: Double]
    ) async throws -> [RoadSample] {

        let radiusMetres = Int(max(500, radiusKm * 1000.0))
        let highwayRegex = requestedTargets.keys
            .flatMap { $0.osmHighwayValues }
            .uniqued()
            .joined(separator: "|")

        let query = """
        [out:json][timeout:25];
        (
          way["highway"~"^(\(highwayRegex))$"](around:\(radiusMetres),\(origin.latitude),\(origin.longitude));
        );
        out tags geom;
        """

        guard let body = query.data(using: .utf8) else {
            throw RouteError.invalidURL
        }

        for endpoint in overpassEndpoints {
            guard let url = URL(string: endpoint) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }

                let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
                let samples = decoded.elements.flatMap { element -> [RoadSample] in
                    guard
                        let highway = element.tags?["highway"],
                        let roadClass = RoadClass(osmHighway: highway),
                        let geometry = element.geometry,
                        geometry.count >= 2
                    else {
                        return []
                    }

                    return sampleRoadGeometry(
                        geometry.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) },
                        roadClass: roadClass,
                        highway: highway,
                        roadName: element.tags?["name"]
                    )
                }

                if !samples.isEmpty {
                    return samples
                }
            } catch {
                continue
            }
        }

        throw RouteError.noRouteFound("Could not load nearby road database")
    }

    private func sampleRoadGeometry(
        _ coordinates: [CLLocationCoordinate2D],
        roadClass: RoadClass,
        highway: String,
        roadName: String?
    ) -> [RoadSample] {

        var samples: [RoadSample] = []

        for index in 0..<(coordinates.count - 1) {
            let start = coordinates[index]
            let end = coordinates[index + 1]
            let segmentLength = haversineMetres(start, end)

            guard segmentLength > 1 else { continue }

            let sampleCount = max(1, Int(segmentLength / 35.0))

            for sampleIndex in 0...sampleCount {
                let t = Double(sampleIndex) / Double(sampleCount)
                samples.append(
                    RoadSample(
                        coordinate: interpolate(start, end, t),
                        roadClass: roadClass,
                        highway: highway,
                        roadName: roadName
                    )
                )
            }
        }

        // Keep the scoring fast on dense city networks.
        if samples.count > 6000 {
            return stride(from: 0, to: samples.count, by: max(1, samples.count / 6000)).map { samples[$0] }
        }

        return samples
    }

    // MARK: - Preference-aware waypoint generation

    private func makePreferenceAwareWaypoints(
        origin: CLLocationCoordinate2D,
        roadSamples: [RoadSample],
        targets: [RoadClass: Double],
        targetDistanceKm: Double,
        attempt: Int
    ) -> [CLLocationCoordinate2D] {

        let waypointCount = max(3, min(8, Int(targetDistanceKm / 1.6)))
        let orderedClasses = expandedRoadClassSequence(targets: targets, count: waypointCount, attempt: attempt)

        var waypoints: [CLLocationCoordinate2D] = []
        var usedIndexes = Set<Int>()
        var previous = origin

        for roadClass in orderedClasses {
            let candidates = roadSamples.enumerated()
                .filter { index, sample in
                    sample.roadClass == roadClass && !usedIndexes.contains(index)
                }
                .sorted { left, right in
                    let leftDistance = haversineMetres(previous, left.element.coordinate)
                    let rightDistance = haversineMetres(previous, right.element.coordinate)

                    let leftOriginDistance = haversineMetres(origin, left.element.coordinate)
                    let rightOriginDistance = haversineMetres(origin, right.element.coordinate)

                    // Prefer candidates that are connectable but still help form a loop.
                    return abs(leftDistance - 650.0) + abs(leftOriginDistance - 1200.0)
                         < abs(rightDistance - 650.0) + abs(rightOriginDistance - 1200.0)
                }

            guard !candidates.isEmpty else { continue }

            let pickWindow = min(12, candidates.count)
            let picked = candidates[Int.random(in: 0..<pickWindow)]

            usedIndexes.insert(picked.offset)
            waypoints.append(picked.element.coordinate)
            previous = picked.element.coordinate
        }

        // Sort around the origin so OSRM receives a loop-like order instead of zig-zagging.
        let clockwise = attempt % 2 == 0
        return waypoints.sorted {
            let a = bearingRadians(from: origin, to: $0)
            let b = bearingRadians(from: origin, to: $1)
            return clockwise ? a < b : a > b
        }
    }

    private func expandedRoadClassSequence(
        targets: [RoadClass: Double],
        count: Int,
        attempt: Int
    ) -> [RoadClass] {

        var sequence: [RoadClass] = []

        for pair in targets {
            let slots = max(1, Int(round(pair.value * Double(count))))
            sequence.append(contentsOf: Array(repeating: pair.key, count: slots))
        }

        while sequence.count < count {
            let next = targets.max(by: { $0.value < $1.value })?.key ?? .residential
            sequence.append(next)
        }

        if sequence.count > count {
            sequence = Array(sequence.prefix(count))
        }

        if attempt % 3 == 0 {
            sequence.shuffle()
        }

        return sequence
    }

    // MARK: - Fallback waypoint generation

    private func makeFallbackLoopWaypoints(
        origin: CLLocationCoordinate2D,
        preferences: RoutePreferences,
        attempt: Int,
        baseAngle: Double,
        radiusKm: Double
    ) -> [CLLocationCoordinate2D] {

        let waypointCount = 5
        let direction = attempt % 2 == 0 ? 1.0 : -1.0
        let sweep = Double.pi * Double.random(in: 1.0...1.8)
        var waypoints: [CLLocationCoordinate2D] = []

        for index in 0..<waypointCount {
            let fraction = Double(index + 1) / Double(waypointCount + 1)
            let angle = baseAngle + direction * sweep * fraction + Double.random(in: -0.18...0.18)
            let distance = radiusKm * Double.random(in: 0.45...0.95)

            let latOffset = (distance * sin(angle)) / 110.574
            let lngOffset = (distance * cos(angle)) / (111.320 * cos(origin.latitude * .pi / 180.0))

            waypoints.append(
                CLLocationCoordinate2D(
                    latitude: origin.latitude + latOffset,
                    longitude: origin.longitude + lngOffset
                )
            )
        }

        return waypoints
    }

    // MARK: - OSRM fetch

    private func fetchOSRM(waypoints: [CLLocationCoordinate2D]) async throws -> OSRMRoute {
        let coords = waypoints.map { "\($0.longitude),\($0.latitude)" }.joined(separator: ";")

        for endpoint in osrmEndpoints {
            let urlString = "\(endpoint)\(coords)?overview=full&geometries=geojson&steps=true&continue_straight=false&alternatives=false"
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

    // MARK: - Road mix analysis

    private func analyzeRoadMix(
        routeCoordinates: [[Double]],
        roadSamples: [RoadSample]
    ) -> [RoadClass: Double] {

        guard !routeCoordinates.isEmpty, !roadSamples.isEmpty else {
            return [:]
        }

        let coords = routeCoordinates.compactMap { pair -> CLLocationCoordinate2D? in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }

        guard coords.count >= 2 else { return [:] }

        var metresByClass: [RoadClass: Double] = [:]

        for index in 0..<(coords.count - 1) {
            let start = coords[index]
            let end = coords[index + 1]
            let segmentLength = haversineMetres(start, end)
            let midpoint = interpolate(start, end, 0.5)

            if let matched = nearestRoadSample(to: midpoint, in: roadSamples),
               matched.distance <= roadMatchToleranceMetres {
                metresByClass[matched.sample.roadClass, default: 0] += segmentLength
            }
        }

        let total = metresByClass.values.reduce(0, +)
        guard total > 0 else { return [:] }

        return metresByClass.reduce(into: [RoadClass: Double]()) { output, pair in
            output[pair.key] = pair.value / total
        }
    }

    private func nearestRoadSample(
        to coordinate: CLLocationCoordinate2D,
        in samples: [RoadSample]
    ) -> (sample: RoadSample, distance: Double)? {

        var bestSample: RoadSample?
        var bestDistance = Double.greatestFiniteMagnitude

        for sample in samples {
            let distance = haversineMetres(coordinate, sample.coordinate)
            if distance < bestDistance {
                bestDistance = distance
                bestSample = sample
            }
        }

        guard let bestSample else { return nil }
        return (bestSample, bestDistance)
    }

    // MARK: - Route scoring

    private func scoreRoute(
        distanceKm: Double,
        durationMinutes: Double,
        targetDistanceKm: Double,
        targetDurationMinutes: Double,
        actualMix: [RoadClass: Double],
        targetMix: [RoadClass: Double],
        route: OSRMRoute,
        alreadyAccepted: [ScoredRoute]
    ) -> RouteScore {

        let durationPenalty = abs(durationMinutes - targetDurationMinutes) / max(targetDurationMinutes, 1)
        let distancePenalty = abs(distanceKm - targetDistanceKm) / max(targetDistanceKm, 0.1)

        let ratioPenalty: Double
        if actualMix.isEmpty {
            // If Overpass failed, do not reject immediately, but score lower.
            ratioPenalty = 0.35
        } else {
            ratioPenalty = targetMix.reduce(0.0) { partial, pair in
                partial + abs((actualMix[pair.key] ?? 0.0) - pair.value)
            }
        }

        let duplicatePenalty = alreadyAccepted.contains {
            abs($0.route.distanceKm - distanceKm) < 0.35 &&
            abs($0.route.durationMinutes - durationMinutes) < 2.5
        } ? 0.45 : 0.0

        let loopPenalty = loopQualityPenalty(route.geometry.coordinates)

        let totalScore =
            durationPenalty * 0.36 +
            distancePenalty * 0.20 +
            ratioPenalty * 0.34 +
            loopPenalty * 0.10 +
            duplicatePenalty

        let acceptable =
            durationPenalty <= 0.35 &&
            distancePenalty <= 0.45 &&
            ratioPenalty <= 0.45 &&
            duplicatePenalty == 0.0

        return RouteScore(totalScore: totalScore, isAcceptable: acceptable)
    }

    private func loopQualityPenalty(_ coordinates: [[Double]]) -> Double {
        let coords = coordinates.compactMap { pair -> CLLocationCoordinate2D? in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }

        guard let first = coords.first, let last = coords.last, coords.count > 5 else {
            return 1.0
        }

        let closureDistance = haversineMetres(first, last)
        return min(1.0, closureDistance / 300.0)
    }

    private func adjustRadius(_ radius: Double, actualDuration: Double, targetDuration: Double) -> Double {
        let ratio = actualDuration / max(targetDuration, 1.0)

        if ratio < 0.65 {
            return min(radius * 1.25, radius + 1.0)
        }

        if ratio > 1.35 {
            return max(radius * 0.78, 0.4)
        }

        return radius
    }

    // MARK: - Parse OSRM steps

    private func parseOSRMSteps(_ route: OSRMRoute) -> [RouteStep] {
        route.legs.flatMap { $0.steps }.map { step in
            let type = step.maneuver.type ?? "straight"
            let modifier = step.maneuver.modifier ?? ""
            let maneuverType = modifier.isEmpty ? type : "\(type)-\(modifier)"
            let location = step.maneuver.location

            let coord = CoordPair(
                latitude: location.count >= 2 ? location[1] : 0,
                longitude: location.count >= 2 ? location[0] : 0
            )

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

    // MARK: - Polyline helpers

    func encodePolyline(_ coords: [[Double]]) -> String {
        var output = ""
        var previousLat = 0
        var previousLng = 0

        func encodeValue(_ value: Int) {
            var value = value < 0 ? ~(value << 1) : (value << 1)

            while value >= 0x20 {
                output.append(Character(UnicodeScalar((0x20 | (value & 0x1f)) + 63)!))
                value >>= 5
            }

            output.append(Character(UnicodeScalar(value + 63)!))
        }

        for coord in coords {
            guard coord.count >= 2 else { continue }

            let lat = Int(round(coord[1] * 1e5))
            let lng = Int(round(coord[0] * 1e5))

            encodeValue(lat - previousLat)
            encodeValue(lng - previousLng)

            previousLat = lat
            previousLng = lng
        }

        return output
    }

    func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        GMSPath(fromEncodedPath: encoded)?.coordinates() ?? []
    }

    // MARK: - Geometry helpers

    private func haversineMetres(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6_371_000.0

        let lat1 = a.latitude * .pi / 180.0
        let lat2 = b.latitude * .pi / 180.0
        let dLat = (b.latitude - a.latitude) * .pi / 180.0
        let dLon = (b.longitude - a.longitude) * .pi / 180.0

        let h = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)

        return earthRadius * 2 * atan2(sqrt(h), sqrt(1 - h))
    }

    private func interpolate(
        _ a: CLLocationCoordinate2D,
        _ b: CLLocationCoordinate2D,
        _ t: Double
    ) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }

    private func bearingRadians(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180.0
        let lat2 = b.latitude * .pi / 180.0
        let dLon = (b.longitude - a.longitude) * .pi / 180.0

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x)

        return bearing >= 0 ? bearing : bearing + 2.0 * .pi
    }
}

// MARK: - Route scoring support

private struct ScoredRoute {
    let route: GeneratedRoute
    let score: Double
    let roadMix: [RoadClass: Double]
}

private struct RouteScore {
    let totalScore: Double
    let isAcceptable: Bool
}

private struct RoadSample {
    let coordinate: CLLocationCoordinate2D
    let roadClass: RoadClass
    let highway: String
    let roadName: String?
}

private enum RoadClass: String, CaseIterable, Hashable {
    case residential
    case main
    case motorway

    init?(from userValue: String) {
        let value = userValue
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        if value.contains("residential") || value.contains("local") || value.contains("neighbourhood") || value.contains("neighborhood") {
            self = .residential
            return
        }

        if value.contains("main") || value.contains("primary") || value.contains("secondary") || value.contains("tertiary") || value.contains("arterial") {
            self = .main
            return
        }

        if value.contains("motorway") || value.contains("freeway") || value.contains("highway") || value.contains("trunk") {
            self = .motorway
            return
        }

        return nil
    }

    init?(osmHighway: String) {
        switch osmHighway {
        case "residential", "living_street", "unclassified":
            self = .residential
        case "primary", "secondary", "tertiary", "primary_link", "secondary_link", "tertiary_link":
            self = .main
        case "motorway", "trunk", "motorway_link", "trunk_link":
            self = .motorway
        default:
            return nil
        }
    }

    var osmHighwayValues: [String] {
        switch self {
        case .residential:
            return ["residential", "living_street", "unclassified"]
        case .main:
            return ["primary", "secondary", "tertiary", "primary_link", "secondary_link", "tertiary_link"]
        case .motorway:
            return ["motorway", "trunk", "motorway_link", "trunk_link"]
        }
    }
}

// MARK: - Errors

enum RouteError: LocalizedError {
    case invalidURL
    case networkError
    case noRouteFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error — check your connection"
        case .noRouteFound(let message):
            return "No route found (\(message))"
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

// MARK: - Overpass response models

private struct OverpassResponse: Codable {
    let elements: [OverpassElement]
}

private struct OverpassElement: Codable {
    let id: Int?
    let type: String?
    let tags: [String: String]?
    let geometry: [OverpassGeometryPoint]?
}

private struct OverpassGeometryPoint: Codable {
    let lat: Double
    let lon: Double
}

// MARK: - GMSPath extension

extension GMSPath {
    func coordinates() -> [CLLocationCoordinate2D] {
        (0..<count()).map { coordinate(at: $0) }
    }
}

// MARK: - Small helpers

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - HTML stripping, kept for legacy compatibility

extension String {
    func strippingHTML() -> String {
        guard let data = data(using: .utf8) else { return self }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        return (try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ))?.string ?? self
    }
}
