import SwiftUI

struct LogbookView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddLog = false
    @State private var showExportSheet = false
    @State private var exportURL: URL? = nil

    var body: some View {
        NavigationStack {
            List {
                // Hours progress — non-deletable header section
                Section {
                    hoursProgress
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                // Log entries
                if appState.logEntries.isEmpty {
                    Section {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                        Text("Recent drives")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        ForEach(appState.logEntries) { entry in
                            logEntryCard(entry)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        appState.deleteLogEntry(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Logbook")
            .navigationDestination(item: $selectedEntry) { entry in
                LogEntryDetailView(entry: entry)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Button {
                                exportURL = LogbookExporter.exportPDF(entries: appState.logEntries, profile: appState.profile)
                                showExportSheet = true
                            } label: {
                                Label("Export PDF", systemImage: "doc.richtext")
                            }
                            Button {
                                exportURL = LogbookExporter.exportCSV(entries: appState.logEntries, profile: appState.profile)
                                showExportSheet = true
                            } label: {
                                Label("Export CSV / Excel", systemImage: "tablecells")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color("AccentGold"))
                                .frame(width: 34, height: 34)
                                .buttonStyle(.glassCircle)
                        }

                        Button {
                            showAddLog = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color("AccentGold"))
                                .frame(width: 34, height: 34)
                                .buttonStyle(.glassCircle)
                        }
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
            .sheet(isPresented: $showAddLog) {
                AddLogEntryView { entry in
                    appState.addLogEntry(entry)
                }
            }
        }
    }

    private var logList: some View {
        // No longer used — list is built inline in body
        EmptyView()
    }

    // MARK: - Hours progress

    private var hoursProgress: some View {
        VStack(spacing: 12) {

            // Day hours
            progressCard(
                icon: "sun.max.fill",
                iconColor: .yellow,
                label: "Day hours",
                current: appState.totalDayMinutes(),
                required: (appState.profile.licenceType.requiredHours - appState.profile.licenceType.requiredNightHours) * 60,
                color: Color("AccentGold")
            )

            // Night hours
            progressCard(
                icon: "moon.stars.fill",
                iconColor: .indigo,
                label: "Night hours",
                current: appState.totalNightMinutes(),
                required: appState.profile.licenceType.requiredNightHours * 60,
                color: .indigo
            )
        }
    }

    private func progressCard(
        icon: String,
        iconColor: Color,
        label: String,
        current: Int,
        required: Int,
        color: Color
    ) -> some View {
        let progress = required > 0 ? min(Double(current) / Double(required), 1.0) : 1.0
        let hours = current / 60
        let minutes = current % 60
        let requiredHours = required / 60

        return VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(hours)h \(minutes)m / \(requiredHours)h")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress >= 1 ? .green : color)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(duration: 0.6), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    @State private var selectedEntry: LogEntry? = nil

    private func logEntryCard(_ entry: LogEntry) -> some View {
        Button {
            selectedEntry = entry
        } label: {
            HStack(spacing: 14) {
                Image(systemName: entry.isNight ? "moon.stars.fill" : "sun.max.fill")
                    .foregroundStyle(entry.isNight ? .indigo : .yellow)
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
                    .background(
                        (entry.isNight ? Color.indigo : Color.yellow).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 9)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 15, weight: .medium))
                    HStack(spacing: 8) {
                        Text("\(entry.durationMinutes) min")
                        Text("·")
                        Text(String(format: "%.1f km", entry.distanceKm))
                        if !entry.startSuburb.isEmpty {
                            Text("·")
                            Text(entry.startSuburb)
                        } else if !entry.supervisorName.isEmpty {
                            Text("·")
                            Text(entry.supervisorName)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No drives logged yet")
                .font(.system(size: 16, weight: .medium))
            Text("Tap + to log your first drive session")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Add log entry sheet

struct AddLogEntryView: View {
    var onSave: (LogEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var date = Date()
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(1800)
    @State private var startSuburb = ""
    @State private var endSuburb = ""
    @State private var startOdometer = ""
    @State private var endOdometer = ""
    @State private var isNight = false
    @State private var supervisor = ""
    @State private var weather: WeatherCondition = .fine
    @State private var roadTypes: Set<LogRoadType> = []
    @State private var traffic: TrafficLevel = .light
    @State private var feel: DriveFeel = .good
    @State private var notes = ""
    @State private var showStartSuggestions = false
    @State private var showEndSuggestions = false
    @FocusState private var startSuburbFocused: Bool
    @FocusState private var endSuburbFocused: Bool
    @StateObject private var placesService = PlacesSearchService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date & time
                    formSection(title: "Date & time") {
                        VStack(spacing: 0) {
                            formRow {
                                DatePicker("Date", selection: $date, displayedComponents: .date)
                                    .tint(Color("AccentGold"))
                            }
                            Divider().padding(.leading, 16)
                            formRow {
                                DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .tint(Color("AccentGold"))
                            }
                            Divider().padding(.leading, 16)
                            formRow {
                                DatePicker("End time", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .tint(Color("AccentGold"))
                            }
                            Divider().padding(.leading, 16)
                            formRow {
                                Toggle("Night drive", isOn: $isNight)
                                    .tint(Color("AccentGold"))
                            }
                        }
                    }

                    // Location
                    formSection(title: "Location") {
                        VStack(spacing: 0) {
                            formRow {
                                HStack {
                                    Text("Start suburb")
                                        .font(.system(size: 15))
                                    Spacer()
                                    TextField("Required", text: $startSuburb)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                        .onChange(of: startSuburb) { val in
                                            guard startSuburbFocused else { return }
                                            Task { await placesService.search(val, near: nil) }
                                            showStartSuggestions = true
                                        }
                                        .focused($startSuburbFocused)
                                }
                            }
                            if showStartSuggestions && startSuburbFocused && !placesService.suggestions.isEmpty {
                                suburbSuggestions(for: $startSuburb, focused: $startSuburbFocused, show: $showStartSuggestions)
                            }
                            Divider().padding(.leading, 16)
                            formRow {
                                HStack {
                                    Text("End suburb")
                                        .font(.system(size: 15))
                                    Spacer()
                                    TextField("Required", text: $endSuburb)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                        .onChange(of: endSuburb) { val in
                                            guard endSuburbFocused else { return }
                                            Task { await placesService.search(val, near: nil) }
                                            showEndSuggestions = true
                                        }
                                        .focused($endSuburbFocused)
                                }
                            }
                            if showEndSuggestions && endSuburbFocused && !placesService.suggestions.isEmpty {
                                suburbSuggestions(for: $endSuburb, focused: $endSuburbFocused, show: $showEndSuggestions)
                            }
                        }
                    }

                    // Odometer
                    formSection(title: "Odometer") {
                        VStack(spacing: 0) {
                            formRow {
                                HStack {
                                    Text("Start (km)")
                                        .font(.system(size: 15))
                                    Spacer()
                                    TextField("0", text: $startOdometer)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Divider().padding(.leading, 16)
                            formRow {
                                HStack {
                                    Text("End (km)")
                                        .font(.system(size: 15))
                                    Spacer()
                                    TextField("0", text: $endOdometer)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    // Supervisor
                    formSection(title: "Supervisor") {
                        formRow {
                            HStack {
                                Text("Name")
                                    .font(.system(size: 15))
                                Spacer()
                                TextField("Required", text: $supervisor)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Weather
                    formSection(title: "Weather") {
                        iconPickerGrid(items: WeatherCondition.allCases, selected: Binding(
                            get: { weather },
                            set: { weather = $0 }
                        ))
                    }

                    // Road types
                    formSection(title: "Road types") {
                        multiIconGrid(items: LogRoadType.allCases, selected: $roadTypes)
                    }

                    // Traffic
                    formSection(title: "Traffic") {
                        iconPickerGrid(items: TrafficLevel.allCases, selected: Binding(
                            get: { traffic },
                            set: { traffic = $0 }
                        ))
                    }

                    // Feel
                    formSection(title: "How did it feel?") {
                        iconPickerGrid(items: DriveFeel.allCases, selected: Binding(
                            get: { feel },
                            set: { feel = $0 }
                        ))
                    }

                    // Notes
                    formSection(title: "Notes") {
                        formRow {
                            TextField("Optional notes", text: $notes, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(3...6)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Log Drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("AccentGold"))
                }
            }
        }
        .onAppear {
            supervisor = appState.profile.supervisorName
        }
    }

    // MARK: - Section container

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            content()
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func formRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
    }

    // MARK: - Single-select icon grid

    private func iconPickerGrid<T: CaseIterable & Identifiable & Equatable>(
        items: [T],
        selected: Binding<T>
    ) -> some View where T: HasDisplayInfo {
        HStack(spacing: 8) {
            ForEach(items) { item in
                let isSelected = selected.wrappedValue == item
                Button {
                    selected.wrappedValue = item
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(isSelected ? Color("AccentGold") : .secondary)
                            .frame(width: 44, height: 44)
                        Text(item.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isSelected ? Color("AccentGold") : .secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        isSelected ? Color("AccentGold").opacity(0.15) : Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color("AccentGold").opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.glassRounded(cornerRadius: 12))
                .animation(.spring(duration: 0.2), value: isSelected)
            }
        }
        .padding(12)
    }

    // MARK: - Multi-select icon grid

    private func multiIconGrid(
        items: [LogRoadType],
        selected: Binding<Set<LogRoadType>>
    ) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
            ForEach(items) { item in
                let isSelected = selected.wrappedValue.contains(item)
                Button {
                    if isSelected {
                        selected.wrappedValue.remove(item)
                    } else {
                        selected.wrappedValue.insert(item)
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(isSelected ? Color("AccentGold") : .secondary)
                            .frame(width: 44, height: 44)
                        Text(item.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isSelected ? Color("AccentGold") : .secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        isSelected ? Color("AccentGold").opacity(0.15) : Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color("AccentGold").opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.glassRounded(cornerRadius: 12))
                .animation(.spring(duration: 0.2), value: isSelected)
            }
        }
        .padding(12)
    }

    // MARK: - Save

    private func save() {
        var entry = LogEntry()
        entry.date = date
        entry.startTime = startTime
        entry.endTime = endTime
        entry.startSuburb = startSuburb
        entry.endSuburb = endSuburb
        entry.startOdometer = Double(startOdometer) ?? 0
        entry.endOdometer = Double(endOdometer) ?? 0
        entry.isNight = isNight
        entry.supervisorName = supervisor
        entry.weather = weather
        entry.roadTypes = roadTypes
        entry.traffic = traffic
        entry.feel = feel
        entry.notes = notes
        onSave(entry)
        dismiss()
    }
    
    private func suburbSuggestions(
        for text: Binding<String>,
        focused: FocusState<Bool>.Binding,
        show: Binding<Bool>
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(placesService.suggestions.prefix(3)) { place in
                Button {
                    text.wrappedValue = place.title
                    show.wrappedValue = false
                    focused.wrappedValue = false
                    placesService.clear()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Color("AccentGold"))
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(place.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if !place.subtitle.isEmpty {
                                Text(place.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if place.id != placesService.suggestions.prefix(3).last?.id {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.15), value: placesService.suggestions.count)
    }
}

// MARK: - Protocol for icon grid items

protocol HasDisplayInfo {
    var displayName: String { get }
    var icon: String { get }
}

extension WeatherCondition: HasDisplayInfo {}
extension TrafficLevel: HasDisplayInfo {}
extension DriveFeel: HasDisplayInfo {}
extension LogRoadType: HasDisplayInfo {}

// MARK: - Logs Viewing
struct LogEntryDetailView: View {
    var entry: LogEntry

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Header
                HStack(spacing: 14) {
                    Image(systemName: entry.isNight ? "moon.stars.fill" : "sun.max.fill")
                        .foregroundStyle(entry.isNight ? .indigo : .yellow)
                        .font(.system(size: 22))
                        .frame(width: 48, height: 48)
                        .background(
                            (entry.isNight ? Color.indigo : Color.yellow).opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.date.formatted(date: .long, time: .omitted))
                            .font(.system(size: 17, weight: .semibold))
                        Text(entry.isNight ? "Night drive" : "Day drive")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))

                // Stats
                HStack(spacing: 0) {
                    statBox(value: "\(entry.durationMinutes)", unit: "min")
                    Divider().frame(height: 36).padding(.horizontal, 8)
                    statBox(value: String(format: "%.1f", entry.distanceKm), unit: "km")
                    Divider().frame(height: 36).padding(.horizontal, 8)
                    statBox(value: entry.startTime.formatted(date: .omitted, time: .shortened), unit: "start")
                    Divider().frame(height: 36).padding(.horizontal, 8)
                    statBox(value: entry.endTime.formatted(date: .omitted, time: .shortened), unit: "end")
                }
                .padding(.vertical, 14)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))

                // Details rows
                detailSection(title: "Location") {
                    if !entry.startSuburb.isEmpty || !entry.endSuburb.isEmpty {
                        detailRow(icon: "mappin.circle", label: "Start", value: entry.startSuburb.isEmpty ? "—" : entry.startSuburb)
                        Divider().padding(.leading, 44)
                        detailRow(icon: "mappin.circle.fill", label: "End", value: entry.endSuburb.isEmpty ? "—" : entry.endSuburb)
                    } else {
                        detailRow(icon: "mappin.slash", label: "No suburbs logged", value: "")
                    }
                }

                detailSection(title: "Odometer") {
                    detailRow(icon: "gauge", label: "Start", value: String(format: "%.0f km", entry.startOdometer))
                    Divider().padding(.leading, 44)
                    detailRow(icon: "gauge.with.dots.needle.100percent", label: "End", value: String(format: "%.0f km", entry.endOdometer))
                }

                detailSection(title: "Supervisor") {
                    detailRow(icon: "person.2", label: "Name", value: entry.supervisorName.isEmpty ? "—" : entry.supervisorName)
                }

                detailSection(title: "Conditions") {
                    detailRow(icon: entry.weather.icon, label: "Weather", value: entry.weather.displayName)
                    Divider().padding(.leading, 44)
                    detailRow(icon: entry.traffic.icon, label: "Traffic", value: entry.traffic.displayName)
                    Divider().padding(.leading, 44)
                    detailRow(icon: entry.feel.icon, label: "Feel", value: entry.feel.displayName)
                }

                if !entry.roadTypes.isEmpty {
                    detailSection(title: "Road types") {
                        FlowLayout(items: Array(entry.roadTypes)) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color("AccentGold").opacity(0.1), in: Capsule())
                                .foregroundStyle(Color("AccentGold"))
                        }
                        .padding(14)
                    }
                }

                if !entry.notes.isEmpty {
                    detailSection(title: "Notes") {
                        Text(entry.notes)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Drive Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statBox(value: String, unit: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(unit)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color("AccentGold"))
                .frame(width: 28)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
