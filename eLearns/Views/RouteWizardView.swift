import SwiftUI
import CoreLocation

struct RouteWizardView: View {
    var onGenerate: ([GeneratedRoute]) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var locationService = LocationService.shared

    @State private var step = 0
    @State private var prefs = RoutePreferences()
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    @State private var showWaypointSearch = false
    @StateObject private var routeService = RouteService.shared

    private let totalSteps = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Progress bar
                progressBar

                // Step content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch step {
                        case 0: roadTypesStep
                        case 1: radiusAndDurationStep
                        case 2: waypointsStep
                        case 3: summaryStep
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }

                // Nav buttons
                bottomButtons
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if !appState.pendingWaypoints.isEmpty {
                prefs.waypoints = appState.pendingWaypoints
                appState.pendingWaypoints = []
                step = 2 // jump straight to waypoints step so user sees them
            }
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= step ? Color("AccentGold") : Color.secondary.opacity(0.25))
                    .frame(maxWidth: .infinity)
                    .frame(height: 3)
                    .animation(.easeInOut, value: step)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Step titles

    private var stepTitle: String {
        switch step {
        case 0: return "Road Types"
        case 1: return "Distance & Duration"
        case 2: return "Waypoints"
        case 3: return "Review"
        default: return ""
        }
    }

    // MARK: - Step 0: Road types

    private var roadTypesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick at least one core road type")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            sectionLabel("Core roads", required: true)
            roadTypeGrid(types: RoadType.allCases.filter { $0.isRequired })

            sectionLabel("Optional extras", required: false)
            roadTypeGrid(types: RoadType.allCases.filter { !$0.isRequired })
        }
    }

    private func sectionLabel(_ text: String, required: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(required ? Color("AccentGold") : .orange)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            if required {
                Text("required")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color("AccentGold"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color("AccentGold").opacity(0.12), in: Capsule())
            }
        }
    }

    private func roadTypeGrid(types: [RoadType]) -> some View {
        VStack(spacing: 8) {
            ForEach(types) { type in
                roadTypeRow(type)
            }
        }
    }

    private func roadTypeRow(_ type: RoadType) -> some View {
        let isSelected = prefs.selectedRoadTypes.contains(type)

        return Button {
            if isSelected {
                prefs.selectedRoadTypes.remove(type)
            } else {
                prefs.selectedRoadTypes.insert(type)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color("AccentGold") : .secondary)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(type.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color("AccentGold") : .secondary)
                    .font(.system(size: 20))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isSelected ? Color("AccentGold").opacity(0.5) : Color("AccentGold").opacity(0.12),
                        lineWidth: 1
                    )
            )
        }
            .buttonStyle(.glassRounded)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Step 1: Radius & duration

    private var radiusAndDurationStep: some View {
        VStack(alignment: .leading, spacing: 24) {

            // Radius
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Radius")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("\(Int(prefs.radiusKm)) km")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color("AccentGold"))
                }
                Slider(value: $prefs.radiusKm, in: 1...20, step: 1)
                    .tint(Color("AccentGold"))
                HStack {
                    Text("1 km").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("20 km").font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            // Duration
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Target duration")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("\(prefs.durationMinutes) min")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color("AccentGold"))
                }
                Slider(value: Binding(
                    get: { Double(prefs.durationMinutes) },
                    set: { prefs.durationMinutes = Int($0) }
                ), in: 15...120, step: 5)
                .tint(Color("AccentGold"))
                HStack {
                    Text("15 min").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("2 hrs").font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            // Loop toggle
            Toggle(isOn: $prefs.isLoop) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Loop route")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Returns to your starting point")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Color("AccentGold"))
        }
    }

    // MARK: - Step 2: Waypoints

    private var waypointsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add specific locations you'd like to drive through (optional)")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            if prefs.waypoints.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No waypoints added")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 32)
            } else {
                ForEach(prefs.waypoints) { wp in
                    waypointRow(wp)
                }
                .onDelete { offsets in
                    prefs.waypoints.remove(atOffsets: offsets)
                }
            }

            Button {
                showWaypointSearch = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Waypoint")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(Color("AccentGold"))
            }
            .buttonStyle(.glassPill)
            .sheet(isPresented: $showWaypointSearch) {
                WaypointSearchSheet { waypoint in
                    prefs.waypoints.append(waypoint)
                }
            }
        }
    }

    private func waypointRow(_ wp: Waypoint) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 20))
            Text(wp.name)
                .font(.system(size: 15))
                .lineLimit(1)
            Spacer()
            Button {
                prefs.waypoints.removeAll { $0.id == wp.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassFrosted(cornerRadius: 20)
    }

    // MARK: - Step 3: Summary

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 10) {

            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                }
                .padding(16)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
            }

            summaryRow(icon: "road.lanes",    label: "Road types",  value: prefs.selectedRoadTypes.map { $0.displayName }.joined(separator: ", "))
            summaryRow(icon: "ruler",         label: "Radius",      value: "\(Int(prefs.radiusKm)) km")
            summaryRow(icon: "clock",         label: "Duration",    value: "\(prefs.durationMinutes) min")
            summaryRow(icon: "arrow.triangle.turn.up.right.diamond", label: "Type", value: prefs.isLoop ? "Loop route" : "Point-to-point")
            if !prefs.waypoints.isEmpty {
                summaryRow(icon: "mappin", label: "Waypoints", value: "\(prefs.waypoints.count) added")
            }
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color("AccentGold"))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassFrosted(cornerRadius: 20)
    }

    // MARK: - Bottom buttons

    private var bottomButtons: some View {
        VStack(spacing: 10) {

            // Progress bar — only visible while generating
            if isGenerating {
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color("AccentGold"))
                                .frame(width: geo.size.width * routeService.generationProgress, height: 6)
                                .animation(.easeInOut(duration: 0.4), value: routeService.generationProgress)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("Finding best routes…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(routeService.generationProgress * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color("AccentGold"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .transition(.opacity)
            }

            HStack(spacing: 12) {
                if step > 0 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.glassPill)
                }

                Button {
                    if step < totalSteps - 1 {
                        withAnimation { step += 1 }
                    } else {
                        generateRoutes()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isGenerating {
                            ProgressView()
                                .tint(.black)
                                .scaleEffect(0.85)
                        }
                        Text(step == totalSteps - 1 ? (isGenerating ? "Generating…" : "Generate") : "Next")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(canAdvance ? .black : .secondary)
                    .background(canAdvance ? Color("AccentGold") : Color.secondary.opacity(0.3))
                    .clipShape(Capsule())
                }
                .buttonStyle(.glassPill)
                .disabled(!canAdvance || isGenerating)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return !prefs.selectedRoadTypes.isEmpty
        default: return true
        }
    }

    // MARK: - Generate

    private func generateRoutes() {
        guard let location = locationService.currentLocation?.coordinate else {
            errorMessage = "Waiting for GPS — make sure location is enabled"
            return
        }

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let routes = try await RouteService.shared.generateRoutes(
                    from: location,
                    preferences: prefs,
                    count: 3
                )
                await MainActor.run {
                    isGenerating = false
                    onGenerate(routes)
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
