import Foundation

struct FlashcardSet: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let userID: Int?
    let fromLanguage: String?
    let toLanguage: String?
    let isAIGenerated: Bool
    let tags: [String]
    let isPublic: Bool
    let publicCode: String?
    let joinedFromCode: String?
    let createdAt: String?
    let words: [Word]
    private let serverWordCount: Int?

    var wordCount: Int {
        serverWordCount ?? words.count
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case userID = "userId"
        case fromLanguage
        case toLanguage
        case isAIGenerated
        case tags
        case isPublic
        case publicCode
        case joinedFromCode
        case createdAt
        case words
        case serverWordCount = "wordCount"
    }

    init(
        id: Int,
        name: String,
        userID: Int? = nil,
        fromLanguage: String? = nil,
        toLanguage: String? = nil,
        isAIGenerated: Bool = false,
        tags: [String] = [],
        isPublic: Bool = false,
        publicCode: String? = nil,
        joinedFromCode: String? = nil,
        createdAt: String? = nil,
        words: [Word] = [],
        wordCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.userID = userID
        self.fromLanguage = fromLanguage
        self.toLanguage = toLanguage
        self.isAIGenerated = isAIGenerated
        self.tags = tags
        self.isPublic = isPublic
        self.publicCode = publicCode
        self.joinedFromCode = joinedFromCode
        self.createdAt = createdAt
        self.words = words
        self.serverWordCount = wordCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        userID = try container.decodeIfPresent(Int.self, forKey: .userID)
        fromLanguage = try container.decodeIfPresent(
            String.self,
            forKey: .fromLanguage
        )
        toLanguage = try container.decodeIfPresent(
            String.self,
            forKey: .toLanguage
        )
        isAIGenerated = try container.decodeIfPresent(
            Bool.self,
            forKey: .isAIGenerated
        ) ?? false
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isPublic = try container.decodeIfPresent(
            Bool.self,
            forKey: .isPublic
        ) ?? false
        publicCode = try container.decodeIfPresent(
            String.self,
            forKey: .publicCode
        )
        joinedFromCode = try container.decodeIfPresent(
            String.self,
            forKey: .joinedFromCode
        )
        createdAt = try container.decodeIfPresent(
            String.self,
            forKey: .createdAt
        )
        words = try container.decodeIfPresent([Word].self, forKey: .words) ?? []
        serverWordCount = try container.decodeIfPresent(
            Int.self,
            forKey: .serverWordCount
        )
    }
}
