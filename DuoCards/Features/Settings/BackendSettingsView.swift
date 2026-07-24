import SwiftUI

/// Lets the user see which backend the app talks to, test its reachability, and
/// point the app at a custom/local server when the default Cloud Run backend is
/// turned off.
struct BackendSettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    private let store = BackendSettingsStore()

    @State private var customURLText = ""
    @State private var validationMessage: String?
    @State private var isApplying = false

    var body: some View {
        Form {
            statusSection
            customServerSection
            infoSection
        }
        .navigationTitle("Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Hotovo") { dismiss() }
            }
        }
        .onAppear {
            customURLText = store.customBaseURL?.absoluteString ?? ""
        }
        .interactiveDismissDisabled(isApplying)
    }

    private var statusSection: some View {
        Section("Aktuální backend") {
            LabeledContent("Adresa") {
                Text(AppConfiguration.live().baseURL.absoluteString)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Režim") {
                Text(
                    AppConfiguration.isUsingCustomServer()
                        ? "Vlastní server"
                        : "Cloud Run (výchozí)"
                )
                .foregroundStyle(.secondary)
            }

            HStack {
                if session.isCheckingBackend {
                    ProgressView()
                    Text("Ověřuji dostupnost…")
                        .foregroundStyle(.secondary)
                } else {
                    Image(
                        systemName: session.backendReachable
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(
                        session.backendReachable
                            ? DuoColors.indigo600
                            : DuoColors.amber500
                    )
                    Text(
                        session.backendReachable
                            ? "Backend odpovídá."
                            : "Backend neodpovídá."
                    )
                }
                Spacer()
                Button("Test") {
                    Task { await session.refreshBackendStatus() }
                }
                .disabled(session.isCheckingBackend)
            }
        }
    }

    private var customServerSection: some View {
        Section {
            TextField(
                "https://192.168.1.20:4000",
                text: $customURLText
            )
            .textContentType(.URL)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(DuoColors.red500)
            }

            Button {
                Task { await saveCustomServer() }
            } label: {
                if isApplying {
                    ProgressView()
                } else {
                    Text("Uložit a připojit")
                }
            }
            .disabled(isApplying || customURLText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty)

            if AppConfiguration.isUsingCustomServer() {
                Button(role: .destructive) {
                    Task { await useDefaultServer() }
                } label: {
                    Text("Použít výchozí Cloud Run")
                }
                .disabled(isApplying)
            }
        } header: {
            Text("Vlastní server")
        } footer: {
            Text(
                "Zadejte adresu vlastního (lokálního) backendu, například "
                    + "http://192.168.1.20:4000. Aplikace si sama doplní cestu "
                    + "/api/v1. Na fyzickém zařízení použijte LAN adresu, ne "
                    + "localhost."
            )
        }
    }

    private var infoSection: some View {
        Section {
            Text(
                "Když je Cloud Run zapnutý, aplikace komunikuje s nasazeným "
                    + "backendem. Když ho vypnete, přepněte se zde na vlastní "
                    + "lokální backend."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func saveCustomServer() async {
        guard let url = store.setCustomBaseURL(customURLText) else {
            validationMessage =
                "Neplatná adresa. Zadejte http(s) adresu serveru."
            return
        }
        validationMessage = nil
        customURLText = url.absoluteString
        isApplying = true
        await session.applyBackendSettings()
        isApplying = false
        dismiss()
    }

    private func useDefaultServer() async {
        store.clearCustomBaseURL()
        validationMessage = nil
        customURLText = ""
        isApplying = true
        await session.applyBackendSettings()
        isApplying = false
        dismiss()
    }
}

#Preview("Nastavení serveru") {
    NavigationStack {
        BackendSettingsView()
            .environment(
                AppSession(
                    api: MockDuoCardsAPI(),
                    initialState: .signedOut
                )
            )
    }
}
