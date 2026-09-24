import Foundation

/// Sanitized sample responses, in the formats observed while validating the
/// sources. They contain no real personal data.
public enum Samples {
    /// Reading moment consistent with the sample responses: 2026-09-23T14:32:00Z.
    public static let readingMoment = Date(timeIntervalSince1970: 1_790_173_920)

    /// Claude's `GET /api/oauth/usage`. Includes fields that are ignored
    /// (opaque names, empty per-model limits and `extra_usage`).
    public static let claudeUsageResponse = Data(#"""
    {
      "five_hour": {"utilization": 35.0, "resets_at": "2026-09-23T17:00:00.000000+00:00"},
      "seven_day": {"utilization": 62.0, "resets_at": "2026-09-25T09:00:00.000000+00:00"},
      "seven_day_oauth_apps": null,
      "seven_day_opus": null,
      "seven_day_sonnet": null,
      "iguana_necktie": null,
      "extra_usage": {"is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null}
    }
    """#.utf8)
}

public struct SampleSessionReader: SessionReader {
    public init() {}

    public func read() async -> SessionReading {
        .session(Session(accessToken: "sample-token", accountID: "sample-account"))
    }
}

/// Always returns the same response and records the requests it receives.
public actor SampleTransport: HTTPTransport {
    public private(set) var requests: [URLRequest] = []
    private let claudeResponse: Data

    public init(claudeResponse: Data) {
        self.claudeResponse = claudeResponse
    }

    public func send(_ request: URLRequest) async -> HTTPResult {
        requests.append(request)
        return .response(HTTPResponse(status: 200, headers: ["Content-Type": "application/json"], body: claudeResponse))
    }
}

public struct FixedClock: WallClock {
    private let moment: Date

    public init(_ moment: Date) {
        self.moment = moment
    }

    public func now() -> Date {
        moment
    }
}
