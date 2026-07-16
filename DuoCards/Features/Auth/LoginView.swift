import SwiftUI

struct LoginView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    @State private var email = ""
    @State private var password = ""
    @State private var showsRegistration = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            DuoBackground()
            ScrollView {
                VStack(spacing: DuoSpacing.xl) {
                    header
                    loginCard
                    registrationCard
                    nextIterationCard
#if DEBUG
                    Text("API: \(AppConfiguration.live().baseURL.absoluteString)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(
                            DuoColors.secondaryText(for: colorScheme)
                        )
                        .multilineTextAlignment(.center)
#endif
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, DuoSpacing.lg)
                .padding(.vertical, DuoSpacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showsRegistration) {
            NavigationStack {
                RegistrationView(api: session.api)
            }
        }
        .onChange(of: session.state) { _, state in
            if case .signedIn = state {
                showsRegistration = false
            }
        }
    }

    private var header: some View {
        VStack(spacing: DuoSpacing.md) {
            DuoBrandMark(size: 72)
            Text("PŘIHLÁŠENÍ")
                .font(.caption.bold().monospaced())
                .tracking(1.4)
                .foregroundStyle(DuoColors.indigo600)
                .padding(.horizontal, DuoSpacing.md)
                .padding(.vertical, 6)
                .background(DuoColors.indigo50)
                .clipShape(Capsule())
            Text("DuoCards")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(DuoColors.brandGradient)
            Text("Vítejte zpět. Přihlaste se ke svým kartičkám.")
                .font(.subheadline)
                .foregroundStyle(
                    DuoColors.secondaryText(for: colorScheme)
                )
                .multilineTextAlignment(.center)
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: DuoSpacing.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text("E-mail")
                    .font(.subheadline.weight(.medium))
                TextField("vas@email.cz", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .duoTextField()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Heslo")
                    .font(.subheadline.weight(.medium))
                SecureField("Zadejte heslo", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .duoTextField()

                HStack {
                    Spacer()
                    Button("Zapomněli jste heslo?") {
                        focusedField = nil
                        password = ""
                        session.presentPasswordReset()
                    }
                    .font(.footnote.weight(.semibold))
                }
            }

            if let message = session.authMessage {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(DuoColors.red500)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DuoSpacing.md)
                    .background(DuoColors.red500.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DuoRadius.small))
            }

            Button(action: submit) {
                HStack {
                    if session.isAuthenticating {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(
                        session.isAuthenticating
                            ? "Přihlašuji…"
                            : "Přihlásit se"
                    )
                    .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.white)
                .background(DuoColors.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: DuoRadius.medium))
            }
            .disabled(
                email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || password.isEmpty
                    || session.isAuthenticating
            )
            .opacity(
                email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || password.isEmpty
                    ? 0.55
                    : 1
            )
        }
        .duoCard(padding: DuoSpacing.xl)
    }

    private var nextIterationCard: some View {
        VStack(spacing: DuoSpacing.sm) {
            Label("Další iterace", systemImage: "hammer.fill")
                .font(.subheadline.bold())
                .foregroundStyle(DuoColors.violet600)
            Text("Přihlášení přes Google a Facebook bude doplněno v další vertikále.")
                .font(.footnote)
                .foregroundStyle(
                    DuoColors.secondaryText(for: colorScheme)
                )
                .multilineTextAlignment(.center)
        }
        .padding(DuoSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(DuoColors.violet100.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: DuoRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: DuoRadius.medium)
                .stroke(DuoColors.violet400.opacity(0.5))
        }
    }

    private var registrationCard: some View {
        VStack(spacing: DuoSpacing.md) {
            Text("Ještě nemáte účet?")
                .font(.headline)
            Text("Zaregistrujte se e-mailem a ověřte účet šestimístným kódem.")
                .font(.footnote)
                .foregroundStyle(
                    DuoColors.secondaryText(for: colorScheme)
                )
                .multilineTextAlignment(.center)
            Button {
                showsRegistration = true
            } label: {
                Label("Vytvořit účet", systemImage: "person.badge.plus")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.borderedProminent)
        }
        .duoCard()
    }

    private func submit() {
        focusedField = nil
        Task {
            await session.login(email: email, password: password)
        }
    }
}

extension View {
    func duoTextField() -> some View {
        self
            .padding(.horizontal, DuoSpacing.md)
            .frame(height: 48)
            .background(DuoColors.gray50)
            .clipShape(RoundedRectangle(cornerRadius: DuoRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: DuoRadius.medium)
                    .stroke(DuoColors.gray200)
            }
    }
}

#Preview("Přihlášení") {
    LoginView()
        .environment(
            AppSession(
                api: MockDuoCardsAPI(),
                initialState: .signedOut
            )
        )
}
