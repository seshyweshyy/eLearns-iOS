import SwiftUI

struct NavigationOverlayView: View {
    var route: GeneratedRoute?
    var onStop: () -> Void

    @StateObject private var navService = NavigationService.shared
    @State private var showStopConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            turnCard
                .padding(.horizontal, 16)
                .padding(.top, 8)

            bottomBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
        .alert("Stop Navigation?", isPresented: $showStopConfirm) {
            Button("Stop", role: .destructive) {
                onStop()
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("Your current drive progress will not be saved.")
        }
        .onChange(of: showStopConfirm) { _ in }
    }

    // MARK: - Turn instruction card

    private var turnCard: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 14) {
                Image(systemName: turnIconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color("AccentGold"))
                    .frame(width: 44, height: 44)
                    .background(Color("AccentGold").opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(currentInstruction)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if navService.remainingDistanceKm > 0 {
                        Text(distanceString)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Spacer to reserve space for the button
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .modifier(GlassPanelModifier(cornerRadius: 24))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)

            // Button sits outside the glassEffect layer so it receives touches
            Button {
                DispatchQueue.main.async {
                    showStopConfirm = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.2), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(12)
            .contentShape(Circle().inset(by: -10))
        }
    }

    // MARK: - Bottom bar (speed, ETA, remaining)

    private var bottomBar: some View {
        HStack(spacing: 0) {

            // Speed
            VStack(spacing: 2) {
                Text("\(Int(navService.currentSpeedKmh))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("km/h")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 30)

            // Remaining distance
            VStack(spacing: 2) {
                Text(String(format: "%.1f", navService.remainingDistanceKm))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("km left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 30)

            // ETA
            VStack(spacing: 2) {
                Text(etaString)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("ETA")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .modifier(GlassPanelModifier(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
    }

    // MARK: - Computed helpers

    private var currentInstruction: String {
        guard let route = route else { return "Follow the route" }
        let idx = min(navService.currentStepIndex, route.steps.count - 1)
        return route.steps[safe: idx]?.instruction ?? "Continue"
    }

    private var turnIconName: String {
        guard let route = route else { return "arrow.up" }
        let idx = min(navService.currentStepIndex, route.steps.count - 1)
        let maneuver = route.steps[safe: idx]?.maneuverType ?? ""

        switch maneuver {
        case let m where m.contains("turn-right"):         return "arrow.turn.up.right"
        case let m where m.contains("turn-left"):          return "arrow.turn.up.left"
        case let m where m.contains("sharp-right"):        return "arrow.turn.right.up"
        case let m where m.contains("sharp-left"):         return "arrow.turn.left.up"
        case let m where m.contains("roundabout"):         return "arrow.clockwise"
        case let m where m.contains("uturn"):              return "arrow.uturn.left"
        case "arrive":                                     return "flag.checkered"
        default:                                           return "arrow.up"
        }
    }

    private var distanceString: String {
        let km = navService.remainingDistanceKm
        if km < 1 {
            return "In \(Int(km * 1000)) m"
        }
        return "In \(String(format: "%.1f", km)) km"
    }

    private var etaString: String {
        let arrival = Date().addingTimeInterval(navService.remainingMinutes * 60)
        return arrival.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Safe array subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
