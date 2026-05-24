import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            MapTabView()
                .tabItem {
                    Label(
                        "Map",
                        systemImage: appState.selectedTab == .map ? "map.fill" : "map"
                    )
                    .environment(\.symbolVariants, .none) // Completely strips the forced global autofill
                }
                .tag(AppTab.map)

            LogbookView()
                .tabItem {
                    Label(
                        "Logbook",
                        systemImage: appState.selectedTab == .logbook ? "book.fill" : "book"
                    )
                    .environment(\.symbolVariants, .none)
                }
                .tag(AppTab.logbook)

            RoutesView()
                .tabItem {
                    Label(
                        "Routes",
                        systemImage: appState.selectedTab == .routes ? "point.bottomleft.forward.to.point.topright.scurvepath.fill" : "point.bottomleft.forward.to.point.topright.scurvepath"
                    )
                    .environment(\.symbolVariants, .none)
                }
                .tag(AppTab.routes)

            ProfileView()
                .tabItem {
                    Label(
                        "Profile",
                        systemImage: appState.selectedTab == .profile ? "person.fill" : "person"
                    )
                    .environment(\.symbolVariants, .none)
                }
                .tag(AppTab.profile)
        }
        .tint(Color("AccentGold"))
        .preferredColorScheme(appState.theme.colorScheme)
        .environmentObject(appState)
    }
}
