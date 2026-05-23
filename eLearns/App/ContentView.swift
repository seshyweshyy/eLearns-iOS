import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            MapTabView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(AppTab.map)

            LogbookView()
                .tabItem {
                    Label("Logbook", systemImage: "book.fill")
                }
                .tag(AppTab.logbook)

            RoutesView()
                .tabItem {
                    Label("Routes", systemImage: "road.lanes")
                }
                .tag(AppTab.routes)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(AppTab.profile)
        }
        .tint(Color("AccentGold"))
        .preferredColorScheme(appState.theme.colorScheme)
        .environmentObject(appState)
    }
}
