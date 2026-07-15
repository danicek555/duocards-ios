import Foundation

struct AppConfiguration: Sendable {
    static let defaultBaseURL = URL(string: "http://localhost:4000")!

    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    static func live(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> AppConfiguration {
        AppConfiguration(
            baseURL: resolvedBaseURL(bundle: bundle, processInfo: processInfo)
        )
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
            url.host != nil
        else {
            return nil
        }
        return url
    }
}
