import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            switch session.state {
            case .restoring:
                LaunchLoadingView()
            case .signedOut:
                LoginView()
            case let .signedIn(user):
                DashboardView(user: user, api: session.api)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.state)
        .overlay(alignment: .top) {
            if !session.backendReachable {
                BackendUnavailableBanner(
                    onOpenSettings: { session.presentBackendSettings() },
                    onRetry: { Task { await session.refreshBackendStatus() } }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            if isSignedOutOrRestoring {
                Button {
                    session.presentBackendSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .padding(DuoSpacing.md)
                }
                .tint(DuoColors.indigo600)
                .accessibilityLabel("Nastavení serveru")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.backendReachable)
        .sheet(
            isPresented: Binding(
                get: { session.isPasswordResetPresented },
                set: { isPresented in
                    if !isPresented { session.dismissPasswordReset() }
                }
            )
        ) {
            NavigationStack {
                PasswordResetFlowView(
                    api: session.api,
                    initialToken: session.passwordResetToken,
                    onPasswordReset: session.completePasswordReset
                )
            }
        }
        .sheet(
            isPresented: Binding(
                get: { session.isBackendSettingsPresented },
                set: { isPresented in
                    if !isPresented { session.dismissBackendSettings() }
                }
            )
        ) {
            NavigationStack {
                BackendSettingsView()
            }
        }
    }

    private var isSignedOutOrRestoring: Bool {
        switch session.state {
        case .signedIn:
            return false
        case .signedOut, .restoring:
            return true
        }
    }
}

private struct BackendUnavailableBanner: View {
    let onOpenSettings: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: DuoSpacing.sm) {
            Label(
                "Backend (Cloud Run) je nedostupný.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(
                "Server neodpovídá. Zkuste to znovu, nebo se přepněte na "
                    + "vlastní lokální backend."
            )
            .font(.caption)
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DuoSpacing.md) {
                Button("Zkusit znovu", action: onRetry)
                    .buttonStyle(.bordered)
                Button("Nastavit server", action: onOpenSettings)
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .tint(.white)
            .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(DuoSpacing.md)
        .background(DuoColors.amber500)
        .clipShape(RoundedRectangle(cornerRadius: DuoRadius.medium))
        .padding(.horizontal, DuoSpacing.md)
        .padding(.top, DuoSpacing.sm)
    }
}

private struct LaunchLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            DuoBackground()
            VStack(spacing: DuoSpacing.lg) {
                DuoBrandMark(size: 76)
                Text("DuoCards")
                    .font(.largeTitle.bold())
                    .foregroundStyle(DuoColors.brandGradient)
                ProgressView()
                    .tint(DuoColors.indigo600)
                Text("Obnovuji přihlášení…")
                    .font(.subheadline)
                    .foregroundStyle(
                        DuoColors.secondaryText(for: colorScheme)
                    )
            }
        }
    }
}
