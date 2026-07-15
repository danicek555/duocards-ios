import Foundation
import Observation

@MainActor
@Observable
final class SetDetailViewModel {
    private let api: any DuoCardsAPI
    private let setID: Int

    private(set) var set: FlashcardSet
    private(set) var isLoading = false
    private(set) var isDeleting = false
    private(set) var isUnauthorized = false
    var errorMessage: String?
    var mutationErrorMessage: String?

    init(set: FlashcardSet, api: any DuoCardsAPI) {
        self.set = set
        setID = set.id
        self.api = api
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        isUnauthorized = false
        errorMessage = nil
        defer { isLoading = false }

        do {
            set = try await api.fetchFlashcardSet(id: setID)
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

    func replace(with set: FlashcardSet) {
        self.set = set
        errorMessage = nil
    }

    func delete() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        isUnauthorized = false
        mutationErrorMessage = nil
        defer { isDeleting = false }

        do {
            try await api.deleteFlashcardSet(id: setID)
            return true
        } catch let error as APIError {
            if case .unauthorized = error {
                isUnauthorized = true
            } else {
                mutationErrorMessage = error.errorDescription
            }
        } catch {
            mutationErrorMessage = error.localizedDescription
        }
        return false
    }
}
