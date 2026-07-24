import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn(User)
    }

    private(set) var api: any DuoCardsAPI
    private(set) var state: State
    private(set) var isAuthenticating = false
    var authMessage: String?
    private(set) var isPasswordResetPresented = false
    private(set) var passwordResetToken: String?
    private var didAttemptRestore = false

    /// Whether the backend answered its last reachability probe. When false, the
    /// UI surfaces that the server (Cloud Run) is unavailable and offers a switch
    /// to a custom/local backend.
    private(set) var backendReachable = true
    private(set) var isCheckingBackend = false
    var isBackendSettingsPresented = false

    /// Only live (URL-based) sessions can rebuild their client when the user
    /// changes servers; mock/demo sessions cannot and skip that work.
    private let usesLiveConfiguration: Bool

    init(
        api: any DuoCardsAPI,
        initialState: State = .restoring
    ) {
        self.api = api
        usesLiveConfiguration = false
        state = initialState
    }

    init(
        configuration: AppConfiguration,
        initialState: State = .restoring
    ) {
        api = DuoCardsAPIClient(configuration: configuration)
        usesLiveConfiguration = true
        state = initialState
    }

    /// Launch sequence: probe the backend, then restore the session only when it
    /// is reachable. When the backend is down we stop at the sign-in screen and
    /// let the UI explain the outage instead of failing mid-restore.
    func startup() async {
        await refreshBackendStatus()
        if backendReachable {
            await restoreIfNeeded()
        } else {
            state = .signedOut
        }
    }

    func refreshBackendStatus() async {
        isCheckingBackend = true
        defer { isCheckingBackend = false }
        backendReachable = await api.checkHealth()
    }

    /// Rebuilds the networking client from the current settings (e.g. after the
    /// user saves or clears a custom server) and reruns the launch sequence.
    func applyBackendSettings() async {
        guard usesLiveConfiguration else { return }
        api = DuoCardsAPIClient(configuration: AppConfiguration.live())
        didAttemptRestore = false
        authMessage = nil
        state = .restoring
        await startup()
    }

    func presentBackendSettings() {
        isBackendSettingsPresented = true
    }

    func dismissBackendSettings() {
        isBackendSettingsPresented = false
    }

    func restoreIfNeeded() async {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true

        do {
            let user = try await api.restoreSession()
            state = .signedIn(user)
        } catch let error as APIError {
            state = .signedOut
            if case .unauthorized = error {
                authMessage = nil
            } else {
                authMessage = "Relaci se nepodařila obnovit. Můžete se přihlásit znovu."
            }
        } catch {
            state = .signedOut
            authMessage = "Relaci se nepodařila obnovit. Můžete se přihlásit znovu."
        }
    }

    func login(email: String, password: String) async {
        let normalizedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            authMessage = "Vyplňte e-mail i heslo."
            return
        }

        isAuthenticating = true
        authMessage = nil
        defer { isAuthenticating = false }

        do {
            let user = try await api.login(
                email: normalizedEmail,
                password: password
            )
            state = .signedIn(user)
        } catch {
            authMessage = (error as? LocalizedError)?.errorDescription
                ?? "Přihlášení se nezdařilo."
        }
    }

    func logout() async {
        do {
            try await api.logout()
        } catch {
            // Local sign-out must remain available even when the server is offline.
        }
        state = .signedOut
        authMessage = nil
    }

    func presentPasswordReset() {
        passwordResetToken = nil
        isPasswordResetPresented = true
        authMessage = nil
    }

    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        guard let token = PasswordResetTokenParser.token(fromURL: url) else {
            return false
        }
        passwordResetToken = token
        isPasswordResetPresented = true
        authMessage = nil
        return true
    }

    func dismissPasswordReset() {
        passwordResetToken = nil
        isPasswordResetPresented = false
    }

    func completePasswordReset() {
        passwordResetToken = nil
        state = .signedOut
        authMessage = nil
    }

    func completeAuthentication(_ user: User) {
        authMessage = nil
        state = .signedIn(user)
    }

    func expireSession() {
        state = .signedOut
        authMessage = APIError.sessionExpired.errorDescription
    }
}
