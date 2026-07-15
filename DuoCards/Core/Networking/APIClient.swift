import Foundation

actor APIClient {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    private let baseURL: URL
    private let cookieStorage: HTTPCookieStorage
    private let session: URLSession

    init(
        baseURL: URL,
        cookieStorage: HTTPCookieStorage = .shared
    ) {
        self.baseURL = baseURL
        self.cookieStorage = cookieStorage

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = cookieStorage
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
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

    func clearAuthenticationCookies() {
        let baseCookies = cookieStorage.cookies(for: baseURL) ?? []
        for cookie in baseCookies where cookie.name == "auth" {
            cookieStorage.deleteCookie(cookie)
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
            throw APIError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
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
