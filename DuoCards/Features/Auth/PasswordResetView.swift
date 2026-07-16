import SwiftUI

struct PasswordResetFlowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PasswordResetViewModel
    @State private var activeNetworkTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?
    let initialToken: String?
    let onPasswordReset: () -> Void

    private enum Field {
        case email
        case token
        case password
        case confirmation
    }

    init(
        api: any DuoCardsAPI,
        initialToken: String? = nil,
        onPasswordReset: @escaping () -> Void = {}
    ) {
        self.initialToken = initialToken
        self.onPasswordReset = onPasswordReset
        _viewModel = State(
            initialValue: PasswordResetViewModel(
                api: api,
                initialToken: initialToken
            )
        )
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        ZStack {
            DuoBackground()
            ScrollView {
                VStack(spacing: DuoSpacing.xl) {
                    switch viewModel.state {
                    case .request:
                        requestContent(viewModel: $bindableViewModel)
                    case let .emailSent(email):
                        confirmationContent(email: email)
                    case .reset:
                        resetContent(viewModel: $bindableViewModel)
                    case .completed:
                        completedContent
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, DuoSpacing.lg)
                .padding(.vertical, DuoSpacing.xl)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Zavřít", action: close)
                    .disabled(viewModel.isRequesting || viewModel.isResetting)
            }
        }
        .interactiveDismissDisabled(
            viewModel.isRequesting || viewModel.isResetting
        )
        .task(id: viewModel.cooldownGeneration) {
            await runCooldown()
        }
        .onChange(of: initialToken) { _, token in
            activeNetworkTask?.cancel()
            if let token { viewModel.applyIncomingToken(token) }
        }
        .onDisappear {
            activeNetworkTask?.cancel()
            viewModel.clearSensitiveValues()
        }
    }

    private var navigationTitle: String {
        switch viewModel.state {
        case .request, .emailSent:
            "Obnova hesla"
        case .reset:
            "Nové heslo"
        case .completed:
            "Heslo změněno"
        }
    }

    @ViewBuilder
    private func requestContent(
        viewModel bindableViewModel: Bindable<PasswordResetViewModel>
    ) -> some View {
        authHeader(
            icon: "lock.rotation",
            badge: "OBNOVA HESLA",
            title: "Zapomněli jste heslo?",
            subtitle: "Zadejte e-mail k účtu. Pokud účet existuje, pošleme vám bezpečný reset odkaz."
        )

        VStack(alignment: .leading, spacing: DuoSpacing.lg) {
            field(title: "E-mail") {
                TextField(
                    "vas@email.cz",
                    text: bindableViewModel.requestForm.email
                )
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.go)
                .onSubmit(requestResetLink)
                .duoTextField()

                if !viewModel.requestForm.email.isEmpty,
                   !viewModel.requestForm.isEmailValid {
                    Text("Zadejte platnou e-mailovou adresu.")
                        .font(.caption)
                        .foregroundStyle(DuoColors.red500)
                }
            }

            errorBanner

            primaryButton(
                title: viewModel.isRequesting
                    ? "Odesílám…"
                    : "Poslat reset odkaz",
                isLoading: viewModel.isRequesting,
                isEnabled: viewModel.canRequestReset,
                action: requestResetLink
            )

            cooldownText

            Button("Mám reset token nebo odkaz") {
                focusedField = nil
                viewModel.showResetForm()
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .duoCard(padding: DuoSpacing.xl)
    }

    @ViewBuilder
    private func confirmationContent(email: String) -> some View {
        authHeader(
            icon: "envelope.badge.shield.half.filled",
            badge: "ZKONTROLUJTE E-MAIL",
            title: "Instrukce jsou na cestě",
            subtitle: "Pokud pro zadanou adresu existuje účet, poslali jsme na ni odkaz pro bezpečnou změnu hesla."
        )

        VStack(spacing: DuoSpacing.lg) {
            AuthFlowBanner(
                message: "Požadavek jsme přijali. Z bezpečnostních důvodů nepotvrzujeme, zda účet existuje.",
                isSuccess: true
            )

            Text(email)
                .font(.subheadline.bold())
                .foregroundStyle(DuoColors.indigo600)
                .multilineTextAlignment(.center)

            Text("Otevřete HTTPS odkaz z e-mailu. Dokud nejsou nasazené Universal Links, můžete sem vložit celý odkaz nebo samotný token.")
                .font(.footnote)
                .foregroundStyle(DuoColors.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)

            primaryButton(
                title: "Vložit reset token",
                isLoading: false,
                isEnabled: true
            ) {
                viewModel.showResetForm()
            }

            Button {
                retryResetLink()
            } label: {
                HStack(spacing: DuoSpacing.sm) {
                    if viewModel.isRequesting { ProgressView() }
                    Text(viewModel.isRequesting ? "Odesílám…" : "Poslat znovu")
                }
            }
            .font(.subheadline.weight(.semibold))
            .disabled(
                viewModel.isRequesting
                    || viewModel.retryCooldownRemaining > 0
            )

            cooldownText
            errorBanner

            Button("Použít jiný e-mail") {
                viewModel.showRequestForm()
                focusedField = .email
            }
            .font(.footnote.weight(.medium))
        }
        .duoCard(padding: DuoSpacing.xl)
    }

    @ViewBuilder
    private func resetContent(
        viewModel bindableViewModel: Bindable<PasswordResetViewModel>
    ) -> some View {
        authHeader(
            icon: "key.fill",
            badge: "NOVÉ HESLO",
            title: "Nastavte nové heslo",
            subtitle: "Vložte reset token nebo celý HTTPS odkaz a zvolte silné heslo."
        )

        VStack(alignment: .leading, spacing: DuoSpacing.lg) {
            field(title: "Reset token nebo HTTPS odkaz") {
                SecureField(
                    "Vložte token nebo celý odkaz",
                    text: bindableViewModel.resetForm.tokenInput
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .token)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .duoTextField()

                Text("Token ukládáme pouze do paměti aplikace a po dokončení nebo zavření ho smažeme.")
                    .font(.caption)
                    .foregroundStyle(DuoColors.secondaryText(for: colorScheme))
            }

            field(title: "Nové heslo") {
                SecureField(
                    "Vytvořte silné heslo",
                    text: bindableViewModel.resetForm.password
                )
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit { focusedField = .confirmation }
                .duoTextField()

                passwordChecklist
            }

            field(title: "Nové heslo znovu") {
                SecureField(
                    "Zopakujte nové heslo",
                    text: bindableViewModel.resetForm.passwordConfirmation
                )
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmation)
                .submitLabel(.go)
                .onSubmit(resetPassword)
                .duoTextField()

                if !viewModel.resetForm.passwordConfirmation.isEmpty {
                    PasswordRequirementRow(
                        title: "Hesla se shodují",
                        isMet: viewModel.resetForm.password
                            == viewModel.resetForm.passwordConfirmation
                    )
                }
            }

            errorBanner

            primaryButton(
                title: viewModel.isResetting
                    ? "Měním heslo…"
                    : "Změnit heslo",
                isLoading: viewModel.isResetting,
                isEnabled: viewModel.canResetPassword,
                action: resetPassword
            )

            cooldownText

            Button("Vyžádat nový reset odkaz") {
                focusedField = nil
                viewModel.resetForm.clearSensitiveValues()
                viewModel.showRequestForm()
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .duoCard(padding: DuoSpacing.xl)
        .onAppear {
            focusedField = viewModel.resetForm.tokenInput.isEmpty
                ? .token
                : .password
        }
    }

    private var completedContent: some View {
        VStack(spacing: DuoSpacing.xl) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(DuoColors.emerald600)
            Text("Heslo bylo změněno")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Teď se můžete přihlásit novým heslem.")
                .font(.subheadline)
                .foregroundStyle(DuoColors.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)

            primaryButton(
                title: "Zpět na přihlášení",
                isLoading: false,
                isEnabled: true,
                action: close
            )
        }
        .duoCard(padding: DuoSpacing.xl)
    }

    private func authHeader(
        icon: String,
        badge: String,
        title: String,
        subtitle: String
    ) -> some View {
        VStack(spacing: DuoSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 54))
                .foregroundStyle(DuoColors.brandGradient)
            Text(badge)
                .font(.caption.bold().monospaced())
                .tracking(1.4)
                .foregroundStyle(DuoColors.violet600)
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(DuoColors.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
    }

    private var passwordChecklist: some View {
        let requirements = viewModel.resetForm.passwordRequirements
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

    @ViewBuilder
    private var errorBanner: some View {
        if let message = viewModel.errorMessage {
            AuthFlowBanner(message: message, isSuccess: false)
        }
    }

    @ViewBuilder
    private var cooldownText: some View {
        if viewModel.retryCooldownRemaining > 0 {
            Text("Další pokus bude možný za \(formattedCooldown).")
                .font(.footnote)
                .foregroundStyle(DuoColors.secondaryText(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var formattedCooldown: String {
        let seconds = viewModel.retryCooldownRemaining
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
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

    private func primaryButton(
        title: String,
        isLoading: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if isLoading { ProgressView().tint(.white) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.white)
            .background(DuoColors.brandGradient)
            .clipShape(RoundedRectangle(cornerRadius: DuoRadius.medium))
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private func requestResetLink() {
        focusedField = nil
        guard viewModel.canRequestReset else { return }
        activeNetworkTask?.cancel()
        activeNetworkTask = Task { await viewModel.requestResetLink() }
    }

    private func retryResetLink() {
        guard !viewModel.isRequesting,
              viewModel.retryCooldownRemaining == 0 else {
            return
        }
        activeNetworkTask?.cancel()
        activeNetworkTask = Task { await viewModel.retryResetLink() }
    }

    private func resetPassword() {
        focusedField = nil
        guard viewModel.canResetPassword else { return }
        activeNetworkTask?.cancel()
        activeNetworkTask = Task {
            await viewModel.resetPassword()
            guard !Task.isCancelled else { return }
            if viewModel.state == .completed { onPasswordReset() }
        }
    }

    private func close() {
        focusedField = nil
        activeNetworkTask?.cancel()
        viewModel.clearSensitiveValues()
        dismiss()
    }

    private func runCooldown() async {
        while !Task.isCancelled, viewModel.hasPendingRetryCooldown {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            viewModel.tickRetryCooldown()
        }
    }
}

#Preview("Obnova hesla") {
    NavigationStack {
        PasswordResetFlowView(api: MockDuoCardsAPI())
    }
}
