import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            MapTabView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(AppTab.map)

            LogbookView()
                .tabItem {
                    Label("Logbook", systemImage: "book")
                }
                .tag(AppTab.logbook)

            RoutesView()
                .tabItem {
                    Label("Routes", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                }
                .tag(AppTab.routes)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(AppTab.profile)
        }
        .tint(Color("AccentGold"))
        .preferredColorScheme(appState.theme.colorScheme)
        .environmentObject(appState)
    }
}
