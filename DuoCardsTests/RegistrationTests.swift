import Foundation
import XCTest
@testable import DuoCards

final class RegistrationTests: XCTestCase {
    func testLegacyPasswordPolicyRequiresAllFiveRules() {
        let valid = PasswordRequirements(password: "Strong1!")

        XCTAssertTrue(valid.minimumLength)
        XCTAssertTrue(valid.uppercaseASCII)
        XCTAssertTrue(valid.lowercaseASCII)
        XCTAssertTrue(valid.number)
        XCTAssertTrue(valid.specialCharacter)
        XCTAssertTrue(valid.isValid)

        let nonASCIIUppercase = PasswordRequirements(password: "Žabcdef1!")
        XCTAssertFalse(nonASCIIUppercase.uppercaseASCII)
        XCTAssertFalse(nonASCIIUppercase.isValid)
    }

    func testRegistrationValidationNormalizesRequestAndDefaultsLocale() throws {
        let form = RegistrationForm(
            email: "  USER@Example.COM ",
            nickname: "  Daniel  ",
            password: "Strong1!",
            passwordConfirmation: "Strong1!",
            locale: ""
        )

        let request = try form.validatedRequest()

        XCTAssertEqual(request.email, "user@example.com")
        XCTAssertEqual(request.nickname, "Daniel")
        XCTAssertEqual(request.password, "Strong1!")
        XCTAssertEqual(request.locale, "cs")
    }

    func testRegistrationRejectsUnsupportedLocaleAndMismatchedPasswords() {
        var form = validForm()
        form.locale = "xx"
        assertValidationError(.invalidLocale, for: form)

        form = validForm()
        form.passwordConfirmation = "Different1!"
        assertValidationError(.passwordMismatch, for: form)
    }

    func testRegistrationRejectsInvalidIdentityAndWeakPassword() {
        var form = validForm()
        form.email = "not-an-email"
        assertValidationError(.invalidEmail, for: form)

        form = validForm()
        form.nickname = "   "
        assertValidationError(.emptyNickname, for: form)

        form = validForm()
        form.password = "password"
        form.passwordConfirmation = "password"
        assertValidationError(.weakPassword, for: form)
    }

    func testRegistrationAcceptsFiftyCharacterNicknameAndRejectsFiftyOne() {
        var form = validForm()
        form.nickname = String(repeating: "ž", count: 50)
        XCTAssertNoThrow(try form.validatedRequest())

        form.nickname += "ž"
        assertValidationError(.nicknameTooLong, for: form)
    }

    func testRegistrationDTOEncodesExactContractAndDecodesResponse() throws {
        let request = RegistrationRequest(
            email: "user@example.com",
            password: "Strong1!",
            nickname: "Daniel",
            locale: "cs"
        )
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(object["email"] as? String, "user@example.com")
        XCTAssertEqual(object["password"] as? String, "Strong1!")
        XCTAssertEqual(object["nickname"] as? String, "Daniel")
        XCTAssertEqual(object["locale"] as? String, "cs")
        XCTAssertEqual(object.count, 4)

        let responseData = #"""
        {"email":"user@example.com","requiresVerification":true}
        """#.data(using: .utf8)!
        let response = try JSONDecoder().decode(
            RegistrationResponse.self,
            from: responseData
        )
        XCTAssertEqual(
            response,
            RegistrationResponse(
                email: "user@example.com",
                requiresVerification: true
            )
        )
    }

    @MainActor
    func testVerificationCodeAcceptsOnlySixASCIIDigits() {
        let viewModel = RegistrationViewModel(api: MockDuoCardsAPI())

        viewModel.setVerificationCode("١2a34５678")

        XCTAssertEqual(viewModel.verificationCode, "234678")
        XCTAssertTrue(viewModel.canSubmitVerification == false)
    }

    @MainActor
    func testRegistrationAndVerificationStateFlow() async {
        let api = MockDuoCardsAPI()
        let viewModel = RegistrationViewModel(api: api)
        viewModel.form = validForm()

        let directlyAuthenticatedUser = await viewModel.register()

        XCTAssertNil(directlyAuthenticatedUser)
        XCTAssertEqual(
            viewModel.state,
            .verification(email: "user@example.com")
        )
        XCTAssertEqual(
            viewModel.resendCooldownRemaining,
            RegistrationViewModel.resendCooldownSeconds
        )

        viewModel.setVerificationCode(MockDuoCardsAPI.validVerificationCode)
        let verifiedUser = await viewModel.verify()

        let user = try? XCTUnwrap(verifiedUser)
        XCTAssertEqual(user?.email, "user@example.com")
        if let user {
            XCTAssertEqual(viewModel.state, .verified(user))
        }
        XCTAssertTrue(viewModel.form.password.isEmpty)
        XCTAssertTrue(viewModel.form.passwordConfirmation.isEmpty)
        XCTAssertTrue(viewModel.verificationCode.isEmpty)
    }

    @MainActor
    func testResendCooldownTicksDeterministically() {
        let viewModel = RegistrationViewModel(api: MockDuoCardsAPI())

        viewModel.beginResendCooldown(seconds: 2)
        XCTAssertFalse(viewModel.canResend)
        viewModel.tickResendCooldown()
        viewModel.tickResendCooldown()

        XCTAssertEqual(viewModel.resendCooldownRemaining, 0)
        XCTAssertTrue(viewModel.canResend)
    }

    private func validForm() -> RegistrationForm {
        RegistrationForm(
            email: "user@example.com",
            nickname: "Daniel",
            password: "Strong1!",
            passwordConfirmation: "Strong1!",
            locale: "cs"
        )
    }

    private func assertValidationError(
        _ expected: RegistrationValidationError,
        for form: RegistrationForm,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try form.validatedRequest(),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? RegistrationValidationError,
                expected,
                file: file,
                line: line
            )
        }
    }
}
