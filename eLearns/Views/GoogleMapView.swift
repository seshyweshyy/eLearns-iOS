import SwiftUI
import GoogleMaps
import GoogleNavigation
import Combine

struct GoogleMapView: UIViewRepresentable {
    var route: GeneratedRoute?
    var isNavigating: Bool

    // Replace with your Map ID from Google Cloud Console
    private let darkMapID = GMSMapID(identifier: "8e79201a670f4f6539b3d694")

    func makeUIView(context: Context) -> GMSMapView {
        // Use last known location immediately if available, otherwise Sydney fallback
        let startLocation = LocationService.shared.currentLocation?.coordinate
        ?? CLLocationCoordinate2D(latitude: -33.8568, longitude: 151.2153)
        
        let camera = GMSCameraPosition(
            latitude: startLocation.latitude,
            longitude: startLocation.longitude,
            zoom: 15
        )
        
        let mapView = GMSMapView(frame: .zero, mapID: darkMapID, camera: camera)
        
        mapView.settings.compassButton      = true
        mapView.settings.myLocationButton   = false
        mapView.isMyLocationEnabled         = true
        mapView.settings.scrollGestures     = true
        mapView.settings.zoomGestures       = true
        mapView.settings.tiltGestures       = !isNavigating
        mapView.settings.rotateGestures     = true
        mapView.isBuildingsEnabled          = true
        
        if let logoView = mapView.subviews.first(where: { String(describing: type(of: $0)).contains("Logo") }) {
            logoView.transform = CGAffineTransform(scaleX: 0.65, y: 0.65)
        }
        
        NavigationService.shared.mapView = mapView
        context.coordinator.startObservingLocation(mapView: mapView)
        context.coordinator.startObservingRelocate(mapView: mapView)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Only redraw the route polyline when the route itself changes,
        // not on every location tick — avoids the flicker/jump
        if route?.id != context.coordinator.lastRouteID {
            mapView.clear()
            if let route = route {
                drawRoute(on: mapView, route: route)
            }
            context.coordinator.lastRouteID = route?.id
        }

        if isNavigating {
            // Only set these once when navigation starts, not every update
            if !context.coordinator.hasConfiguredNavCamera {
                mapView.isBuildingsEnabled    = true
                mapView.cameraMode            = .following   // SDK handles all camera movement
                mapView.travelMode            = .driving
                mapView.settings.tiltGestures   = false
                mapView.settings.scrollGestures = false
                mapView.settings.rotateGestures = false

                // Animate into 3D once — after that .following takes over
                let navCamera = GMSCameraPosition(
                    target: mapView.myLocation?.coordinate ?? mapView.camera.target,
                    zoom: 18.5,
                    bearing: mapView.camera.bearing,
                    viewingAngle: 60
                )
                mapView.animate(to: navCamera)
                context.coordinator.hasConfiguredNavCamera = true
            }
            // Do NOT touch the camera again while navigating —
            // .following + the Navigation SDK handle interpolation natively

        } else {
            if context.coordinator.hasConfiguredNavCamera {
                mapView.cameraMode              = .free
                mapView.settings.tiltGestures   = true
                mapView.settings.scrollGestures = true
                mapView.settings.rotateGestures = true

                let flatCamera = GMSCameraPosition(
                    target: mapView.camera.target,
                    zoom: mapView.camera.zoom,
                    bearing: 0,
                    viewingAngle: 0
                )
                mapView.animate(to: flatCamera)
                context.coordinator.hasConfiguredNavCamera = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var lastRouteID: UUID? = nil
        var hasConfiguredNavCamera: Bool = false
        private var cancellable: AnyCancellable?
        private var relocateCancellable: AnyCancellable?
        private var hasSnappedToLocation = false

        func startObservingLocation(mapView: GMSMapView) {
            cancellable = LocationService.shared.$currentLocation
                .compactMap { $0 }
                .first()
                .receive(on: DispatchQueue.main)
                .sink { [weak mapView] location in
                    guard let mapView, !self.hasSnappedToLocation else { return }
                    self.hasSnappedToLocation = true
                    mapView.animate(to: GMSCameraPosition(target: location.coordinate, zoom: 15))
                }
        }

        func startObservingRelocate(mapView: GMSMapView) {
            relocateCancellable = NotificationCenter.default
                .publisher(for: .relocateToUserLocation)
                .receive(on: DispatchQueue.main)
                .sink { [weak mapView] notification in
                    guard let mapView,
                          let coord = notification.object as? CLLocationCoordinate2D else { return }
                    mapView.animate(to: GMSCameraPosition(target: coord, zoom: 16))
                }
        }
    }

    // MARK: - Draw route polyline + markers

    private func drawRoute(on mapView: GMSMapView, route: GeneratedRoute) {
        // Main polyline
        if let path = GMSPath(fromEncodedPath: route.polylinePoints) {
            let polyline = GMSPolyline(path: path)
            polyline.strokeColor  = UIColor(named: "AccentGold") ?? .systemTeal
            polyline.strokeWidth  = 5
            polyline.geodesic     = true
            polyline.map          = mapView

            // Fit camera to route
            let bounds = GMSCoordinateBounds(path: path)
            let update = GMSCameraUpdate.fit(bounds, withPadding: 60)
            mapView.animate(with: update)
        }

        // Start marker
        let startMarker = GMSMarker(position: route.startCoordinate.coordinate)
        startMarker.title  = "Start"
        startMarker.icon   = markerIcon(letter: "A", color: UIColor(named: "AccentGold") ?? .systemTeal)
        startMarker.map    = mapView

        // End marker (loop returns to start, so only show if different)
        let end   = route.endCoordinate.coordinate
        let start = route.startCoordinate.coordinate
        let isLoop = abs(end.latitude - start.latitude) < 0.0001 &&
                     abs(end.longitude - start.longitude) < 0.0001

        if !isLoop {
            let endMarker = GMSMarker(position: end)
            endMarker.title = "Destination"
            endMarker.icon  = markerIcon(letter: "B", color: .systemRed)
            endMarker.map   = mapView
        }

        // Waypoint markers
        for (i, wp) in route.waypoints.enumerated() {
            let wpMarker = GMSMarker(position: wp.coordinate)
            wpMarker.title = wp.name
            wpMarker.icon  = markerIcon(letter: "\(i + 1)", color: .systemOrange)
            wpMarker.map   = mapView
        }
    }

    // MARK: - Custom marker icon

    private func markerIcon(letter: String, color: UIColor) -> UIImage {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let str = NSAttributedString(string: letter, attributes: attrs)
            let strSize = str.size()
            let strRect = CGRect(
                x: (size.width  - strSize.width)  / 2,
                y: (size.height - strSize.height) / 2,
                width: strSize.width,
                height: strSize.height
            )
            str.draw(in: strRect)
        }
    }
}

extension Notification.Name {
    static let relocateToUserLocation = Notification.Name("relocateToUserLocation")
}

// MARK: - Interactive glass bar (search bar, input fields)
struct GlassInteractiveBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        }
    }
}
