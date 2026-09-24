import Foundation

// External dependencies of the usage core. They are injected so tests use
// fakes and the app uses thin real implementations.

public struct Session: Sendable, Equatable {
    public let accessToken: String
    /// Account identity; `nil` when it cannot be verified.
    public let accountID: String?

    public init(accessToken: String, accountID: String?) {
        self.accessToken = accessToken
        self.accountID = accountID
    }
}

public enum SessionReading: Sendable, Equatable {
    case session(Session)
    case noSession
    case accessDenied
    case unknownFormat
}

public protocol SessionReader: Sendable {
    func read() async -> SessionReading
}

public struct HTTPResponse: Sendable, Equatable {
    public let status: Int
    public let headers: [String: String]
    public let body: Data

    public init(status: Int, headers: [String: String], body: Data) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

public enum HTTPResult: Sendable, Equatable {
    case response(HTTPResponse)
    case networkError
    case timeout
}

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async -> HTTPResult
}

public protocol WallClock: Sendable {
    func now() -> Date
    /// Runs `action` once the clock reaches `deadline`.
    func schedule(at deadline: Date, _ action: @escaping @MainActor @Sendable () -> Void)
}
