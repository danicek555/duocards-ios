import SwiftUI

struct RegistrationView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RegistrationViewModel
    @State private var showsVerification = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case nickname
        case email
        case password
        case confirmation
    }

    init(api: any DuoCardsAPI) {
        _viewModel = State(initialValue: RegistrationViewModel(api: api))
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        ZStack {
            DuoBackground()
            ScrollView {
                VStack(spacing: DuoSpacing.xl) {
                    header

                    VStack(alignment: .leading, spacing: DuoSpacing.lg) {
                        field(title: "Přezdívka") {
                            TextField(
                                "Jak vám máme říkat?",
                                text: $bindableViewModel.form.nickname
                            )
                            .textContentType(.nickname)
                            .focused($focusedField, equals: .nickname)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }
                            .duoTextField()

                            if viewModel.form.nickname.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).count > 50 {
                                Text("Přezdívka může mít nejvýše 50 znaků.")
                                    .font(.caption)
                                    .foregroundStyle(DuoColors.red500)
                            }
                        }

                        field(title: "E-mail") {
                            TextField(
                                "vas@email.cz",
                                text: $bindableViewModel.form.email
                            )
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .duoTextField()

                            if !viewModel.form.email.isEmpty,
                               !viewModel.form.isEmailValid {
                                Text("Zadejte platnou e-mailovou adresu.")
                                    .font(.caption)
                                    .foregroundStyle(DuoColors.red500)
                            }
                        }

                        field(title: "Heslo") {
                            SecureField(
                                "Vytvořte silné heslo",
                                text: $bindableViewModel.form.password
                            )
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .confirmation }
                            .duoTextField()

                            passwordChecklist
                        }

                        field(title: "Heslo znovu") {
                            SecureField(
                                "Zopakujte heslo",
                                text: $bindableViewModel.form.passwordConfirmation
                            )
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmation)
                            .submitLabel(.go)
                            .onSubmit(submitRegistration)
                            .duoTextField()

                            if !viewModel.form.passwordConfirmation.isEmpty {
                                PasswordRequirementRow(
                                    title: "Hesla se shodují",
                                    isMet: viewModel.form.password
                                        == viewModel.form.passwordConfirmation
                                )
                            }
                        }

                        Picker(
                            "Jazyk aplikace",
                            selection: $bindableViewModel.form.locale
                        ) {
                            ForEach(RegistrationLocale.allCases) { locale in
                                Text(locale.displayName).tag(locale.rawValue)
                            }
                        }

                        if let message = viewModel.errorMessage {
                            AuthFlowBanner(message: message, isSuccess: false)
                        }

                        Button(action: submitRegistration) {
                            HStack {
                                if viewModel.isRegistering {
                                    ProgressView().tint(.white)
                                }
                                Text(
                                    viewModel.isRegistering
                                        ? "Vytvářím účet…"
                                        : "Vytvořit účet"
                                )
                                .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(.white)
                            .background(DuoColors.brandGradient)
                            .clipShape(
                                RoundedRectangle(cornerRadius: DuoRadius.medium)
                            )
                        }
                        .disabled(!viewModel.canSubmitRegistration)
                        .opacity(viewModel.canSubmitRegistration ? 1 : 0.5)
                    }
                    .duoCard(padding: DuoSpacing.xl)

                    Text("Po registraci vám pošleme šestimístný kód s platností 10 minut.")
                        .font(.footnote)
                        .foregroundStyle(
                            DuoColors.secondaryText(for: colorScheme)
                        )
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, DuoSpacing.lg)
                .padding(.vertical, DuoSpacing.xl)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Registrace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Zrušit") { dismiss() }
                    .disabled(viewModel.isRegistering)
            }
        }
        .navigationDestination(isPresented: $showsVerification) {
            VerificationView(viewModel: viewModel)
        }
        .onChange(of: showsVerification) { wasPresented, isPresented in
            if wasPresented,
               !isPresented,
               viewModel.verificationEmail != nil {
                viewModel.returnToRegistration()
            }
        }
        .interactiveDismissDisabled(viewModel.isRegistering)
    }

    private var header: some View {
        VStack(spacing: DuoSpacing.md) {
            DuoBrandMark(size: 64)
            Text("NOVÝ ÚČET")
                .font(.caption.bold().monospaced())
                .tracking(1.4)
                .foregroundStyle(DuoColors.violet600)
            Text("Začněte s DuoCards")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Vytvořte účet a mějte své sady na webu i v iPhonu.")
                .font(.subheadline)
                .foregroundStyle(DuoColors.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
    }

    private var passwordChecklist: some View {
        let requirements = viewModel.form.passwordRequirements
        return VStack(alignment: .leading, spacing: 5) {
            PasswordRequirementRow(
                title: "Alespoň 8 znaků",
                isMet: requirements.minimumLength
            )
            PasswordRequirementRow(
                title: "Jedno velké písmeno A–Z",
                isMet: requirements.uppercaseASCII
            )
            PasswordRequirementRow(
                title: "Jedno malé písmeno a–z",
                isMet: requirements.lowercaseASCII
            )
            PasswordRequirementRow(
                title: "Jedno číslo 0–9",
                isMet: requirements.number
            )
            PasswordRequirementRow(
                title: "Jeden speciální znak",
                isMet: requirements.specialCharacter
            )
        }
        .padding(.top, 2)
    }

    private func field<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            content()
        }
    }

    private func submitRegistration() {
        focusedField = nil
        guard viewModel.canSubmitRegistration else { return }
        Task {
            if let user = await viewModel.register() {
                session.completeAuthentication(user)
            } else if viewModel.verificationEmail != nil {
                showsVerification = true
            }
        }
    }
}

struct PasswordRequirementRow: View {
    let title: String
    let isMet: Bool

    var body: some View {
        Label(
            title,
            systemImage: isMet ? "checkmark.circle.fill" : "circle"
        )
        .font(.caption)
        .foregroundStyle(isMet ? DuoColors.emerald600 : DuoColors.gray500)
    }
}

struct AuthFlowBanner: View {
    let message: String
    let isSuccess: Bool

    var body: some View {
        Label(
            message,
            systemImage: isSuccess
                ? "checkmark.circle.fill"
                : "exclamationmark.circle.fill"
        )
        .font(.footnote)
        .foregroundStyle(isSuccess ? DuoColors.emerald600 : DuoColors.red500)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DuoSpacing.md)
        .background(
            (isSuccess ? DuoColors.emerald600 : DuoColors.red500).opacity(0.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DuoRadius.small))
    }
}

#Preview("Registrace") {
    let api = MockDuoCardsAPI()
    NavigationStack {
        RegistrationView(api: api)
    }
    .environment(
        AppSession(api: api, initialState: .signedOut)
    )
}
