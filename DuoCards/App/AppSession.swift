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

    let api: any DuoCardsAPI
    private(set) var state: State
    private(set) var isAuthenticating = false
    var authMessage: String?
    private var didAttemptRestore = false

    init(
        api: any DuoCardsAPI,
        initialState: State = .restoring
    ) {
        self.api = api
        state = initialState
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

    func completeAuthentication(_ user: User) {
        authMessage = nil
        state = .signedIn(user)
    }

    func expireSession() {
        state = .signedOut
        authMessage = APIError.sessionExpired.errorDescription
    }
}
