import Foundation
import Combine

struct Sponsor: Codable, Identifiable {
    let id: String
    let name: String
    let logo: String?
    let tier: String
    let url: String?
}

@MainActor
final class SponsorService: ObservableObject {
    static let shared = SponsorService()

    @Published private(set) var sponsors: [Sponsor] = []

    private let jsonURL = URL(string: "https://raw.githubusercontent.com/lucianfialho/periquito/main/sponsors.json")!

    func load() async {
        guard let (data, _) = try? await URLSession.shared.data(from: jsonURL) else { return }
        guard let decoded = try? JSONDecoder().decode([Sponsor].self, from: data) else { return }
        // Filter out placeholder entry
        sponsors = decoded.filter { $0.id != "example" }
    }
}
