import Foundation
import CoreLocation
import Combine

struct PlaceResult: Identifiable, Hashable {
    let id: String          // place_id
    let title: String       // primary text
    let subtitle: String    // secondary text
    var coordinate: CLLocationCoordinate2D?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PlaceResult, rhs: PlaceResult) -> Bool { lhs.id == rhs.id }
}

@MainActor
class PlacesSearchService: ObservableObject {

    static let shared = PlacesSearchService()

    @Published var suggestions: [PlaceResult] = []
    @Published var isLoading = false

    private let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
    private var debounceTask: Task<Void, Never>?

    // MARK: - Autocomplete

    func search(_ query: String, near location: CLLocationCoordinate2D?) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            suggestions = []
            isLoading = false
            return
        }

        isLoading = true

        let url = URL(string: "https://places.googleapis.com/v1/places:autocomplete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        var body: [String: Any] = [
            "input": query,
            "languageCode": "en",
            "regionCode": "AU",
            "includedRegionCodes": ["AU"]
        ]
        if let loc = location {
            body["locationBias"] = [
                "circle": [
                    "center": [
                        "latitude": loc.latitude,
                        "longitude": loc.longitude
                    ],
                    "radius": 20000.0
                ]
            ]
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(NewAutocompleteResponse.self, from: data)
            suggestions = decoded.suggestions?.compactMap { suggestion in
                guard let place = suggestion.placePrediction else { return nil }
                return PlaceResult(
                    id:       place.placeId,
                    title:    place.structuredFormat.mainText.text,
                    subtitle: place.structuredFormat.secondaryText?.text ?? ""
                )
            } ?? []
        } catch {
            print("❌ Search error: \(error)")
            suggestions = []
        }
        isLoading = false
    }

    // MARK: - Get coordinates for a place

    func fetchCoordinate(for placeID: String) async -> CLLocationCoordinate2D? {
        let url = URL(string: "https://places.googleapis.com/v1/places/\(placeID)")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("location", forHTTPHeaderField: "X-Goog-FieldMask")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(NewPlaceDetailsResponse.self, from: data)
            return CLLocationCoordinate2D(
                latitude: decoded.location.latitude,
                longitude: decoded.location.longitude
            )
        } catch {
            return nil
        }
    }

    func clear() {
        suggestions = []
    }
}

// MARK: - Response models

private struct NewAutocompleteResponse: Codable {
    let suggestions: [AutocompleteSuggestion]?
}

private struct AutocompleteSuggestion: Codable {
    let placePrediction: PlacePrediction?
}

private struct PlacePrediction: Codable {
    let placeId: String
    let structuredFormat: StructuredFormat
}

private struct StructuredFormat: Codable {
    let mainText: FormattedText
    let secondaryText: FormattedText?
}

private struct FormattedText: Codable {
    let text: String
}

private struct NewPlaceDetailsResponse: Codable {
    let location: NewLatLng
}

private struct NewLatLng: Codable {
    let latitude: Double
    let longitude: Double
}
