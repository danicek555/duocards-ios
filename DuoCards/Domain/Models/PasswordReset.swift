import Foundation

struct ForgotPasswordRequest: Codable, Equatable, Sendable {
    let email: String
}

struct ResetPasswordRequest: Codable, Equatable, Sendable {
    let token: String
    let password: String
}

struct PasswordResetResponse: Codable, Equatable, Sendable {
    let message: String
}

enum PasswordResetTokenParser {
    static let maximumTokenLength = 256

    static func token(fromInput rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.contains("://") {
            guard let url = URL(string: value) else { return nil }
            return token(fromURL: url)
        }

        return validatedRawToken(value)
    }

    static func token(fromURL url: URL) -> String? {
        guard url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else {
            return nil
        }

        let normalizedPath = url.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard normalizedPath == ["reset-password"],
              let components = URLComponents(
                  url: url,
                  resolvingAgainstBaseURL: false
              ) else {
            return nil
        }

        let queryToken = components.queryItems?.first(where: {
            $0.name == "token"
        })?.value
        let fragmentToken = tokenFromFragment(components.fragment)
        // Prefer the new fragment capability if a transitional URL happens to
        // contain both forms; a stale query value must not override it.
        guard let token = fragmentToken ?? queryToken else { return nil }

        return validatedRawToken(
            token.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func tokenFromFragment(_ fragment: String?) -> String? {
        guard let fragment, !fragment.isEmpty else { return nil }
        var components = URLComponents()
        components.query = fragment
        return components.queryItems?.first(where: {
            $0.name == "token"
        })?.value
    }

    private static func validatedRawToken(_ token: String) -> String? {
        guard !token.isEmpty,
              token.count <= maximumTokenLength,
              !token.unicodeScalars.contains(where: {
                  CharacterSet.whitespacesAndNewlines.contains($0)
                      || CharacterSet.controlCharacters.contains($0)
              }) else {
            return nil
        }

        let isBase64URLToken = token.count == 43
            && token.unicodeScalars.allSatisfy {
                (48...57).contains($0.value)
                    || (65...90).contains($0.value)
                    || (97...122).contains($0.value)
                    || $0 == "-"
                    || $0 == "_"
            }
        let isLegacyHexToken = token.count == 64
            && token.unicodeScalars.allSatisfy {
                (48...57).contains($0.value)
                    || (65...70).contains($0.value)
                    || (97...102).contains($0.value)
            }
        return isBase64URLToken || isLegacyHexToken ? token : nil
    }
}
