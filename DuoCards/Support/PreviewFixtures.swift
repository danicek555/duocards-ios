import Foundation

enum PreviewFixtures {
    static let user = User(
        id: 1,
        email: "demo@duocards.xyz",
        nickname: "Daniel",
        locale: "cs"
    )

    static let travelWords: [Word] = [
        Word(
            id: 1,
            word: "bonjour",
            translation: "ahoj",
            difficulty: 1,
            pronunciation: "/bɔ̃.ʒuʁ/"
        ),
        Word(
            id: 2,
            word: "la gare",
            translation: "nádraží",
            difficulty: 2,
            pronunciation: "/la ɡaʁ/"
        ),
        Word(
            id: 3,
            word: "Où est l'hôtel ?",
            translation: "Kde je hotel?",
            difficulty: 3
        ),
        Word(
            id: 4,
            word: "merci beaucoup",
            translation: "moc děkuji",
            difficulty: 1,
            pronunciation: "/mɛʁ.si bo.ku/"
        )
    ]

    static let travelSet = FlashcardSet(
        id: 101,
        name: "Francouzština na cesty",
        userID: user.id,
        fromLanguage: "French",
        toLanguage: "Czech",
        tags: ["Cestování", "A1"],
        words: travelWords
    )

    static let aiSet = FlashcardSet(
        id: 102,
        name: "Business English",
        userID: user.id,
        fromLanguage: "English",
        toLanguage: "Czech",
        isAIGenerated: true,
        tags: ["Práce", "B2"],
        words: [
            Word(
                id: 5,
                word: "deadline",
                translation: "termín",
                difficulty: 2
            ),
            Word(
                id: 6,
                word: "stakeholder",
                translation: "zainteresovaná strana",
                difficulty: 3
            )
        ]
    )

    static let allSets = [travelSet, aiSet]
}

actor MockDuoCardsAPI: DuoCardsAPI {
    private let user: User
    private var sets: [FlashcardSet]
    private let coins: Int
    private var nextSetID: Int
    private var nextWordID: Int

    init(
        user: User = PreviewFixtures.user,
        sets: [FlashcardSet] = PreviewFixtures.allSets,
        coins: Int = 245
    ) {
        self.user = user
        self.sets = sets
        self.coins = coins
        nextSetID = (sets.map(\.id).max() ?? 0) + 1
        nextWordID = (
            sets.flatMap(\.words).map(\.id).max() ?? 0
        ) + 1
    }

    func login(email: String, password: String) async throws -> User {
        user
    }

    func restoreSession() async throws -> User {
        user
    }

    func logout() async throws {}

    func fetchFlashcardSets() async throws -> [FlashcardSet] {
        sets
    }

    func fetchFlashcardSet(id: Int) async throws -> FlashcardSet {
        guard let set = sets.first(where: { $0.id == id }) else {
            throw APIError.server(
                status: 404,
                code: "SET_NOT_FOUND",
                message: "Sada nebyla nalezena."
            )
        }
        return set
    }

    func createFlashcardSet(
        payload: FlashcardSetPayload
    ) async throws -> FlashcardSet {
        let set = FlashcardSet(
            id: nextSetID,
            name: payload.name,
            userID: user.id,
            fromLanguage: payload.fromLanguage,
            toLanguage: payload.toLanguage,
            tags: payload.tags,
            words: materializeWords(payload.words)
        )
        nextSetID += 1
        sets.insert(set, at: 0)
        return set
    }

    func updateFlashcardSet(
        id: Int,
        payload: FlashcardSetPayload
    ) async throws -> FlashcardSet {
        guard let index = sets.firstIndex(where: { $0.id == id }) else {
            throw APIError.server(
                status: 404,
                code: "SET_NOT_FOUND",
                message: "Sada nebyla nalezena."
            )
        }
        let existing = sets[index]
        let updated = FlashcardSet(
            id: existing.id,
            name: payload.name,
            userID: existing.userID,
            fromLanguage: payload.fromLanguage,
            toLanguage: payload.toLanguage,
            isAIGenerated: existing.isAIGenerated,
            tags: payload.tags,
            isPublic: existing.isPublic,
            publicCode: existing.publicCode,
            joinedFromCode: existing.joinedFromCode,
            createdAt: existing.createdAt,
            words: materializeWords(payload.words)
        )
        sets[index] = updated
        return updated
    }

    func deleteFlashcardSet(id: Int) async throws {
        guard sets.contains(where: { $0.id == id }) else {
            throw APIError.server(
                status: 404,
                code: "SET_NOT_FOUND",
                message: "Sada nebyla nalezena."
            )
        }
        sets.removeAll { $0.id == id }
    }

    func fetchCoins() async throws -> Int {
        coins
    }

    func fetchWordImage(id: Int) async throws -> WordImage {
        WordImage(
            id: id,
            dataURL: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
            mimeType: "image/png"
        )
    }

    func fetchWordAudio(id: Int) async throws -> WordAudio {
        WordAudio(
            id: id,
            dataURL: "data:audio/mpeg;base64,",
            mimeType: "audio/mpeg"
        )
    }

    private func materializeWords(
        _ payloadWords: [FlashcardWordPayload]
    ) -> [Word] {
        payloadWords.map { payload in
            let wordID: Int
            if let existingID = payload.id, existingID > 0 {
                wordID = existingID
                nextWordID = max(nextWordID, existingID + 1)
            } else {
                wordID = nextWordID
                nextWordID += 1
            }
            return Word(
                id: wordID,
                word: payload.word,
                translation: payload.translation,
                difficulty: payload.difficulty,
                pronunciation: payload.pronunciation
            )
        }
    }
}
