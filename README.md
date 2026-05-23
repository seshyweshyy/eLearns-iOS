# eLearns iOS

NSW Learner & Provisional Route Builder — native iOS app built with SwiftUI and the Google Maps Navigation SDK.

## What it does

eLearns helps NSW learner drivers log practice hours and build GPS loop routes tailored to the roads they need to practice. It tracks progress toward the 120-hour logbook requirement and provides real turn-by-turn navigation for each route.

## Features

- **Route wizard** — pick road types (residential, main roads, multi-lane, roundabouts, hills, parking), set radius and duration, generate loop routes from your current location via Google Directions API
- **Turn-by-turn navigation** — real Google Maps Navigation SDK with 3D buildings, 60° tilt camera, speed display, ETA, and remaining distance
- **Logbook** — log day and night drives, track progress toward NSW 120-hour requirement with separate day/night hour bars
- **Saved routes** — save and replay any generated route
- **Driver profile** — licence type, supervisor name, prior hours from paper logbook
- **Liquid Glass UI** — iOS 26 native glass effects with interactive press morphing, falls back to `.ultraThinMaterial` on iOS 16–25
- **Dark/light/system theme** — cloud-based Google Maps styling via Map ID, SwiftUI colour scheme preference persisted across sessions

## Tech stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Maps | Google Maps SDK for iOS |
| Navigation | Google Navigation SDK for iOS |
| Routing | Google Directions API |
| Location | CoreLocation |
| Persistence | UserDefaults + AppStorage |
| Minimum iOS | 16.0 |

## Project structure

```
eLearns/
├── App/
│   ├── eLearnsApp.swift          ← Entry point, Google Maps init
│   ├── ContentView.swift         ← Tab bar root
│   └── AppState.swift            ← Global state, persistence, AppTheme enum
│
├── Models/
│   └── Models.swift              ← Route, LogEntry, UserProfile, Waypoint, RoadType
│
├── Services/
│   ├── LocationService.swift     ← CLLocationManager wrapper
│   ├── RouteService.swift        ← Google Directions API, route generation
│   └── NavigationService.swift   ← GMSNavigator wrapper
│
└── Views/
    ├── MapTabView.swift           ← Main map screen
    ├── GoogleMapView.swift        ← GMSMapView UIViewRepresentable, 3D nav camera
    ├── GlassModifiers.swift       ← Liquid Glass view modifiers + button styles
    ├── NavigationOverlayView.swift← Turn card, speed, ETA bar
    ├── RouteWizardView.swift      ← 4-step route builder wizard
    ├── RoutePreviewSheet.swift    ← Turn-by-turn preview before driving
    ├── LogbookView.swift          ← Hours tracker, log entries
    ├── RoutesView.swift           ← Saved routes list
    └── ProfileView.swift          ← Driver profile, appearance settings
```

## Setup

### Requirements

- Xcode 16+
- iOS 16.0+ deployment target
- Google Maps API key with the following APIs enabled:
  - Maps SDK for iOS
  - Navigation SDK for iOS
  - Directions API
  - Places API (New)
  - Routes API
  - Roads API

### Installation

1. Clone the repo
2. Open `eLearns.xcodeproj` in Xcode
3. Add Swift Package dependencies:
   - `https://github.com/googlemaps/ios-maps-sdk`
   - `https://github.com/googlemaps/ios-navigation-sdk`
4. Create `eLearns/Secrets.xcconfig` (gitignored):
   ```
   GOOGLE_MAPS_API_KEY = your_key_here
   ```
5. Set `Secrets.xcconfig` as the configuration file for Debug and Release under the project Info tab
6. Replace `YOUR_MAP_ID` in `GoogleMapView.swift` with your Google Cloud Map ID
7. Add `AccentGold` colour (`#F5C842`) to `Assets.xcassets`
8. Build and run

### API key restriction

- **Simulator** → set key restriction to None in Google Cloud Console
- **Real device / production** → restrict to bundle ID `seshyweshyy.eLearns`

## Roadmap

- [ ] Places API address search for waypoints
- [ ] Arrive → auto log-drive prompt
- [ ] Speed limit display via Roads API
- [ ] Supabase sync (port from web app)
- [ ] POI landmarks along route
- [ ] App icon
- [ ] App Store submission

## Related

[eLearns.au](https://elearns.au) — the web version this app is based on
