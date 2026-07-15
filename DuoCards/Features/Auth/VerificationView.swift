import Foundation
import SwiftUI

struct VerificationView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: RegistrationViewModel
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        ZStack {
            DuoBackground()
            ScrollView {
                VStack(spacing: DuoSpacing.xl) {
                    header

                    VStack(spacing: DuoSpacing.lg) {
                        TextField(
                            "000000",
                            text: Binding(
                                get: { viewModel.verificationCode },
                                set: { newValue in
                                    viewModel.setVerificationCode(newValue)
                                }
                            )
                        )
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .tracking(8)
                        .focused($isCodeFocused)
                        .padding(.horizontal, DuoSpacing.md)
                        .frame(height: 68)
                        .background(DuoColors.gray50)
                        .clipShape(
                            RoundedRectangle(cornerRadius: DuoRadius.medium)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: DuoRadius.medium)
                                .stroke(
                                    viewModel.verificationCode.count == 6
                                        ? DuoColors.emerald600
                                        : DuoColors.gray200,
                                    lineWidth: 1.5
                                )
                        }
                        .accessibilityLabel("Šestimístný ověřovací kód")

                        if let message = viewModel.errorMessage {
                            AuthFlowBanner(message: message, isSuccess: false)
                        }
                        if let message = viewModel.successMessage {
                            AuthFlowBanner(message: message, isSuccess: true)
                        }

                        Button(action: verify) {
                            HStack {
                                if viewModel.isVerifying {
                                    ProgressView().tint(.white)
                                }
                                Text(
                                    viewModel.isVerifying
                                        ? "Ověřuji…"
                                        : "Ověřit e-mail"
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
                        .disabled(!viewModel.canSubmitVerification)
                        .opacity(viewModel.canSubmitVerification ? 1 : 0.5)

                        resendControl
                    }
                    .duoCard(padding: DuoSpacing.xl)
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, DuoSpacing.lg)
                .padding(.vertical, DuoSpacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Ověření e-mailu")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.cooldownGeneration) {
            await runCooldown()
        }
        .onAppear { isCodeFocused = true }
    }

    private var header: some View {
        VStack(spacing: DuoSpacing.md) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 54))
                .foregroundStyle(DuoColors.brandGradient)
            Text("Zkontrolujte svůj e-mail")
                .font(.title2.bold())
            Text("Šestimístný kód jsme poslali na")
                .font(.subheadline)
                .foregroundStyle(DuoColors.secondaryText(for: colorScheme))
            Text(viewModel.verificationEmail ?? "")
                .font(.subheadline.bold())
                .foregroundStyle(DuoColors.indigo600)
                .multilineTextAlignment(.center)
            Text("Kód platí 10 minut.")
                .font(.caption)
                .foregroundStyle(DuoColors.secondaryText(for: colorScheme))
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var resendControl: some View {
        if viewModel.isResending {
            HStack(spacing: DuoSpacing.sm) {
                ProgressView()
                Text("Odesílám nový kód…")
            }
            .font(.footnote)
        } else if viewModel.resendCooldownRemaining > 0 {
            Text(
                "Nový kód můžete poslat za \(formattedCooldown)."
            )
            .font(.footnote)
            .foregroundStyle(DuoColors.secondaryText(for: colorScheme))
        } else {
            Button("Poslat nový kód") {
                Task { await viewModel.resend() }
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    private var formattedCooldown: String {
        let seconds = viewModel.resendCooldownRemaining
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func verify() {
        isCodeFocused = false
        Task {
            if let user = await viewModel.verify() {
                session.completeAuthentication(user)
            }
        }
    }

    private func runCooldown() async {
        while !Task.isCancelled, viewModel.resendCooldownRemaining > 0 {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            viewModel.tickResendCooldown()
        }
    }
}

#Preview("Ověření") {
    let api = MockDuoCardsAPI()
    let viewModel = RegistrationViewModel(api: api)
    NavigationStack {
        VerificationPreviewContainer(viewModel: viewModel)
    }
    .environment(
        AppSession(api: api, initialState: .signedOut)
    )
}

private struct VerificationPreviewContainer: View {
    let viewModel: RegistrationViewModel

    var body: some View {
        VerificationView(viewModel: viewModel)
            .task {
                viewModel.form = RegistrationForm(
                    email: "demo@duocards.xyz",
                    nickname: "Daniel",
                    password: "Strong1!",
                    passwordConfirmation: "Strong1!"
                )
                _ = await viewModel.register()
            }
    }
}
