import SwiftUI

struct NavigationOverlayView: View {
    var route: GeneratedRoute?
    var onStop: () -> Void

    @StateObject private var navService = NavigationService.shared
    @State private var showStopConfirm = false

    var body: some View {
        ZStack(alignment: .bottom) {

            // Top floating card + "Then" chip
            VStack(alignment: .leading, spacing: 6) {
                topCard
                if let next = nextStepInstruction {
                    thenChip(icon: nextTurnIcon, label: next)
                }
                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)

            // Bottom bar
            bottomBar
                .padding(.bottom, 35)
                .padding(.horizontal, 16)
        }
        .alert("Stop Navigation?", isPresented: $showStopConfirm) {
            Button("Stop", role: .destructive) { onStop() }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("Your current drive progress will not be saved.")
        }
    }

    // MARK: - Top floating card

    private var topCard: some View {
        HStack(alignment: .center, spacing: 16) {

            // Arrow icon
            Image(systemName: turnIconName)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48)

            // Street name block
            VStack(alignment: .leading, spacing: 2) {
                Text(nextStepDistanceString)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                Text(currentInstruction)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.22, green: 0.33, blue: 0.28))  // Google Maps dark green
        )
        .modifier(TopCardGlassOverlay())
        .shadow(color: .black.opacity(0.35), radius: 14, y: 5)
    }

    // MARK: - "Then" chip

    private func thenChip(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Text("Then")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.22, green: 0.33, blue: 0.28).opacity(0.92))
        )
        .modifier(ThenChipGlassOverlay())
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 0) {

            // ETA + distance · time
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(navService.remainingMinutes.rounded()))")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("AccentGold"))
                    Text("min")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("AccentGold"))
                }
                HStack(spacing: 4) {
                    Text(distanceRemainingString)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(etaString)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 20)

            Spacer()

            // Exit button (red pill — matches Google Maps)
            Button {
                DispatchQueue.main.async { showStopConfirm = true }
            } label: {
                Text("Exit")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.85, green: 0.27, blue: 0.22), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(GlassPanelModifier(cornerRadius: 28))
        .shadow(color: .black.opacity(0.25), radius: 12, y: -3)
    }

    // MARK: - Computed helpers

    private var currentInstruction: String {
        guard let route else { return "Follow the route" }
        let idx = min(navService.currentStepIndex, route.steps.count - 1)
        return route.steps[safe: idx]?.instruction ?? "Continue"
    }

    private var nextStepInstruction: String? {
        guard let route else { return nil }
        let nextIdx = navService.currentStepIndex + 1
        guard nextIdx < route.steps.count else { return nil }
        let instr = route.steps[nextIdx].instruction
        return instr.isEmpty ? nil : instr
    }

    private var turnIconName: String {
        maneuverIcon(route?.steps[safe: navService.currentStepIndex]?.maneuverType ?? "")
    }

    private var nextTurnIcon: String {
        guard let route else { return "arrow.up" }
        let next = route.steps[safe: navService.currentStepIndex + 1]?.maneuverType ?? ""
        return maneuverIcon(next)
    }

    private func maneuverIcon(_ maneuver: String) -> String {
        switch maneuver {
        case let m where m.contains("turn-right"):  return "arrow.turn.up.right"
        case let m where m.contains("turn-left"):   return "arrow.turn.up.left"
        case let m where m.contains("sharp-right"): return "arrow.turn.right.up"
        case let m where m.contains("sharp-left"):  return "arrow.turn.left.up"
        case let m where m.contains("roundabout"):  return "arrow.clockwise"
        case let m where m.contains("uturn"):       return "arrow.uturn.left"
        case "arrive":                              return "flag.checkered"
        default:                                    return "arrow.up"
        }
    }

    private var nextStepDistanceString: String {
        guard let route else { return "" }
        let idx = min(navService.currentStepIndex, route.steps.count - 1)
        let metres = route.steps[safe: idx]?.distanceMetres ?? 0
        return metres >= 1000
            ? String(format: "%.1f km", metres / 1000)
            : "\(Int(metres)) m"
    }

    private var distanceRemainingString: String {
        let km = navService.remainingDistanceKm
        return km >= 1
            ? String(format: "%.1f km", km)
            : "\(Int(km * 1000)) m"
    }

    private var etaString: String {
        let arrival = Date().addingTimeInterval(navService.remainingMinutes * 60)
        return arrival.formatted(date: .omitted, time: .shortened)
    }

    private var bottomSafeAreaPadding: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow }?
            .safeAreaInsets.bottom) ?? 34
    }
}

// MARK: - Glass overlays
// On iOS 26 these add a subtle Liquid Glass sheen over the coloured backgrounds.
// On iOS 16–25 they're no-ops so the solid colour shows as-is.

private struct TopCardGlassOverlay: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.tint(.clear), in: RoundedRectangle(cornerRadius: 20))
        } else {
            content
        }
    }
}

private struct ThenChipGlassOverlay: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.tint(.clear), in: RoundedRectangle(cornerRadius: 12))
        } else {
            content
        }
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
