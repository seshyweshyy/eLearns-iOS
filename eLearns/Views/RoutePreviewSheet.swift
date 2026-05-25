import SwiftUI

struct RoutePreviewSheet: View {
    var route: GeneratedRoute
    var onStartDrive: () -> Void
    var onSave: () -> Void
    var onUnsave: () -> Void
    var onDismiss: () -> Void

    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Stats row
                    HStack(spacing: 0) {
                        statCard(icon: "ruler", value: String(format: "%.1f", route.distanceKm), unit: "km")
                        Divider().frame(height: 40).padding(.horizontal, 8)
                        statCard(icon: "clock", value: "\(Int(route.durationMinutes))", unit: "min")
                        Divider().frame(height: 40).padding(.horizontal, 8)
                        statCard(icon: "arrow.triangle.turn.up.right.circle", value: "\(route.steps.count)", unit: "turns")
                    }
                    .padding(.vertical, 14)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

                    // Road types
                    if !route.preferences.selectedRoadTypes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Road types")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                            FlowLayout(items: Array(route.preferences.selectedRoadTypes)) { type in
                                Label(type.displayName, systemImage: type.systemImage)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color("AccentGold").opacity(0.1), in: Capsule())
                                    .foregroundStyle(Color("AccentGold"))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Turn-by-turn steps
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Turn-by-turn")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                            .padding(.bottom, 10)

                        ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                            stepRow(step: step, index: index, isLast: index == route.steps.count - 1)
                        }
                    }
                    .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))

                    // Action buttons
                    VStack(spacing: 10) {
                        Button {
                            onDismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onStartDrive()
                            }
                        } label: {
                            Label("Start Drive", systemImage: "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color("AccentGold"))
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            onSave()
                            onDismiss()
                        } label: {
                            Label("Save Route", systemImage: "bookmark")
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Route Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if appState.isRouteSaved(route) {
                            onUnsave()
                        } else {
                            onSave()
                        }
                    } label: {
                        Label("Save", systemImage: appState.isRouteSaved(route) ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(Color("AccentGold"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Stat card

    private func statCard(icon: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(unit)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step row

    private func stepRow(step: RouteStep, index: Int, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: turnIcon(step.maneuverType))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("AccentGold"))
                .frame(width: 28, height: 28)
                .background(Color("AccentGold").opacity(0.1), in: RoundedRectangle(cornerRadius: 7))

            // Instruction
            VStack(alignment: .leading, spacing: 2) {
                Text(step.instruction)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(distanceLabel(step.distanceMetres))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider().padding(.leading, 56)
            }
        }
    }

    private func turnIcon(_ maneuver: String) -> String {
        switch maneuver {
        case let m where m.contains("right"):     return "arrow.turn.up.right"
        case let m where m.contains("left"):      return "arrow.turn.up.left"
        case let m where m.contains("roundabout"):return "arrow.clockwise"
        case let m where m.contains("uturn"):     return "arrow.uturn.left"
        case "arrive":                             return "flag.checkered"
        default:                                   return "arrow.up"
        }
    }

    private func distanceLabel(_ metres: Double) -> String {
        metres >= 1000
            ? String(format: "%.1f km", metres / 1000)
            : "\(Int(metres)) m"
    }
}

// MARK: - Simple flow layout for tags

struct FlowLayout<Item: Hashable, Content: View>: View {
    var items: [Item]
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        // Simple wrapping layout using LazyVStack + HStack approach
        // For iOS 16+ you could use Layout protocol for true flow
        var rows: [[Item]] = [[]]
        for item in items {
            rows[rows.count - 1].append(item)
            if rows.last?.count ?? 0 >= 3 {
                rows.append([])
            }
        }

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                }
            }
        }
    }
}
