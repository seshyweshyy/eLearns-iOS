import SwiftUI

struct LogbookView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Hours progress cards
                    hoursProgress

                    // Log entries
                    if appState.logEntries.isEmpty {
                        emptyState
                    } else {
                        logList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Logbook")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddLog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddLog) {
                AddLogEntryView { entry in
                    appState.addLogEntry(entry)
                }
            }
        }
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

    // MARK: - Log list

    private var logList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent drives")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(appState.logEntries) { entry in
                logEntryCard(entry)
            }
        }
    }

    private func logEntryCard(_ entry: LogEntry) -> some View {
        HStack(spacing: 14) {
            // Night/day indicator
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
                    if !entry.supervisorName.isEmpty {
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
    @State private var durationMinutes = 30
    @State private var distanceKm = ""
    @State private var isNight = false
    @State private var supervisor = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Drive details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 1...480)
                    HStack {
                        Text("Distance (km)")
                        Spacer()
                        TextField("0.0", text: $distanceKm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Night drive", isOn: $isNight)
                }

                Section("Supervisor") {
                    TextField("Supervisor name", text: $supervisor)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
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
                }
            }
        }
        .onAppear {
            supervisor = appState.profile.supervisorName
        }
    }

    private func save() {
        let entry = LogEntry(
            date: date,
            durationMinutes: durationMinutes,
            distanceKm: Double(distanceKm) ?? 0,
            isNight: isNight,
            supervisorName: supervisor,
            roadTypes: [],
            notes: notes
        )
        onSave(entry)
        dismiss()
    }
}
