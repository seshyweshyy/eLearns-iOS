import SwiftUI
import GoogleMaps

@main
struct eLearnsApp: App {

    init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
        GMSServices.provideAPIKey(key)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
