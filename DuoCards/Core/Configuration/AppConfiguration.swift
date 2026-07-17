import Foundation

struct AppConfiguration: Sendable {
    static let defaultBaseURL = URL(
        string: "https://duocards-backend-731652720086.europe-west1.run.app"
    )!

    let baseURL: URL
    let fallbackBaseURL: URL?

    init(baseURL: URL, fallbackBaseURL: URL? = nil) {
        self.baseURL = baseURL
        self.fallbackBaseURL = fallbackBaseURL
    }

    static func live(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> AppConfiguration {
        AppConfiguration(
            baseURL: resolvedBaseURL(bundle: bundle, processInfo: processInfo),
            fallbackBaseURL: resolvedFallbackBaseURL(
                bundle: bundle,
                processInfo: processInfo
            )
        )
    }

    private static func resolvedFallbackBaseURL(
        bundle: Bundle,
        processInfo: ProcessInfo
    ) -> URL? {
        let arguments = processInfo.arguments
        if let index = arguments.firstIndex(of: "-duocardsAPIFallbackURL"),
           arguments.indices.contains(index + 1),
           let url = validURL(arguments[index + 1]) {
            return url
        }
        if let value = processInfo.environment["DUOCARDS_API_FALLBACK_URL"],
           let url = validURL(value) {
            return url
        }
        if let value = bundle.object(
            forInfoDictionaryKey: "DuoCardsAPIFallbackURL"
        ) as? String {
            return validURL(value)
        }
        return nil
    }

    private static func resolvedBaseURL(
        bundle: Bundle,
        processInfo: ProcessInfo
    ) -> URL {
        let arguments = processInfo.arguments
        if let flagIndex = arguments.firstIndex(of: "-duocardsAPIBaseURL"),
           arguments.indices.contains(flagIndex + 1),
           let argumentURL = validURL(arguments[flagIndex + 1]) {
            return argumentURL
        }

        if let environmentValue = processInfo.environment["DUOCARDS_API_BASE_URL"],
           let environmentURL = validURL(environmentValue) {
            return environmentURL
        }

        if let plistValue = bundle.object(
            forInfoDictionaryKey: "DuoCardsAPIBaseURL"
        ) as? String,
           let plistURL = validURL(plistValue) {
            return plistURL
        }

        return defaultBaseURL
    }

    private static func validURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            !trimmed.contains("$("),
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = url.host,
            isReachableHost(host)
        else {
            return nil
        }
        return url
    }

    private static func isReachableHost(_ host: String) -> Bool {
#if targetEnvironment(simulator)
        true
#else
        !["localhost", "127.0.0.1", "::1"].contains(host.lowercased())
#endif
    }
}
