import Foundation
import XCTest
@testable import DuoCards

final class PasswordResetTests: XCTestCase {
    private let base64URLToken = String(repeating: "A", count: 43)
    private let legacyHexToken = String(repeating: "a1", count: 32)

    func testPasswordResetDTOsMatchV1Contract() throws {
        let forgotData = try JSONEncoder().encode(
            ForgotPasswordRequest(email: "user@example.com")
        )
        let forgotObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: forgotData) as? [String: Any]
        )
        XCTAssertEqual(forgotObject["email"] as? String, "user@example.com")
        XCTAssertEqual(forgotObject.count, 1)

        let resetData = try JSONEncoder().encode(
            ResetPasswordRequest(
                token: base64URLToken,
                password: "Strong1!"
            )
        )
        let resetObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: resetData) as? [String: Any]
        )
        XCTAssertEqual(resetObject["token"] as? String, base64URLToken)
        XCTAssertEqual(resetObject["password"] as? String, "Strong1!")
        XCTAssertEqual(resetObject.count, 2)

        let response = try JSONDecoder().decode(
            PasswordResetResponse.self,
            from: Data(#"{"message":"accepted"}"#.utf8)
        )
        XCTAssertEqual(response, PasswordResetResponse(message: "accepted"))
    }

    func testTokenParserAcceptsOnlySupportedRawFormats() {
        XCTAssertEqual(
            PasswordResetTokenParser.token(fromInput: base64URLToken),
            base64URLToken
        )
        XCTAssertEqual(
            PasswordResetTokenParser.token(fromInput: legacyHexToken),
            legacyHexToken
        )
        XCTAssertNil(
            PasswordResetTokenParser.token(
                fromInput: String(repeating: "A", count: 42)
            )
        )
        XCTAssertNil(
            PasswordResetTokenParser.token(
                fromInput: String(repeating: "g", count: 64)
            )
        )
        XCTAssertNil(
            PasswordResetTokenParser.token(fromInput: "not-a-reset-token")
        )
    }

    func testTokenParserExtractsHTTPSResetLinkWithoutRestrictingHost() {
        let legacyQueryURL = URL(
            string: "https://staging.example.test/reset-password?utm_source=mail&token=\(base64URLToken)"
        )!
        let fragmentURL = URL(
            string: "https://staging.example.test/reset-password#token=\(base64URLToken)"
        )!
        let bothURL = URL(
            string: "https://staging.example.test/reset-password?token=\(legacyHexToken)#token=\(base64URLToken)"
        )!

        XCTAssertEqual(
            PasswordResetTokenParser.token(fromURL: legacyQueryURL),
            base64URLToken
        )
        XCTAssertEqual(
            PasswordResetTokenParser.token(fromInput: fragmentURL.absoluteString),
            base64URLToken
        )
        XCTAssertEqual(
            PasswordResetTokenParser.token(fromURL: fragmentURL),
            base64URLToken
        )
        XCTAssertEqual(
            PasswordResetTokenParser.token(fromURL: bothURL),
            base64URLToken
        )
        XCTAssertNil(
            PasswordResetTokenParser.token(
                fromInput: "http://example.test/reset-password?token=\(base64URLToken)"
            )
        )
        XCTAssertNil(
            PasswordResetTokenParser.token(
                fromInput: "https://example.test/other?token=\(base64URLToken)"
            )
        )
    }

    func testNewPasswordFormReusesStrongPolicyAndNormalizesTokenLink() throws {
        let link = "https://app.duocards.xyz/reset-password#token=\(legacyHexToken)"
        let form = NewPasswordForm(
            tokenInput: "  \(link)  ",
            password: "Strong1!",
            passwordConfirmation: "Strong1!"
        )

        let request = try form.validatedRequest()

        XCTAssertEqual(request.token, legacyHexToken)
        XCTAssertEqual(request.password, "Strong1!")
        XCTAssertTrue(form.passwordRequirements.isValid)
    }

    func testNewPasswordFormRejectsWeakMismatchedAndInvalidToken() {
        var form = validNewPasswordForm()
        form.password = "password"
        form.passwordConfirmation = "password"
        assertValidationError(.weakPassword, for: form)

        form = validNewPasswordForm()
        form.passwordConfirmation = "Different1!"
        assertValidationError(.passwordMismatch, for: form)

        form = validNewPasswordForm()
        form.tokenInput = "invalid"
        assertValidationError(.invalidToken, for: form)
    }

    @MainActor
    func testForgotRequestUsesNormalizedEmailAndGenericConfirmationState() async {
        let api = MockDuoCardsAPI()
        let viewModel = PasswordResetViewModel(api: api)
        viewModel.requestForm.email = "  USER@Example.COM "

        await viewModel.requestResetLink()

        XCTAssertEqual(
            viewModel.state,
            .emailSent(email: "user@example.com")
        )
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(
            viewModel.retryCooldownRemaining,
            PasswordResetViewModel.retryCooldownSeconds
        )
        let captured = await api.capturedForgotPasswordRequest()
        XCTAssertEqual(captured, ForgotPasswordRequest(email: "user@example.com"))
    }

    @MainActor
    func testSuccessfulResetClearsTokenAndPasswords() async {
        let api = MockDuoCardsAPI()
        let viewModel = PasswordResetViewModel(
            api: api,
            initialToken: base64URLToken
        )
        viewModel.resetForm.password = "Strong1!"
        viewModel.resetForm.passwordConfirmation = "Strong1!"

        await viewModel.resetPassword()

        XCTAssertEqual(viewModel.state, .completed)
        XCTAssertTrue(viewModel.resetForm.tokenInput.isEmpty)
        XCTAssertTrue(viewModel.resetForm.password.isEmpty)
        XCTAssertTrue(viewModel.resetForm.passwordConfirmation.isEmpty)
        let captured = await api.capturedResetPasswordRequest()
        XCTAssertEqual(
            captured,
            ResetPasswordRequest(
                token: base64URLToken,
                password: "Strong1!"
            )
        )
    }

    @MainActor
    func testResetRateLimitStartsServerDirectedRetryCooldown() async {
        let api = MockDuoCardsAPI()
        await api.failNextResetPasswordRequest(
            with: .rateLimited(
                code: "RATE_LIMIT_RESET_PASSWORD",
                message: "backend message",
                retryAfterSeconds: 17
            )
        )
        let viewModel = PasswordResetViewModel(
            api: api,
            initialToken: base64URLToken
        )
        viewModel.resetForm.password = "Strong1!"
        viewModel.resetForm.passwordConfirmation = "Strong1!"

        await viewModel.resetPassword()

        XCTAssertEqual(viewModel.retryCooldownRemaining, 17)
        XCTAssertFalse(viewModel.canResetPassword)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Příliš mnoho pokusů. Počkejte prosím a zkuste to znovu."
        )
        XCTAssertEqual(viewModel.resetForm.tokenInput, base64URLToken)
        XCTAssertEqual(viewModel.resetForm.password, "Strong1!")
    }

    @MainActor
    func testForgotCooldownContinuesAcrossResetFormNavigation() async {
        let viewModel = PasswordResetViewModel(api: MockDuoCardsAPI())
        viewModel.requestForm.email = "user@example.com"

        await viewModel.requestResetLink()
        XCTAssertEqual(
            viewModel.retryCooldownRemaining,
            PasswordResetViewModel.retryCooldownSeconds
        )

        viewModel.showResetForm()
        XCTAssertEqual(viewModel.retryCooldownRemaining, 0)
        viewModel.tickRetryCooldown()

        viewModel.showRequestForm()
        XCTAssertEqual(
            viewModel.retryCooldownRemaining,
            PasswordResetViewModel.retryCooldownSeconds - 1
        )
        XCTAssertFalse(viewModel.canRequestReset)
    }

    @MainActor
    func testInvalidOrExpiredTokenClearsAllResetSecrets() async {
        let api = MockDuoCardsAPI()
        await api.failNextResetPasswordRequest(
            with: .server(
                status: 400,
                code: "INVALID_OR_EXPIRED_RESET_TOKEN",
                message: "backend message"
            )
        )
        let viewModel = PasswordResetViewModel(
            api: api,
            initialToken: base64URLToken
        )
        viewModel.resetForm.password = "Strong1!"
        viewModel.resetForm.passwordConfirmation = "Strong1!"

        await viewModel.resetPassword()

        XCTAssertEqual(viewModel.state, .reset)
        XCTAssertTrue(viewModel.resetForm.tokenInput.isEmpty)
        XCTAssertTrue(viewModel.resetForm.password.isEmpty)
        XCTAssertTrue(viewModel.resetForm.passwordConfirmation.isEmpty)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Reset odkaz nebo token je neplatný či vypršel. Vyžádejte si nový."
        )
    }

    @MainActor
    func testHTTPSDeepLinkPresentsResetWithoutPrematureSignOut() {
        let api = MockDuoCardsAPI()
        let user = PreviewFixtures.user
        let session = AppSession(api: api, initialState: .signedIn(user))
        let resetURL = URL(
            string: "https://app.duocards.xyz/reset-password?token=\(base64URLToken)"
        )!

        XCTAssertTrue(session.handleIncomingURL(resetURL))
        XCTAssertTrue(session.isPasswordResetPresented)
        XCTAssertEqual(session.passwordResetToken, base64URLToken)
        XCTAssertEqual(session.state, .signedIn(user))

        session.completePasswordReset()

        XCTAssertEqual(session.state, .signedOut)
        XCTAssertNil(session.authMessage)
        XCTAssertNil(session.passwordResetToken)
        XCTAssertTrue(session.isPasswordResetPresented)

        session.dismissPasswordReset()
        XCTAssertNil(session.passwordResetToken)
        XCTAssertFalse(session.isPasswordResetPresented)
    }

    @MainActor
    func testNonHTTPSDeepLinksAreIgnored() {
        let session = AppSession(
            api: MockDuoCardsAPI(),
            initialState: .signedOut
        )
        let customScheme = URL(
            string: "duocards://reset-password?token=\(base64URLToken)"
        )!

        XCTAssertFalse(session.handleIncomingURL(customScheme))
        XCTAssertFalse(session.isPasswordResetPresented)
        XCTAssertNil(session.passwordResetToken)
    }

    private func validNewPasswordForm() -> NewPasswordForm {
        NewPasswordForm(
            tokenInput: base64URLToken,
            password: "Strong1!",
            passwordConfirmation: "Strong1!"
        )
    }

    private func assertValidationError(
        _ expected: PasswordResetValidationError,
        for form: NewPasswordForm,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try form.validatedRequest(),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? PasswordResetValidationError,
                expected,
                file: file,
                line: line
            )
        }
    }
}
