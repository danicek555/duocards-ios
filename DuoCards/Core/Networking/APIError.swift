import Foundation

enum APIError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case unauthorized(code: String?, message: String)
    case rateLimited(
        code: String?,
        message: String,
        retryAfterSeconds: Int?
    )
    case server(status: Int, code: String?, message: String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Adresa serveru není platná."
        case .invalidResponse:
            "Server vrátil neplatnou odpověď."
        case let .unauthorized(_, message):
            message
        case let .rateLimited(_, message, _):
            message
        case let .server(_, _, message):
            message
        case let .decoding(message):
            "Odpověď serveru se nepodařilo načíst: \(message)"
        case let .transport(message):
            "Server není dostupný: \(message)"
        }
    }

    static var sessionExpired: APIError {
        .unauthorized(
            code: "UNAUTHORIZED",
            message: "Přihlášení vypršelo. Přihlaste se prosím znovu."
        )
    }
}

struct APIErrorEnvelope: Decodable, Sendable {
    let code: String?
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case error
    }

    private struct Details: Decodable, Sendable {
        let code: String?
        let message: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let topLevelCode = try container.decodeIfPresent(
            String.self,
            forKey: .code
        )
        let topLevelMessage = try container.decodeIfPresent(
            String.self,
            forKey: .message
        )
        let nestedError = try? container.decode(Details.self, forKey: .error)
        let stringError = try? container.decode(String.self, forKey: .error)

        code = topLevelCode ?? nestedError?.code
        message = topLevelMessage ?? nestedError?.message ?? stringError
    }

    var displayMessage: String? { message }
}
