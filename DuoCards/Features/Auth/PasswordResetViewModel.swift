import Foundation
import Observation

struct ForgotPasswordForm: Equatable, Sendable {
    var email = ""

    var isEmailValid: Bool {
        (try? validatedRequest()) != nil
    }

    func validatedRequest() throws -> ForgotPasswordRequest {
        let normalizedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
        guard normalizedEmail.count <= 320,
              Self.isValidEmail(normalizedEmail) else {
            throw PasswordResetValidationError.invalidEmail
        }
        return ForgotPasswordRequest(email: normalizedEmail)
    }

    private static func isValidEmail(_ email: String) -> Bool {
        guard
            !email.isEmpty,
            !email.contains(where: { $0.isWhitespace }),
            let separator = email.firstIndex(of: "@"),
            email[separator...].dropFirst().firstIndex(of: "@") == nil
        else {
            return false
        }

        let localPart = email[..<separator]
        let domainStart = email.index(after: separator)
        let domain = email[domainStart...]
        return !localPart.isEmpty
            && !domain.isEmpty
            && !domain.hasPrefix(".")
            && !domain.hasSuffix(".")
            && domain.contains(".")
    }
}

struct NewPasswordForm: Equatable, Sendable {
    var tokenInput = ""
    var password = ""
    var passwordConfirmation = ""

    var passwordRequirements: PasswordRequirements {
        PasswordRequirements(password: password)
    }

    var parsedToken: String? {
        PasswordResetTokenParser.token(fromInput: tokenInput)
    }

    var isSubmittable: Bool {
        (try? validatedRequest()) != nil
    }

    func validatedRequest() throws -> ResetPasswordRequest {
        guard let token = parsedToken else {
            throw PasswordResetValidationError.invalidToken
        }
        guard password.count <= 1_024 else {
            throw PasswordResetValidationError.passwordTooLong
        }
        guard passwordRequirements.isValid else {
            throw PasswordResetValidationError.weakPassword
        }
        guard password == passwordConfirmation else {
            throw PasswordResetValidationError.passwordMismatch
        }
        return ResetPasswordRequest(token: token, password: password)
    }

    mutating func clearSensitiveValues() {
        tokenInput = ""
        password = ""
        passwordConfirmation = ""
    }

    mutating func clearPasswords() {
        password = ""
        passwordConfirmation = ""
    }
}

enum PasswordResetValidationError: LocalizedError, Equatable, Sendable {
    case invalidEmail
    case invalidToken
    case weakPassword
    case passwordMismatch
    case passwordTooLong

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            "Zadejte platnou e-mailovou adresu."
        case .invalidToken:
            "Vložte platný reset token nebo celý HTTPS odkaz z e-mailu."
        case .weakPassword:
            "Nové heslo nesplňuje všechny požadavky."
        case .passwordMismatch:
            "Zadaná hesla se neshodují."
        case .passwordTooLong:
            "Heslo může mít nejvýše 1024 znaků."
        }
    }
}

enum PasswordResetFlowState: Equatable, Sendable {
    case request
    case emailSent(email: String)
    case reset
    case completed
}

@MainActor
@Observable
final class PasswordResetViewModel {
    static let retryCooldownSeconds = 60

    private let api: any DuoCardsAPI

    var requestForm = ForgotPasswordForm()
    var resetForm = NewPasswordForm()
    private(set) var state: PasswordResetFlowState
    private(set) var isRequesting = false
    private(set) var isResetting = false
    private(set) var requestRetryCooldownRemaining = 0
    private(set) var resetRetryCooldownRemaining = 0
    private(set) var cooldownGeneration = 0
    var errorMessage: String?

    var retryCooldownRemaining: Int {
        switch state {
        case .request, .emailSent:
            requestRetryCooldownRemaining
        case .reset:
            resetRetryCooldownRemaining
        case .completed:
            0
        }
    }

    var hasPendingRetryCooldown: Bool {
        requestRetryCooldownRemaining > 0
            || resetRetryCooldownRemaining > 0
    }

    var canRequestReset: Bool {
        requestForm.isEmailValid
            && !isRequesting
            && requestRetryCooldownRemaining == 0
    }

    var canResetPassword: Bool {
        resetForm.isSubmittable
            && !isResetting
            && resetRetryCooldownRemaining == 0
    }

    init(api: any DuoCardsAPI, initialToken: String? = nil) {
        self.api = api
        if let initialToken,
           let token = PasswordResetTokenParser.token(fromInput: initialToken) {
            state = .reset
            resetForm.tokenInput = token
        } else {
            state = .request
        }
    }

    func requestResetLink() async {
        let request: ForgotPasswordRequest
        do {
            request = try requestForm.validatedRequest()
        } catch {
            errorMessage = localizedMessage(for: error)
            return
        }

        guard requestRetryCooldownRemaining == 0, !isRequesting else {
            return
        }
        isRequesting = true
        errorMessage = nil
        defer { isRequesting = false }

        do {
            _ = try await api.requestPasswordReset(request: request)
            requestForm.email = request.email
            state = .emailSent(email: request.email)
            beginRequestRetryCooldown()
        } catch {
            if error is CancellationError { return }
            handle(error)
        }
    }

    func retryResetLink() async {
        guard case .emailSent = state else { return }
        await requestResetLink()
    }

    func showRequestForm() {
        state = .request
        errorMessage = nil
    }

    func showResetForm() {
        state = .reset
        errorMessage = nil
    }

    func applyIncomingToken(_ token: String) {
        guard let parsed = PasswordResetTokenParser.token(fromInput: token) else {
            errorMessage = PasswordResetValidationError.invalidToken
                .errorDescription
            return
        }
        resetForm.clearSensitiveValues()
        resetForm.tokenInput = parsed
        state = .reset
        errorMessage = nil
    }

    func resetPassword() async {
        let request: ResetPasswordRequest
        do {
            request = try resetForm.validatedRequest()
        } catch {
            errorMessage = localizedMessage(for: error)
            return
        }

        guard resetRetryCooldownRemaining == 0, !isResetting else {
            return
        }
        isResetting = true
        errorMessage = nil
        defer { isResetting = false }

        do {
            _ = try await api.resetPassword(request: request)
            resetForm.clearSensitiveValues()
            state = .completed
        } catch {
            if error is CancellationError { return }
            if isInvalidOrExpiredToken(error) {
                resetForm.clearSensitiveValues()
            } else if isServerPasswordPolicyError(error) {
                resetForm.clearPasswords()
            }
            handle(error)
        }
    }

    private func beginRequestRetryCooldown(
        seconds: Int = PasswordResetViewModel.retryCooldownSeconds
    ) {
        requestRetryCooldownRemaining = max(0, seconds)
        cooldownGeneration += 1
    }

    private func beginResetRetryCooldown(
        seconds: Int = PasswordResetViewModel.retryCooldownSeconds
    ) {
        resetRetryCooldownRemaining = max(0, seconds)
        cooldownGeneration += 1
    }

    func tickRetryCooldown() {
        requestRetryCooldownRemaining = max(
            0,
            requestRetryCooldownRemaining - 1
        )
        resetRetryCooldownRemaining = max(
            0,
            resetRetryCooldownRemaining - 1
        )
    }

    func clearSensitiveValues() {
        requestForm.email = ""
        resetForm.clearSensitiveValues()
        errorMessage = nil
        requestRetryCooldownRemaining = 0
        resetRetryCooldownRemaining = 0
        cooldownGeneration += 1
    }

    private func handle(_ error: Error) {
        if case let APIError.rateLimited(_, _, retryAfterSeconds) = error {
            beginResetRetryCooldown(
                seconds: retryAfterSeconds ?? Self.retryCooldownSeconds
            )
        }
        errorMessage = localizedMessage(for: error)
    }

    private func localizedMessage(for error: Error) -> String {
        if isInvalidOrExpiredToken(error) {
            return "Reset odkaz nebo token je neplatný či vypršel. Vyžádejte si nový."
        }
        if isServerPasswordPolicyError(error) {
            return PasswordResetValidationError.weakPassword.errorDescription
                ?? "Nové heslo není dostatečně silné."
        }
        if case let APIError.rateLimited(code, _, _) = error,
           code == "RATE_LIMIT_RESET_PASSWORD" {
            return "Příliš mnoho pokusů. Počkejte prosím a zkuste to znovu."
        }
        return (error as? LocalizedError)?.errorDescription
            ?? "Požadavek se nepodařilo dokončit."
    }

    private func isInvalidOrExpiredToken(_ error: Error) -> Bool {
        guard case let APIError.server(_, code, _) = error else { return false }
        return code == "INVALID_OR_EXPIRED_RESET_TOKEN"
    }

    private func isServerPasswordPolicyError(_ error: Error) -> Bool {
        guard case let APIError.server(_, code, _) = error else { return false }
        return code == "PASSWORD_WEAK" || code == "PASSWORD_MEDIUM"
    }
}
