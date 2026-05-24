import SwiftUI

struct RoutesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if appState.savedRoutes.isEmpty {
                    emptyState
                } else {
                    routeList
                }
            }
            .navigationTitle("Routes")
        }
    }

    // MARK: - Route list

    private var routeList: some View {
        List {
            ForEach(appState.savedRoutes) { saved in
                routeCard(saved)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .onDelete { offsets in
                appState.deleteRoute(at: offsets)
            }
        }
        .listStyle(.plain)
    }

    private func routeCard(_ saved: SavedRoute) -> some View {
        Button {
            appState.currentRoute = saved.route
            appState.selectedTab = .map
        } label: {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: "road.lanes")
                    .font(.system(size: 16))
                    .foregroundStyle(Color("AccentGold"))
                    .frame(width: 40, height: 40)
                    .background(Color("AccentGold").opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(saved.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(String(format: "%.1f km", saved.route.distanceKm), systemImage: "ruler")
                        Text("·")
                        Label("\(Int(saved.route.durationMinutes)) min", systemImage: "clock")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                    Text(saved.savedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color("AccentGold"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "road.lanes")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No saved routes")
                .font(.system(size: 18, weight: .semibold))
            Text("Build a route from the Map tab and save it to revisit it anytime")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                appState.selectedTab = .map
            } label: {
                Label("Go to Map", systemImage: "map")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color("AccentGold"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.glassPill)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
