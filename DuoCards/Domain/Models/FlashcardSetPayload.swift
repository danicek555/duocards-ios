import Foundation

struct FlashcardWordPayload: Encodable, Equatable, Sendable {
    let id: Int?
    let word: String
    let translation: String
    let difficulty: Int
    let pronunciation: String?
}

struct FlashcardSetPayload: Encodable, Equatable, Sendable {
    let name: String
    let fromLanguage: String?
    let toLanguage: String?
    let tags: [String]
    let words: [FlashcardWordPayload]
}
