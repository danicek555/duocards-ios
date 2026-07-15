import Foundation
import Observation

@MainActor
@Observable
final class StudyViewModel {
    private(set) var words: [Word]
    private(set) var currentIndex = 0
    private(set) var imageDataURLs: [Int: String] = [:]
    private(set) var audioDataURLs: [Int: String] = [:]
    private(set) var isLoadingMedia = false
    private(set) var isUnauthorized = false
    var mediaErrorMessage: String?
    private let api: any DuoCardsAPI

    var currentWord: Word? {
        words.indices.contains(currentIndex) ? words[currentIndex] : nil
    }

    var hasPrevious: Bool {
        currentIndex > 0
    }

    var hasNext: Bool {
        currentIndex < words.count - 1
    }

    var progress: Double {
        guard !words.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(words.count)
    }

    var currentImageDataURL: String? {
        guard let word = currentWord else { return nil }
        if let embedded = word.imageDataURL { return embedded }
        return word.imageID.flatMap { imageDataURLs[$0] }
    }

    var currentAudioDataURL: String? {
        guard let word = currentWord else { return nil }
        if let embedded = word.audioDataURL { return embedded }
        return word.audioID.flatMap { audioDataURLs[$0] }
    }

    init(
        words: [Word],
        api: any DuoCardsAPI,
        shuffle: Bool = true
    ) {
        self.words = shuffle ? words.shuffled() : words
        self.api = api
    }

    func previous() {
        guard hasPrevious else { return }
        currentIndex -= 1
    }

    func next() {
        guard hasNext else { return }
        currentIndex += 1
    }

    func loadCurrentMedia() async {
        guard let word = currentWord else { return }
        let needsImage = word.imageDataURL == nil
            && word.imageID.map { imageDataURLs[$0] == nil } == true
        let needsAudio = word.audioDataURL == nil
            && word.audioID.map { audioDataURLs[$0] == nil } == true
        guard needsImage || needsAudio else { return }

        isLoadingMedia = true
        mediaErrorMessage = nil
        defer { isLoadingMedia = false }

        if needsImage, let imageID = word.imageID {
            do {
                let image = try await api.fetchWordImage(id: imageID)
                imageDataURLs[imageID] = image.dataURL
            } catch {
                handleMediaError(error)
            }
        }

        guard !isUnauthorized else { return }

        if needsAudio, let audioID = word.audioID {
            do {
                let audio = try await api.fetchWordAudio(id: audioID)
                audioDataURLs[audioID] = audio.dataURL
            } catch {
                handleMediaError(error)
            }
        }
    }

    private func handleMediaError(_ error: Error) {
        if let apiError = error as? APIError,
           case .unauthorized = apiError {
            isUnauthorized = true
        } else {
            mediaErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Média ke kartě se nepodařilo načíst."
        }
    }
}
