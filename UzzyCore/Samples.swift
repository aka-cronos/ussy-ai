import Foundation

/// Sanitized sample responses, in the formats observed while validating the
/// sources. They contain no real personal data.
public enum Samples {
    /// Reading moment consistent with the sample responses: 2026-09-23T14:32:00Z.
    /// A fictional session of the sample account.
    public static let session = Session(accessToken: "sample-token", accountID: "sample-account")

    public static let readingMoment = Date(timeIntervalSince1970: 1_790_173_920)

    /// Claude's `GET /api/oauth/usage`. `limits[]` repeats both windows, as the
    /// real response does. Includes fields that are ignored (opaque names,
    /// empty per-model limits and `extra_usage`).
    public static let claudeUsageResponse = Data(#"""
    {
      "five_hour": {"utilization": 35.0, "resets_at": "2026-09-23T17:00:00.000000+00:00"},
      "seven_day": {"utilization": 62.0, "resets_at": "2026-09-25T09:00:00.000000+00:00"},
      "seven_day_oauth_apps": null,
      "seven_day_opus": null,
      "seven_day_sonnet": null,
      "iguana_necktie": null,
      "extra_usage": {"is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null},
      "limits": [
        {"kind": "session", "percent": 35.0, "resets_at": "2026-09-23T17:00:00.000000+00:00", "scope": null},
        {"kind": "weekly_all", "percent": 62.0, "resets_at": "2026-09-25T09:00:00.000000+00:00", "scope": null}
      ]
    }
    """#.utf8)

    /// Codex's `GET /backend-api/wham/usage` for a ChatGPT session. Includes
    /// fields that are ignored (identifiers, plan, credits, `spend_control`
    /// and `model_usage`).
    public static let codexUsageResponse = Data(#"""
    {
      "user_id": "user-sample",
      "account_id": "sample-account",
      "email": "sample@example.com",
      "plan_type": "plus",
      "rate_limit": {
        "allowed": true,
        "limit_reached": false,
        "primary_window": {"used_percent": 12, "limit_window_seconds": 18000, "reset_after_seconds": 12480, "reset_at": 1790186400},
        "secondary_window": {"used_percent": 41, "limit_window_seconds": 604800, "reset_after_seconds": 401280, "reset_at": 1790575200}
      },
      "code_review_rate_limit": null,
      "additional_rate_limits": null,
      "model_usage": {"sample-model": {"available": true, "available_at": null, "credits_would_enable": false}},
      "credits": {
        "has_credits": true,
        "unlimited": false,
        "overage_limit_reached": false,
        "balance": "0",
        "approx_local_messages": [0, 0],
        "approx_cloud_messages": [0, 0]
      },
      "spend_control": {"reached": false, "individual_limit": null},
      "rate_limit_reached_type": null,
      "promo": null,
      "rate_limit_reset_credits": {"available_count": 0, "applicable_available_count": 0}
    }
    """#.utf8)
}

public struct SampleSessionReader: SessionReader {
    public init() {}

    public func read() async -> SessionReading {
        .session(Samples.session)
    }
}

/// Always answers each provider with the same response, and records the
/// requests it receives.
public actor SampleTransport: HTTPTransport {
    public private(set) var requests: [URLRequest] = []
    private let claudeResponse: Data
    private let codexResponse: Data

    public init(claudeResponse: Data = Samples.claudeUsageResponse, codexResponse: Data = Samples.codexUsageResponse) {
        self.claudeResponse = claudeResponse
        self.codexResponse = codexResponse
    }

    public func send(_ request: URLRequest) async -> HTTPResult {
        requests.append(request)
        let body = request.url?.host == "chatgpt.com" ? codexResponse : claudeResponse
        return .response(HTTPResponse(status: 200, headers: ["Content-Type": "application/json"], body: body))
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

    /// The clock never moves, so scheduled work never runs.
    public func schedule(at deadline: Date, _ action: @escaping @MainActor @Sendable () -> Void) {}
}
