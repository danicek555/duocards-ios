import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    private let api: any DuoCardsAPI

    private(set) var sets: [FlashcardSet] = []
    private(set) var coins: Int?
    private(set) var isLoading = false
    private(set) var isUnauthorized = false
    var errorMessage: String?

    var totalWords: Int {
        sets.reduce(0) { $0 + $1.wordCount }
    }

    init(api: any DuoCardsAPI) {
        self.api = api
    }

    func upsert(_ set: FlashcardSet) {
        if let index = sets.firstIndex(where: { $0.id == set.id }) {
            sets[index] = set
        } else {
            sets.insert(set, at: 0)
        }
    }

    func removeSet(id: Int) {
        sets.removeAll { $0.id == id }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        isUnauthorized = false
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedSets = api.fetchFlashcardSets()
            async let loadedCoins = api.fetchCoins()
            let (sets, coins) = try await (loadedSets, loadedCoins)
            self.sets = sets
            self.coins = coins
        } catch let error as APIError {
            if case .unauthorized = error {
                isUnauthorized = true
            } else {
                errorMessage = error.errorDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
