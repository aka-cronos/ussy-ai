import Foundation

/// Claude adapter: builds the usage query and translates its response into
/// normalized quotas.
enum Claude {
    static func request(accessToken: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// Returns `nil` when the response does not have the expected format.
    static func quotas(from body: Data, readAt moment: Date) -> [Quota]? {
        guard let response = try? JSONDecoder().decode(Response.self, from: body) else { return nil }
        let windows = [("5 horas", response.five_hour), ("Semanal", response.seven_day)]
        return windows.compactMap { period, window in
            window.map { Quota(period: period, usedPercent: $0.utilization, reset: reset($0.resets_at), readAt: moment) }
        }
    }

    private static func reset(_ text: String?) -> Reset {
        guard let text else { return .unknown }
        let date = (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
            ?? (try? Date.ISO8601FormatStyle().parse(text))
        return date.map(Reset.at) ?? .unknown
    }

    private struct Response: Decodable {
        let five_hour: Window?
        let seven_day: Window?
    }

    private struct Window: Decodable {
        let utilization: Double
        let resets_at: String?
    }
}
