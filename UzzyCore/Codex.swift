import Foundation

/// Codex adapter: builds the usage query of a ChatGPT session and translates
/// its response into normalized quotas.
enum Codex: ProviderAdapter {
    static let provider = Provider.codex

    static func request(for session: Session) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID = session.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        return request
    }

    /// Returns `nil` when the response does not have the expected format.
    static func quotas(from body: Data, readAt moment: Date) -> [QuotaReading]? {
        guard let response = try? JSONDecoder().decode(Response.self, from: body) else { return nil }
        let windows = [response.rate_limit?.primary_window, response.rate_limit?.secondary_window].compactMap { $0 }
        return windows.map { window in
            QuotaReading(
                period: window.limit_window_seconds == 18_000 ? .fiveHours : .weekly,
                usedPercents: [window.used_percent].compactMap { $0 },
                resets: [window.reset_at].compactMap { $0 }.map { Date(timeIntervalSince1970: $0) },
                readAt: moment
            )
        }
    }

    private struct Response: Decodable {
        let rate_limit: RateLimit?
    }

    private struct RateLimit: Decodable {
        let primary_window: Window?
        let secondary_window: Window?
    }

    private struct Window: Decodable {
        let used_percent: Double?
        let limit_window_seconds: Int
        let reset_at: Double?
    }
}
