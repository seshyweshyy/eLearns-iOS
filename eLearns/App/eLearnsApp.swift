import SwiftUI
import GoogleMaps
import GoogleNavigation

@main
struct eLearnsApp: App {

    init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
        GMSServices.provideAPIKey(key)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    showNavTermsIfNeeded()
                }
        }
    }

    private func showNavTermsIfNeeded() {
        let options = GMSNavigationTermsAndConditionsOptions(companyName: "eLearns")
        GMSNavigationServices.showTermsAndConditionsDialogIfNeeded(with: options) { termsAccepted in
            if termsAccepted {
                GMSNavigationServices.setAbnormalTerminationReportingEnabled(true)
            }
        }
    }
}
