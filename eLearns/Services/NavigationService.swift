import Foundation
import GoogleMaps
import GoogleNavigation
import CoreLocation
import Combine

class NavigationService: NSObject, ObservableObject {

    static let shared = NavigationService()

    @Published var isNavigating: Bool = false
    @Published var currentStepIndex: Int = 0
    @Published var remainingDistanceKm: Double = 0
    @Published var remainingMinutes: Double = 0
    @Published var currentSpeedKmh: Double = 0
    @Published var hasArrived: Bool = false
    @Published var isRerouting: Bool = false

    var mapView: GMSMapView?
    private var navigator: GMSNavigator?
    private var locationProvider: GMSRoadSnappedLocationProvider?
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
    }

    // MARK: - Start navigation to a destination

    func startNavigation(to destination: CLLocationCoordinate2D, via waypoints: [CLLocationCoordinate2D] = []) {
        guard let mapView = mapView else { return }

        let navigator = mapView.navigator
        self.navigator = navigator
        navigator?.add(self)

        // Start road-snapped location — this is what switches the blue dot to the nav arrow
        let locationProvider = mapView.roadSnappedLocationProvider
        locationProvider?.startUpdatingLocation()
        locationProvider?.add(self)
        self.locationProvider = locationProvider

        var targets: [GMSNavigationWaypoint] = waypoints.compactMap {
            GMSNavigationWaypoint(location: $0, title: "Waypoint")
        }
        guard let dest = GMSNavigationWaypoint(location: destination, title: "Destination") else { return }
        targets.append(dest)

        navigator?.setDestinations(targets, routingOptions: routingOptions()) { routeStatus in
            DispatchQueue.main.async {
                if routeStatus == .OK {
                    navigator?.isGuidanceActive = true
                    mapView.cameraMode = .following
                    mapView.travelMode = .driving
                    // Explicitly enable the navigation UI — shows arrow + hides blue dot
                    mapView.isNavigationEnabled = true
                    self.isNavigating = true
                    self.hasArrived = false
                } else {
                    print("Navigation routing error: \(routeStatus.rawValue)")
                }
            }
        }
    }

    func stopNavigation() {
        locationProvider?.stopUpdatingLocation()
        locationProvider?.remove(self)
        locationProvider = nil
        navigator?.isGuidanceActive = false
        navigator?.clearDestinations()
        mapView?.isNavigationEnabled = false
        mapView?.cameraMode = .free
        isNavigating = false
        hasArrived = false
        currentStepIndex = 0
        remainingDistanceKm = 0
        remainingMinutes = 0
    }

    // MARK: - Routing options

    private func routingOptions() -> GMSNavigationRoutingOptions {
        return GMSNavigationMutableRoutingOptions()
    }
}

// MARK: - GMSNavigatorListener

extension NavigationService: GMSNavigatorListener {

    func navigator(_ navigator: GMSNavigator, didArriveAt waypoint: GMSNavigationWaypoint) {
        DispatchQueue.main.async {
            if waypoint.title == "Destination" {
                self.hasArrived = true
                self.isNavigating = false
            }
        }
    }

    func navigator(_ navigator: GMSNavigator, didUpdateRemainingTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.remainingMinutes = time / 60.0
        }
    }

    func navigator(_ navigator: GMSNavigator, didUpdateRemainingDistance distance: CLLocationDistance) {
        DispatchQueue.main.async {
            self.remainingDistanceKm = distance / 1000.0
        }
    }

    func navigatorDidChangeRoute(_ navigator: GMSNavigator) {
        DispatchQueue.main.async {
            self.isRerouting = false
        }
    }
}

// MARK: - GMSRoadSnappedLocationProviderListener

extension NavigationService: GMSRoadSnappedLocationProviderListener {

    func locationProvider(
        _ locationProvider: GMSRoadSnappedLocationProvider,
        didUpdate location: CLLocation
    ) {
        DispatchQueue.main.async {
            self.currentSpeedKmh = max(0, location.speed * 3.6)
        }
    }
}
