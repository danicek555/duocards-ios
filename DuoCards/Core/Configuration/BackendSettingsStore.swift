import Foundation

/// Persists an optional user-chosen backend origin. When set, the app talks to
/// this server — typically a local or self-hosted DuoCards backend — instead of
/// the default Cloud Run deployment. This is what lets the app keep working when
/// the Cloud Run backend is turned off: point it at a local backend instead.
struct BackendSettingsStore {
    static let customBaseURLKey = "duocards.customBackendBaseURL"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The stored custom origin, or nil when the default Cloud Run backend is used.
    var customBaseURL: URL? {
        guard let raw = defaults.string(forKey: Self.customBaseURLKey) else {
            return nil
        }
        return Self.normalizedURL(raw)
    }

    /// Stores a custom origin. Returns the normalized URL on success, or nil when
    /// the input is not a usable http(s) origin.
    @discardableResult
    func setCustomBaseURL(_ rawValue: String) -> URL? {
        guard let url = Self.normalizedURL(rawValue) else { return nil }
        defaults.set(url.absoluteString, forKey: Self.customBaseURLKey)
        return url
    }

    /// Removes the custom origin, reverting the app to the default Cloud Run backend.
    func clearCustomBaseURL() {
        defaults.removeObject(forKey: Self.customBaseURLKey)
    }

    /// Reduces a raw string to a bare http(s) origin (scheme://host[:port]). The
    /// networking client appends `/api/v1` itself, so any path is dropped. Unlike
    /// AppConfiguration's default resolution this accepts LAN hosts and http, so a
    /// physical device can target a local backend (e.g. http://192.168.1.20:4000).
    static func normalizedURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty
        else {
            return nil
        }

        var origin = URLComponents()
        origin.scheme = scheme
        origin.host = host
        origin.port = components.port
        return origin.url
    }
}
