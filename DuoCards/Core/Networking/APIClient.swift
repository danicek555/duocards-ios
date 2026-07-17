import Foundation

actor APIClient {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    private let baseURL: URL
    private let fallbackBaseURL: URL?
    private let cookieStorage: HTTPCookieStorage
    private let session: URLSession

    init(
        baseURL: URL,
        fallbackBaseURL: URL? = nil,
        cookieStorage: HTTPCookieStorage = .shared
    ) {
        self.baseURL = baseURL
        self.fallbackBaseURL = fallbackBaseURL
        self.cookieStorage = cookieStorage

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = cookieStorage
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadRevalidatingCacheData
        session = URLSession(configuration: configuration)
    }

    func get<Response: Decodable & Sendable>(
        _ path: String,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        let data = try await execute(path: path, method: .get, body: nil)
        return try decode(type, from: data)
    }

    func send<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        method: Method = .post,
        body: Body,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        let encodedBody: Data
        do {
            encodedBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        let data = try await execute(
            path: path,
            method: method,
            body: encodedBody
        )
        return try decode(type, from: data)
    }

    func perform(
        _ path: String,
        method: Method = .post
    ) async throws {
        _ = try await execute(path: path, method: method, body: nil)
    }

    func perform<Body: Encodable & Sendable>(
        _ path: String,
        method: Method = .post,
        body: Body
    ) async throws {
        let encodedBody: Data
        do {
            encodedBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        _ = try await execute(path: path, method: method, body: encodedBody)
    }

    func clearAuthenticationCookies() {
        for url in [baseURL, fallbackBaseURL].compactMap({ $0 }) {
            for cookie in cookieStorage.cookies(for: url) ?? []
            where cookie.name == "auth" {
                cookieStorage.deleteCookie(cookie)
            }
        }
    }

    private func execute(
        path: String,
        method: Method,
        body: Data?
    ) async throws -> Data {
        let cleanPath = path.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        return try await execute(
            cleanPath: cleanPath,
            method: method,
            body: body,
            baseURL: baseURL,
            mayFallback: true
        )
    }

    private func execute(
        cleanPath: String,
        method: Method,
        body: Data?,
        baseURL: URL,
        mayFallback: Bool
    ) async throws -> Data {
        let url = baseURL.appending(path: cleanPath)
        guard url.scheme != nil, url.host != nil else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if mayFallback, let fallbackBaseURL {
                return try await execute(
                    cleanPath: cleanPath,
                    method: method,
                    body: body,
                    baseURL: fallbackBaseURL,
                    mayFallback: false
                )
            }
            throw APIError.transport(Self.transportMessage(for: error))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if mayFallback,
               [502, 503, 504].contains(httpResponse.statusCode),
               let fallbackBaseURL {
                return try await execute(
                    cleanPath: cleanPath,
                    method: method,
                    body: body,
                    baseURL: fallbackBaseURL,
                    mayFallback: false
                )
            }
            let envelope = try? JSONDecoder().decode(
                APIErrorEnvelope.self,
                from: data
            )
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized(
                    code: envelope?.code,
                    message: envelope?.displayMessage
                        ?? "Přihlášení vypršelo. Přihlaste se prosím znovu."
                )
            }
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(
                    forHTTPHeaderField: "Retry-After"
                ).flatMap(Int.init)
                throw APIError.rateLimited(
                    code: envelope?.code,
                    message: envelope?.displayMessage
                        ?? "Příliš mnoho požadavků. Zkuste to prosím později.",
                    retryAfterSeconds: retryAfter
                )
            }
            throw APIError.server(
                status: httpResponse.statusCode,
                code: envelope?.code,
                message: envelope?.displayMessage
                    ?? HTTPURLResponse.localizedString(
                        forStatusCode: httpResponse.statusCode
                    )
            )
        }

        return data
    }

    private static func transportMessage(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return error.localizedDescription
        }

        switch urlError.code {
        case .timedOut:
            return "Připojení k serveru trvalo příliš dlouho. Zkuste to znovu."
        case .notConnectedToInternet, .networkConnectionLost:
            return "Zkontrolujte připojení k internetu a zkuste to znovu."
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return "K serveru DuoCards se nepodařilo připojit."
        default:
            return urlError.localizedDescription
        }
    }

    private func decode<Response: Decodable>(
        _ type: Response.Type,
        from data: Data
    ) throws -> Response {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}
