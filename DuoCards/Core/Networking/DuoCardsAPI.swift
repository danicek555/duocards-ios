import Foundation

protocol DuoCardsAPI: Sendable {
    func login(email: String, password: String) async throws -> User
    func requestPasswordReset(
        request: ForgotPasswordRequest
    ) async throws -> PasswordResetResponse
    func resetPassword(
        request: ResetPasswordRequest
    ) async throws -> PasswordResetResponse
    func register(
        request: RegistrationRequest
    ) async throws -> RegistrationResponse
    func verifyRegistration(
        request: VerificationRequest
    ) async throws -> User
    func resendVerification(
        request: ResendVerificationRequest
    ) async throws
    func restoreSession() async throws -> User
    func logout() async throws
    func fetchFlashcardSets() async throws -> [FlashcardSet]
    func fetchFlashcardSet(id: Int) async throws -> FlashcardSet
    func createFlashcardSet(
        payload: FlashcardSetPayload
    ) async throws -> FlashcardSet
    func updateFlashcardSet(
        id: Int,
        payload: FlashcardSetPayload
    ) async throws -> FlashcardSet
    func deleteFlashcardSet(id: Int) async throws
    func fetchCoins() async throws -> Int
    func fetchWordImage(id: Int) async throws -> WordImage
    func fetchWordAudio(id: Int) async throws -> WordAudio
}

struct DuoCardsAPIClient: DuoCardsAPI, Sendable {
    private enum Path {
        static let root = "api/v1"
        static let login = "\(root)/auth/login"
        static let forgotPassword = "\(root)/auth/forgot-password"
        static let resetPassword = "\(root)/auth/reset-password"
        static let register = "\(root)/auth/register"
        static let verify = "\(root)/auth/verify"
        static let resend = "\(root)/auth/resend"
        static let me = "\(root)/auth/me"
        static let logout = "\(root)/auth/logout"
        static let sets = "\(root)/flashcard-sets"
        static let coins = "\(root)/user/coins"
        static let wordImages = "\(root)/word-images"
        static let wordAudio = "\(root)/word-audio"
    }

    private let client: APIClient

    init(configuration: AppConfiguration) {
        client = APIClient(baseURL: configuration.baseURL)
    }

    func login(email: String, password: String) async throws -> User {
        let response: UserResponse = try await client.send(
            Path.login,
            body: LoginRequest(email: email, password: password)
        )
        return response.user
    }

    func requestPasswordReset(
        request: ForgotPasswordRequest
    ) async throws -> PasswordResetResponse {
        try await client.send(Path.forgotPassword, body: request)
    }

    func resetPassword(
        request: ResetPasswordRequest
    ) async throws -> PasswordResetResponse {
        try await client.send(Path.resetPassword, body: request)
    }

    func register(
        request: RegistrationRequest
    ) async throws -> RegistrationResponse {
        try await client.send(Path.register, body: request)
    }

    func verifyRegistration(
        request: VerificationRequest
    ) async throws -> User {
        let response: UserResponse = try await client.send(
            Path.verify,
            body: request
        )
        return response.user
    }

    func resendVerification(
        request: ResendVerificationRequest
    ) async throws {
        try await client.perform(Path.resend, body: request)
    }

    func restoreSession() async throws -> User {
        let response: UserResponse = try await client.get(Path.me)
        return response.user
    }

    func logout() async throws {
        do {
            try await client.perform(Path.logout)
        } catch {
            await client.clearAuthenticationCookies()
            throw error
        }
        await client.clearAuthenticationCookies()
    }

    func fetchFlashcardSets() async throws -> [FlashcardSet] {
        let response: SetsResponse = try await client.get(Path.sets)
        return response.sets
    }

    func fetchFlashcardSet(id: Int) async throws -> FlashcardSet {
        let response: SetResponse = try await client.get("\(Path.sets)/\(id)")
        return response.set
    }

    func createFlashcardSet(
        payload: FlashcardSetPayload
    ) async throws -> FlashcardSet {
        let response: SetResponse = try await client.send(
            Path.sets,
            body: payload
        )
        return response.set
    }

    func updateFlashcardSet(
        id: Int,
        payload: FlashcardSetPayload
    ) async throws -> FlashcardSet {
        let response: SetResponse = try await client.send(
            "\(Path.sets)/\(id)",
            method: .patch,
            body: payload
        )
        return response.set
    }

    func deleteFlashcardSet(id: Int) async throws {
        try await client.perform("\(Path.sets)/\(id)", method: .delete)
    }

    func fetchCoins() async throws -> Int {
        let response: CoinsResponse = try await client.get(Path.coins)
        return response.coins
    }

    func fetchWordImage(id: Int) async throws -> WordImage {
        let response: ImageResponse = try await client.get(
            "\(Path.wordImages)/\(id)"
        )
        return response.image
    }

    func fetchWordAudio(id: Int) async throws -> WordAudio {
        let response: AudioResponse = try await client.get(
            "\(Path.wordAudio)/\(id)"
        )
        return response.audio
    }
}

private struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

private struct UserResponse: Decodable, Sendable {
    let user: User

    private enum CodingKeys: String, CodingKey {
        case user
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let nestedUser = try? container.decode(User.self, forKey: .user) {
            user = nestedUser
        } else {
            user = try User(from: decoder)
        }
    }
}

private struct SetsResponse: Decodable, Sendable {
    let sets: [FlashcardSet]

    private enum CodingKeys: String, CodingKey {
        case flashcardSets
        case sets
        case items
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let value = try? container.decode(
                [FlashcardSet].self,
                forKey: .flashcardSets
            ) {
                sets = value
                return
            }
            if let value = try? container.decode(
                [FlashcardSet].self,
                forKey: .sets
            ) {
                sets = value
                return
            }
            if let value = try? container.decode(
                [FlashcardSet].self,
                forKey: .items
            ) {
                sets = value
                return
            }
        }
        sets = try decoder.singleValueContainer().decode(
            [FlashcardSet].self
        )
    }
}

private struct SetResponse: Decodable, Sendable {
    let set: FlashcardSet

    private enum CodingKeys: String, CodingKey {
        case flashcardSet
        case set
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let value = try? container.decode(
                FlashcardSet.self,
                forKey: .flashcardSet
            ) {
                set = value
                return
            }
            if let value = try? container.decode(
                FlashcardSet.self,
                forKey: .set
            ) {
                set = value
                return
            }
        }
        set = try FlashcardSet(from: decoder)
    }
}

private struct CoinsResponse: Decodable, Sendable {
    let coins: Int
}

private struct ImageResponse: Decodable, Sendable {
    let image: WordImage
}

private struct AudioResponse: Decodable, Sendable {
    let audio: WordAudio
}
