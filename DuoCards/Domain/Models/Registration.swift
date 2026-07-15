import Foundation

struct RegistrationRequest: Codable, Equatable, Sendable {
    let email: String
    let password: String
    let nickname: String
    let locale: String
}

struct RegistrationResponse: Codable, Equatable, Sendable {
    let email: String
    let requiresVerification: Bool
}

struct VerificationRequest: Codable, Equatable, Sendable {
    let email: String
    let code: String
}

struct ResendVerificationRequest: Codable, Equatable, Sendable {
    let email: String
}
