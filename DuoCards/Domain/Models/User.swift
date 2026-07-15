import Foundation

struct User: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let email: String
    let nickname: String
    let locale: String?
    let createdAt: String?

    init(
        id: Int,
        email: String,
        nickname: String,
        locale: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.email = email
        self.nickname = nickname
        self.locale = locale
        self.createdAt = createdAt
    }
}
