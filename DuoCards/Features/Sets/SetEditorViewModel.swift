import Foundation
import Observation

struct EditableFlashcard: Identifiable, Equatable, Sendable {
    let id: UUID
    var serverID: Int?
    var word: String
    var translation: String
    var difficulty: Int
    var pronunciation: String

    init(
        id: UUID = UUID(),
        serverID: Int? = nil,
        word: String = "",
        translation: String = "",
        difficulty: Int = 1,
        pronunciation: String = ""
    ) {
        self.id = id
        self.serverID = serverID
        self.word = word
        self.translation = translation
        self.difficulty = difficulty
        self.pronunciation = pronunciation
    }

    init(word: Word) {
        self.init(
            serverID: word.id > 0 ? word.id : nil,
            word: word.word,
            translation: word.translation,
            difficulty: min(max(word.difficulty, 1), 4),
            pronunciation: word.pronunciation ?? ""
        )
    }
}

struct SetEditorForm: Equatable, Sendable {
    var name: String
    var fromLanguage: String
    var toLanguage: String
    var tags: [String]
    var words: [EditableFlashcard]

    init(
        name: String = "",
        fromLanguage: String = "",
        toLanguage: String = "",
        tags: [String] = [],
        words: [EditableFlashcard] = [EditableFlashcard()]
    ) {
        self.name = name
        self.fromLanguage = fromLanguage
        self.toLanguage = toLanguage
        self.tags = tags
        self.words = words
    }

    init(set: FlashcardSet) {
        name = set.name
        fromLanguage = set.fromLanguage ?? ""
        toLanguage = set.toLanguage ?? ""
        tags = set.tags
        words = set.words.isEmpty
            ? [EditableFlashcard()]
            : set.words.map(EditableFlashcard.init(word:))
    }

    func validatedPayload() throws -> FlashcardSetPayload {
        let normalizedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedName.isEmpty else {
            throw SetEditorValidationError.emptyName
        }
        guard (1...100).contains(words.count) else {
            throw SetEditorValidationError.invalidWordCount
        }

        var normalizedTags: [String] = []
        for rawTag in tags {
            let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty else { continue }
            let isDuplicate = normalizedTags.contains {
                $0.caseInsensitiveCompare(tag) == .orderedSame
            }
            if !isDuplicate {
                normalizedTags.append(tag)
            }
        }
        guard normalizedTags.count <= 5 else {
            throw SetEditorValidationError.tooManyTags
        }

        let payloadWords = try words.enumerated().map { index, card in
            let word = card.word.trimmingCharacters(in: .whitespacesAndNewlines)
            let translation = card.translation.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !word.isEmpty, !translation.isEmpty else {
                throw SetEditorValidationError.incompleteWord(index: index + 1)
            }
            guard (1...4).contains(card.difficulty) else {
                throw SetEditorValidationError.invalidDifficulty(index: index + 1)
            }
            let pronunciation = card.pronunciation.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return FlashcardWordPayload(
                id: card.serverID,
                word: word,
                translation: translation,
                difficulty: card.difficulty,
                pronunciation: pronunciation.isEmpty ? nil : pronunciation
            )
        }

        return FlashcardSetPayload(
            name: normalizedName,
            fromLanguage: normalizedOptional(fromLanguage),
            toLanguage: normalizedOptional(toLanguage),
            tags: normalizedTags,
            words: payloadWords
        )
    }

    private func normalizedOptional(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

enum SetEditorValidationError: LocalizedError, Equatable, Sendable {
    case emptyName
    case invalidWordCount
    case incompleteWord(index: Int)
    case invalidDifficulty(index: Int)
    case tooManyTags

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "Zadejte název sady."
        case .invalidWordCount:
            "Sada musí obsahovat 1 až 100 karet."
        case let .incompleteWord(index):
            "Karta \(index) musí mít vyplněné slovo i překlad."
        case let .invalidDifficulty(index):
            "Karta \(index) má neplatnou obtížnost."
        case .tooManyTags:
            "Sada může obsahovat nejvýše 5 tagů."
        }
    }
}

@MainActor
@Observable
final class SetEditorViewModel {
    static let maximumWords = 100
    static let maximumTags = 5

    private let api: any DuoCardsAPI
    private let setID: Int?

    var form: SetEditorForm
    var pendingTag = ""
    private(set) var isSaving = false
    private(set) var isUnauthorized = false
    var errorMessage: String?

    var isEditing: Bool { setID != nil }
    var title: String { isEditing ? "Upravit sadu" : "Nová sada" }
    var saveTitle: String { isEditing ? "Uložit" : "Vytvořit" }

    init(api: any DuoCardsAPI, set: FlashcardSet? = nil) {
        self.api = api
        setID = set?.id
        form = set.map(SetEditorForm.init(set:)) ?? SetEditorForm()
    }

    func addWord() {
        guard form.words.count < Self.maximumWords else { return }
        form.words.append(EditableFlashcard())
    }

    func removeWord(id: UUID) {
        guard form.words.count > 1 else { return }
        form.words.removeAll { $0.id == id }
    }

    func addPendingTag() {
        let tag = pendingTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        guard form.tags.count < Self.maximumTags else {
            errorMessage = SetEditorValidationError.tooManyTags.errorDescription
            return
        }
        guard !form.tags.contains(where: {
            $0.caseInsensitiveCompare(tag) == .orderedSame
        }) else {
            pendingTag = ""
            return
        }
        form.tags.append(tag)
        pendingTag = ""
        errorMessage = nil
    }

    func removeTag(_ tag: String) {
        form.tags.removeAll { $0 == tag }
    }

    func save() async -> FlashcardSet? {
        let payload: FlashcardSetPayload
        do {
            payload = try form.validatedPayload()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            return nil
        }

        isSaving = true
        isUnauthorized = false
        errorMessage = nil
        defer { isSaving = false }

        do {
            if let setID {
                return try await api.updateFlashcardSet(
                    id: setID,
                    payload: payload
                )
            }
            return try await api.createFlashcardSet(payload: payload)
        } catch let error as APIError {
            if case .unauthorized = error {
                isUnauthorized = true
            } else {
                errorMessage = error.errorDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return nil
    }
}
