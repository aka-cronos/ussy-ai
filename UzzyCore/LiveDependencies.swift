import Foundation

/// HTTP transport over `URLSession`. Each request is limited to 15 s, and
/// nothing is cached or stored: no cookies, no credentials, no responses.
/// Redirects are not followed, so only the requested host is contacted.
public struct URLSessionTransport: HTTPTransport {
    private static let timeout: TimeInterval = 15
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.timeoutIntervalForResource = Self.timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        session = URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest) async -> HTTPResult {
        do {
            let (body, response) = try await session.data(for: request, delegate: NoRedirects())
            guard let response = response as? HTTPURLResponse else { return .networkError }
            var headers: [String: String] = [:]
            for case let (name as String, value as String) in response.allHeaderFields {
                headers[name] = value
            }
            return .response(HTTPResponse(status: response.statusCode, headers: headers, body: body))
        } catch let error as URLError where error.code == .timedOut {
            return .timeout
        } catch {
            return .networkError
        }
    }
}

/// Hands a redirect back to the caller as its 3xx response instead of following it.
private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}

public struct SystemClock: WallClock {
    public init() {}

    public func now() -> Date {
        Date()
    }

    public func schedule(at deadline: Date, _ action: @escaping @MainActor @Sendable () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
            action()
        }
    }
}
