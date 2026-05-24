import SwiftUI
import GoogleMaps

struct SearchSuggestionsView: View {
    var suggestions: [PlaceResult]
    var isLoading: Bool
    var onSelect: (PlaceResult) -> Void       // "Route here" — moves camera + opens wizard
    var onAddWaypoint: (PlaceResult) -> Void  // "Add waypoint" — appends to wizard waypoints

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .modifier(GlassPanelModifier(cornerRadius: 20))

            } else if !suggestions.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, place in
                            suggestionRow(place: place, isLast: index == suggestions.count - 1)
                        }
                    }
                }
                .frame(maxHeight: 380)
                .modifier(GlassPanelModifier(cornerRadius: 20))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            }
        }
    }

    private func suggestionRow(place: PlaceResult, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(Color("AccentGold"))
                    .font(.system(size: 20))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(place.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !place.subtitle.isEmpty {
                        Text(place.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    onSelect(place)
                } label: {
                    Label("Route here", systemImage: "map")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color("AccentGold").opacity(0.12), in: Capsule())
                        .foregroundStyle(Color("AccentGold"))
                }
                .buttonStyle(.plain)

                Button {
                    onAddWaypoint(place)
                } label: {
                    Label("Add waypoint", systemImage: "arrow.turn.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            if !isLast {
                Divider().padding(.leading, 54)
            }
        }
    }
}
