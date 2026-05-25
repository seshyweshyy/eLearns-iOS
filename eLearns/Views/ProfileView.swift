import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var isEditing = false
    @State private var selectedPhoto: PhotosPickerItem? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Avatar + name
                    profileHeader

                    // Stats
                    statsGrid

                    // Settings list
                    settingsList
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation { isEditing.toggle() }
                        if !isEditing { appState.saveAll() }
                    }
                }
            }
        }
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar circle
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    Circle()
                        .fill(Color("AccentGold").opacity(0.15))
                        .frame(width: 72, height: 72)
                    if let data = appState.profile.avatarData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                    } else {
                        Text(appState.profile.name.prefix(1).uppercased().isEmpty ? "L" : String(appState.profile.name.prefix(1).uppercased()))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color("AccentGold"))
                    }
                    // Camera badge
                    if isEditing {
                        Circle()
                            .fill(Color("AccentGold"))
                            .frame(width: 22, height: 22)
                            .overlay(Image(systemName: "camera.fill").font(.system(size: 10)).foregroundStyle(.black))
                            .offset(x: 24, y: 24)
                    }
                }
            }
            .disabled(!isEditing)
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        appState.profile.avatarData = data
                        appState.saveAll()
                    }
                }
            }

            VStack(spacing: 4) {
                if isEditing {
                    TextField("Your name", text: $appState.profile.name)
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color("AccentGold").opacity(0.4), lineWidth: 1.5)
                        )
                        .frame(maxWidth: 220)
                } else {
                    Text(appState.profile.name.isEmpty ? "Set your name" : appState.profile.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(appState.profile.name.isEmpty ? .secondary : .primary)
                }

                Text(appState.profile.licenceType.displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color("AccentGold").opacity(0.1), in: Capsule())
                    .foregroundStyle(Color("AccentGold"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        HStack(spacing: 10) {
            statBox(value: "\(appState.savedRoutes.count)", label: "Routes")
            statBox(value: String(format: "%.0f", totalKm), label: "km driven")
            statBox(value: "\(appState.totalDayMinutes() / 60 + appState.totalNightMinutes() / 60)", label: "Hours")
        }
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var totalKm: Double {
        appState.logEntries.reduce(0) { $0 + $1.distanceKm }
    }

    // MARK: - Settings list

    private var settingsList: some View {
        VStack(spacing: 8) {

            // Appearance
            settingRow(icon: appState.theme.icon, label: "Appearance") {
                Menu {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            appState.theme = theme
                        } label: {
                            Label(theme.displayName, systemImage: theme.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: appState.theme.icon)
                            .font(.system(size: 12))
                        Text(appState.theme.displayName)
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(Color("AccentGold"))
                    .frame(minWidth: 110, alignment: .trailing)
                    .animation(nil, value: appState.theme)
                }
            }

            // Licence
            settingRow(icon: "creditcard", label: "Licence") {
                if isEditing {
                    Picker("", selection: $appState.profile.licenceType) {
                        ForEach(LicenceType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                } else {
                    Text(appState.profile.licenceType.displayName)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
            }

            // Supervisor
            settingRow(icon: "person.2", label: "Supervisor") {
                if isEditing {
                    TextField("Name", text: $appState.profile.supervisorName)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 14))
                } else {
                    Text(appState.profile.supervisorName.isEmpty ? "Not set" : appState.profile.supervisorName)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
            }

            // Licence number
            settingRow(icon: "number", label: "Licence #") {
                if isEditing {
                    TextField("Number", text: $appState.profile.licenceNumber)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 14))
                } else {
                    Text(appState.profile.licenceNumber.isEmpty ? "Not set" : appState.profile.licenceNumber)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
            }

            if isEditing {
                // Initial hours (if transferring from paper logbook)
                settingRow(icon: "sun.max", label: "Prior day hours") {
                    Stepper("\(appState.profile.initialDayMinutes / 60)h", value: Binding(
                        get: { appState.profile.initialDayMinutes / 60 },
                        set: { appState.profile.initialDayMinutes = $0 * 60 }
                    ), in: 0...100)
                }

                settingRow(icon: "moon.stars", label: "Prior night hours") {
                    Stepper("\(appState.profile.initialNightMinutes / 60)h", value: Binding(
                        get: { appState.profile.initialNightMinutes / 60 },
                        set: { appState.profile.initialNightMinutes = $0 * 60 }
                    ), in: 0...20)
                }
            }
        }
    }

    private func settingRow<Content: View>(
        icon: String,
        label: String,
        @ViewBuilder trailing: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color("AccentGold"))
                .frame(width: 28)
            Text(label)
                .font(.system(size: 15))
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}
