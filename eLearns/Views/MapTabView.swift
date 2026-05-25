import SwiftUI
import GoogleMaps
import CoreLocation

struct MapTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var locationService  = LocationService.shared
    @StateObject private var routeService     = RouteService.shared
    @StateObject private var navService       = NavigationService.shared
    @StateObject private var placesService    = PlacesSearchService.shared

    @State private var showWizard       = false
    @State private var showRoutePreview = false
    @State private var showNavigation   = false
    @State private var searchText       = ""
    @FocusState private var searchFocused: Bool
    @State private var isGenerating     = false
    @State private var generatedRoutes: [GeneratedRoute] = []
    @State private var selectedRouteIndex = 0
    @State private var errorMessage: String? = nil
    @State private var pinnedPlace: PlaceResult? = nil
    @State private var showWaypointConfirm = false
    @State private var pendingWaypoint: PlaceResult? = nil
    @State private var showHandoverWarning = false

    var body: some View {
        ZStack(alignment: .top) {

            // MARK: - Map
            GoogleMapView(
                route: appState.currentRoute,
                isNavigating: appState.isNavigating
            )
            .ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }

            // MARK: - Relocate button
            if !appState.isNavigating {
                VStack {
                    Spacer()
                    HStack {
                        Button {
                            guard let coord = LocationService.shared.currentLocation?.coordinate else { return }
                            NotificationCenter.default.post(
                                name: .relocateToUserLocation,
                                object: coord
                            )
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color("AccentGold"))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glassCircle)
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                        .padding(.leading, 16)
                        .padding(.bottom, 40)
                        Spacer()
                    }
                }
            }

            // MARK: - Top search bar
            if !appState.isNavigating {
                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if let error = errorMessage {
                        errorBanner(error)
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                    }

                    SearchSuggestionsView(
                        suggestions: placesService.suggestions,
                        isLoading: placesService.isLoading,
                        onSelect: handleRouteHere,
                        onAddWaypoint: handleAddWaypoint
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                    Spacer()
                }
            }

            // MARK: - Bottom controls
            VStack {
                Spacer()
                if appState.isNavigating {
                    NavigationOverlayView(
                        route: appState.currentRoute,
                        onStop: stopNavigation
                    )
                } else if let route = appState.currentRoute {
                    routePreviewPanel(route)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                } else {
                    HStack {
                        Spacer()
                        buildRouteButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .sheet(isPresented: $showWizard) {
            RouteWizardView(onGenerate: handleGeneratedRoutes)
        }
        .overlay {
            if showHandoverWarning {
                HandoverWarningView(
                    onConfirm: {
                        withAnimation(.spring(duration: 0.3)) {
                            showHandoverWarning = false
                        }
                        showRoutePreview = false
                        startNavigation()
                    },
                    onCancel: {
                        withAnimation(.spring(duration: 0.3)) {
                            showHandoverWarning = false
                        }
                    }
                )
                .animation(.spring(duration: 0.3), value: showHandoverWarning)
            }
        }
        .sheet(isPresented: $showRoutePreview) {
            if let route = appState.currentRoute {
                RoutePreviewSheet(
                    route: route,
                    onStartDrive: confirmAndStartNavigation,
                    onSave: saveRoute,
                    onDismiss: { showRoutePreview = false }
                )
            }
        }
        .onAppear {
            locationService.requestPermission()
        }
        .onChange(of: searchText) { newValue in
            guard !newValue.isEmpty else {
                placesService.clear()
                return
            }
            Task {
                await placesService.search(newValue, near: locationService.currentLocation?.coordinate)
            }
        }
        .confirmationDialog(
            "Add \"\(pendingWaypoint?.title ?? "")\" as a waypoint?",
            isPresented: $showWaypointConfirm,
            titleVisibility: .visible
        ) {
            Button("Add Waypoint") {
                if let place = pendingWaypoint {
                    addWaypointToWizard(place)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            // Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15))

                TextField("Search address or landmark", text: $searchText)
                    .font(.system(size: 15))
                    .submitLabel(.search)
                    .focused($searchFocused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .modifier(GlassInteractiveBarModifier())

            // X button — slides in outside the bar
            if searchFocused || !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchFocused = false
                    placesService.clear()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(11)
                }
                .buttonStyle(.glassCircle)
                .contentShape(Circle())
                .allowsHitTesting(true)
                .zIndex(10)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: searchFocused)
        .animation(.spring(duration: 0.3), value: searchText.isEmpty)
    }
    
    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
            Spacer()
            Button { errorMessage = nil } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .modifier(GlassPanelModifier(cornerRadius: 12))
    }

    // MARK: - Build route button

    private var buildRouteButton: some View {
        Button {
            showWizard = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color("AccentGold"))
                Text("Build Route")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
        }
        .buttonStyle(.glassPill)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
    }

    // MARK: - Route preview panel

    private func routePreviewPanel(_ route: GeneratedRoute) -> some View {
        VStack(spacing: 10) {
            // Route stats row
            HStack(spacing: 0) {
                statPill(value: String(format: "%.1f", route.distanceKm), unit: "km")
                Divider().frame(height: 24).padding(.horizontal, 12)
                statPill(value: "\(Int(route.durationMinutes))", unit: "min")
                Divider().frame(height: 24).padding(.horizontal, 12)
                statPill(value: "\(route.steps.count)", unit: "turns")
                Spacer()
                Button {
                    appState.currentRoute = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .contentShape(Circle())
                }
                .buttonStyle(.glassCircle)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Action buttons
            HStack(spacing: 10) {
                Button {
                    showRoutePreview = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 14))
                        Text("Preview")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.glassRounded(cornerRadius: 20))

                Button {
                    confirmAndStartNavigation()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                        Text("Start Drive")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color("AccentGold"))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.glassRounded)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .modifier(GlassPanelModifier(cornerRadius: 18))
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
    }

    private func statPill(value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func handleGeneratedRoutes(_ routes: [GeneratedRoute]) {
        generatedRoutes = routes
        appState.currentRoute = routes.first
        showWizard = false
    }

    private func startNavigation() {
        guard let route = appState.currentRoute else { return }
        appState.isNavigating = true
        let viaWaypoints = routeService.navigationWaypoints(for: route, sampleCount: 6)
        navService.startNavigation(
            to: route.endCoordinate.coordinate,
            via: viaWaypoints
        )
    }

    private func confirmAndStartNavigation() {
        showHandoverWarning = true
    }

    private func stopNavigation() {
        navService.stopNavigation()
        appState.isNavigating = false
    }

    private func saveRoute() {
        guard let route = appState.currentRoute else { return }
        let name = "Route \(appState.savedRoutes.count + 1) — \(Date().formatted(date: .abbreviated, time: .omitted))"
        appState.saveRoute(route, name: name)
    }
    
    private func handlePlaceSelect(_ place: PlaceResult) {
        // do nothing — actions handled by buttons in the row
    }

    private func handleAddWaypoint(_ place: PlaceResult) {
        Task {
            guard let coord = await placesService.fetchCoordinate(for: place.id) else { return }
            let waypoint = Waypoint(
                name: place.title,
                latitude: coord.latitude,
                longitude: coord.longitude
            )
            appState.pendingWaypoints.append(waypoint)
            searchText = ""
            searchFocused = false
            placesService.clear()
            showWizard = true
        }
    }

    private func handleRouteHere(_ place: PlaceResult) {
        Task {
            guard let coord = await placesService.fetchCoordinate(for: place.id) else { return }
            NavigationService.shared.mapView?.animate(to: GMSCameraPosition(
                target: coord,
                zoom: 15
            ))
            searchText = ""
            searchFocused = false
            placesService.clear()
            // Open wizard with destination pre-set as waypoint
            let waypoint = Waypoint(
                name: place.title,
                latitude: coord.latitude,
                longitude: coord.longitude
            )
            appState.pendingWaypoints = [waypoint]
            showWizard = true
        }
    }

    private func addWaypointToWizard(_ place: PlaceResult) {
        Task {
            guard let coord = await placesService.fetchCoordinate(for: place.id) else { return }
            let waypoint = Waypoint(
                name: place.title,
                latitude: coord.latitude,
                longitude: coord.longitude
            )
            // Pre-populate wizard preferences and open it
            appState.pendingWaypoints.append(waypoint)
            searchText = ""
            placesService.clear()
            showWizard = true
        }
    }
}
