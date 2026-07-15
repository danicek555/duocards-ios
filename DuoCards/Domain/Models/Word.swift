import Foundation

struct WordImage: Codable, Hashable, Sendable {
    let id: Int
    let dataURL: String
    let mimeType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case dataURL = "dataUrl"
        case mimeType
    }

    init(id: Int, dataURL: String, mimeType: String? = nil) {
        self.id = id
        self.dataURL = dataURL
        self.mimeType = mimeType
    }
}

struct WordAudio: Codable, Hashable, Sendable {
    let id: Int
    let dataURL: String
    let mimeType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case dataURL = "dataUrl"
        case mimeType
    }

    init(id: Int, dataURL: String, mimeType: String? = nil) {
        self.id = id
        self.dataURL = dataURL
        self.mimeType = mimeType
    }
}

struct Word: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let word: String
    let translation: String
    let difficulty: Int
    let pronunciation: String?
    let imageID: Int?
    let audioID: Int?
    let image: WordImage?
    let audio: WordAudio?

    var imageDataURL: String? { image?.dataURL }
    var audioDataURL: String? { audio?.dataURL }

    enum CodingKeys: String, CodingKey {
        case id
        case word
        case translation
        case difficulty
        case pronunciation
        case imageID = "imageId"
        case audioID = "audioId"
        case image
        case audio
    }

    init(
        id: Int,
        word: String,
        translation: String,
        difficulty: Int = 1,
        pronunciation: String? = nil,
        imageID: Int? = nil,
        audioID: Int? = nil,
        image: WordImage? = nil,
        audio: WordAudio? = nil
    ) {
        self.id = id
        self.word = word
        self.translation = translation
        self.difficulty = difficulty
        self.pronunciation = pronunciation
        self.imageID = imageID
        self.audioID = audioID
        self.image = image
        self.audio = audio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        word = try container.decodeIfPresent(String.self, forKey: .word) ?? ""
        translation = try container.decodeIfPresent(
            String.self,
            forKey: .translation
        ) ?? ""
        difficulty = try container.decodeIfPresent(
            Int.self,
            forKey: .difficulty
        ) ?? 1
        pronunciation = try container.decodeIfPresent(
            String.self,
            forKey: .pronunciation
        )
        imageID = try container.decodeIfPresent(Int.self, forKey: .imageID)
        audioID = try container.decodeIfPresent(Int.self, forKey: .audioID)
        image = try container.decodeIfPresent(WordImage.self, forKey: .image)
        audio = try container.decodeIfPresent(WordAudio.self, forKey: .audio)
    }
}
