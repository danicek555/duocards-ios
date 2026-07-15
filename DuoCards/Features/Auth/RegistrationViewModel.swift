import Foundation
import Observation

enum RegistrationLocale: String, CaseIterable, Identifiable, Sendable {
    case ar, ca, zh, cs, da, nl, en, fi, fr, de
    case el, he, hi, hu, id, it, ja, ko, no, pl
    case pt, ro, ru, es, sv, th, tr, uk, vi

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ar: "العربية"
        case .ca: "Català"
        case .zh: "中文（普通话）"
        case .cs: "Čeština"
        case .da: "Dansk"
        case .nl: "Nederlands"
        case .en: "English"
        case .fi: "Suomi"
        case .fr: "Français"
        case .de: "Deutsch"
        case .el: "Ελληνικά"
        case .he: "עברית"
        case .hi: "हिन्दी"
        case .hu: "Magyar"
        case .id: "Bahasa Indonesia"
        case .it: "Italiano"
        case .ja: "日本語"
        case .ko: "한국어"
        case .no: "Norsk"
        case .pl: "Polski"
        case .pt: "Português"
        case .ro: "Română"
        case .ru: "Русский"
        case .es: "Español"
        case .sv: "Svenska"
        case .th: "ไทย"
        case .tr: "Türkçe"
        case .uk: "Українська"
        case .vi: "Tiếng Việt"
        }
    }
}

struct PasswordRequirements: Equatable, Sendable {
    let minimumLength: Bool
    let uppercaseASCII: Bool
    let lowercaseASCII: Bool
    let number: Bool
    let specialCharacter: Bool

    var isValid: Bool {
        minimumLength
            && uppercaseASCII
            && lowercaseASCII
            && number
            && specialCharacter
    }

    init(password: String) {
        let scalarValues = password.unicodeScalars.map { Int($0.value) }
        let specialCharacters = CharacterSet(
            charactersIn: "!@#$%^&*()_+-=[]{};':\"\\|,.<>/?"
        )

        minimumLength = password.count >= 8
        uppercaseASCII = scalarValues.contains { (65...90).contains($0) }
        lowercaseASCII = scalarValues.contains { (97...122).contains($0) }
        number = scalarValues.contains { (48...57).contains($0) }
        specialCharacter = password.unicodeScalars.contains {
            specialCharacters.contains($0)
        }
    }
}

struct RegistrationForm: Equatable, Sendable {
    var email = ""
    var nickname = ""
    var password = ""
    var passwordConfirmation = ""
    var locale = "cs"

    var passwordRequirements: PasswordRequirements {
        PasswordRequirements(password: password)
    }

    var isEmailValid: Bool {
        Self.isValidEmail(email)
    }

    var isSubmittable: Bool {
        (try? validatedRequest()) != nil
    }

    func validatedRequest() throws -> RegistrationRequest {
        let normalizedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
        let normalizedNickname = nickname.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard Self.isValidEmail(normalizedEmail) else {
            throw RegistrationValidationError.invalidEmail
        }
        guard !normalizedNickname.isEmpty else {
            throw RegistrationValidationError.emptyNickname
        }
        guard normalizedNickname.count <= 50 else {
            throw RegistrationValidationError.nicknameTooLong
        }
        guard password.count <= 1_024 else {
            throw RegistrationValidationError.passwordTooLong
        }
        guard passwordRequirements.isValid else {
            throw RegistrationValidationError.weakPassword
        }
        guard password == passwordConfirmation else {
            throw RegistrationValidationError.passwordMismatch
        }

        let normalizedLocale = locale.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let localeValue = normalizedLocale.isEmpty ? "cs" : normalizedLocale
        guard RegistrationLocale(rawValue: localeValue) != nil else {
            throw RegistrationValidationError.invalidLocale
        }
        return RegistrationRequest(
            email: normalizedEmail,
            password: password,
            nickname: normalizedNickname,
            locale: localeValue
        )
    }

    private static func isValidEmail(_ rawValue: String) -> Bool {
        let email = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard
            !localPart.isEmpty,
            !domain.isEmpty,
            !domain.hasPrefix("."),
            !domain.hasSuffix("."),
            domain.contains(".")
        else {
            return false
        }
        return true
    }
}

enum RegistrationValidationError: LocalizedError, Equatable, Sendable {
    case invalidEmail
    case emptyNickname
    case nicknameTooLong
    case weakPassword
    case passwordMismatch
    case passwordTooLong
    case invalidLocale
    case invalidVerificationCode

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            "Zadejte platnou e-mailovou adresu."
        case .emptyNickname:
            "Zadejte přezdívku."
        case .nicknameTooLong:
            "Přezdívka může mít nejvýše 50 znaků."
        case .weakPassword:
            "Heslo nesplňuje všechny požadavky."
        case .passwordMismatch:
            "Zadaná hesla se neshodují."
        case .passwordTooLong:
            "Heslo může mít nejvýše 1024 znaků."
        case .invalidLocale:
            "Vyberte podporovaný jazyk aplikace."
        case .invalidVerificationCode:
            "Ověřovací kód musí obsahovat přesně 6 číslic."
        }
    }
}

enum RegistrationFlowState: Equatable, Sendable {
    case registration
    case verification(email: String)
    case verified(User)
}

@MainActor
@Observable
final class RegistrationViewModel {
    static let resendCooldownSeconds = 60

    private let api: any DuoCardsAPI

    var form = RegistrationForm()
    var verificationCode = ""
    private(set) var state: RegistrationFlowState = .registration
    private(set) var isRegistering = false
    private(set) var isVerifying = false
    private(set) var isResending = false
    private(set) var resendCooldownRemaining = 0
    private(set) var cooldownGeneration = 0
    var errorMessage: String?
    var successMessage: String?

    var verificationEmail: String? {
        guard case let .verification(email) = state else { return nil }
        return email
    }

    var canSubmitRegistration: Bool {
        form.isSubmittable && !isRegistering
    }

    var canSubmitVerification: Bool {
        verificationEmail != nil
            && verificationCode.count == 6
            && verificationCode.allSatisfy(Self.isASCIIDigit)
            && !isVerifying
    }

    var canResend: Bool {
        resendCooldownRemaining == 0 && !isResending
    }

    init(api: any DuoCardsAPI) {
        self.api = api
    }

    func register() async -> User? {
        let request: RegistrationRequest
        do {
            request = try form.validatedRequest()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            return nil
        }

        isRegistering = true
        errorMessage = nil
        successMessage = nil
        defer { isRegistering = false }

        do {
            let response = try await api.register(request: request)
            let responseEmail = response.email.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if response.requiresVerification {
                state = .verification(
                    email: responseEmail.isEmpty ? request.email : responseEmail
                )
                beginResendCooldown()
                return nil
            }

            let user = try await api.restoreSession()
            completeVerification(with: user)
            return user
        } catch {
            errorMessage = localizedMessage(for: error)
            return nil
        }
    }

    func setVerificationCode(_ rawValue: String) {
        verificationCode = String(
            rawValue.filter(Self.isASCIIDigit).prefix(6)
        )
        errorMessage = nil
    }

    func verify() async -> User? {
        guard let email = verificationEmail else { return nil }
        guard canSubmitVerification else {
            errorMessage = RegistrationValidationError
                .invalidVerificationCode
                .errorDescription
            return nil
        }

        isVerifying = true
        errorMessage = nil
        successMessage = nil
        defer { isVerifying = false }

        do {
            let user = try await api.verifyRegistration(
                request: VerificationRequest(
                    email: email,
                    code: verificationCode
                )
            )
            completeVerification(with: user)
            return user
        } catch {
            errorMessage = localizedMessage(for: error)
            return nil
        }
    }

    func resend() async {
        guard let email = verificationEmail, canResend else { return }
        isResending = true
        errorMessage = nil
        successMessage = nil
        defer { isResending = false }

        do {
            try await api.resendVerification(
                request: ResendVerificationRequest(email: email)
            )
            successMessage = "Nový ověřovací kód jsme poslali na váš e-mail."
            beginResendCooldown()
        } catch {
            if case let APIError.rateLimited(_, _, retryAfter) = error {
                beginResendCooldown(
                    seconds: retryAfter ?? Self.resendCooldownSeconds
                )
            }
            errorMessage = localizedMessage(for: error)
        }
    }

    func beginResendCooldown(
        seconds: Int = RegistrationViewModel.resendCooldownSeconds
    ) {
        resendCooldownRemaining = max(0, seconds)
        cooldownGeneration += 1
    }

    func tickResendCooldown() {
        resendCooldownRemaining = max(0, resendCooldownRemaining - 1)
    }

    func returnToRegistration() {
        state = .registration
        verificationCode = ""
        resendCooldownRemaining = 0
        cooldownGeneration += 1
        errorMessage = nil
        successMessage = nil
    }

    private func localizedMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? "Požadavek se nepodařilo dokončit."
    }

    private func completeVerification(with user: User) {
        form.password = ""
        form.passwordConfirmation = ""
        verificationCode = ""
        errorMessage = nil
        successMessage = nil
        state = .verified(user)
    }

    private static func isASCIIDigit(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first else {
            return false
        }
        return (48...57).contains(Int(scalar.value))
    }
}
