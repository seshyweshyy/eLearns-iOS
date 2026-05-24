import SwiftUI
import CoreLocation

struct WaypointSearchSheet: View {
    var onSelect: (Waypoint) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var placesService = PlacesSearchService.shared
    @StateObject private var locationService = LocationService.shared
    @State private var searchText = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15))
                    TextField("Search for a place", text: $searchText)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .font(.system(size: 15))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .modifier(GlassInteractiveBarModifier())
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                // Results
                if placesService.isLoading {
                    Spacer()
                    ProgressView("Searching…")
                    Spacer()
                } else if placesService.suggestions.isEmpty && !searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No results for \"\(searchText)\"")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Search for an address or landmark")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(placesService.suggestions) { place in
                                Button {
                                    selectPlace(place)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundStyle(Color("AccentGold"))
                                            .font(.system(size: 20))
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(place.title)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            if !place.subtitle.isEmpty {
                                                Text(place.subtitle)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(Color("AccentGold"))
                                            .font(.system(size: 18))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Waypoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        placesService.clear()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
        .onChange(of: searchText) { newValue in
            guard !newValue.isEmpty else {
                placesService.clear()
                return
            }
            Task {
                await placesService.search(newValue, near: locationService.currentLocation?.coordinate)
            }
        }
    }

    private func selectPlace(_ place: PlaceResult) {
        Task {
            guard let coord = await placesService.fetchCoordinate(for: place.id) else { return }
            let waypoint = Waypoint(
                name: place.title,
                latitude: coord.latitude,
                longitude: coord.longitude
            )
            placesService.clear()
            onSelect(waypoint)
            dismiss()
        }
    }
}
