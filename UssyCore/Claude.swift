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
    static func quotas(from body: Data, readAt moment: Date) -> [QuotaReading]? {
        guard let response = try? JSONDecoder().decode(Response.self, from: body) else { return nil }
        let windows: [(QuotaPeriod, Window?)] = [(.fiveHours, response.five_hour), (.weekly, response.seven_day)]
        // A missing window is still a quota: it shows as unavailable.
        let baseWindows = windows.map { period, window in reading(period, window, at: moment) }
        // Per-model limits only count when sent explicitly and with data.
        let models: [(String, Window?)] = [("Sonnet", response.seven_day_sonnet), ("Opus", response.seven_day_opus)]
        let perModel = models.compactMap { model, window in
            window?.utilization == nil ? nil : reading(.weeklyForModel(model), window, at: moment)
        }
        return baseWindows + perModel
    }

    private static func reading(_ period: QuotaPeriod, _ window: Window?, at moment: Date) -> QuotaReading {
        QuotaReading(period: period, usedPercent: window?.utilization, reset: reset(window?.resets_at), readAt: moment)
    }

    private static func reset(_ text: String?) -> Date? {
        guard let text else { return nil }
        return (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
            ?? (try? Date.ISO8601FormatStyle().parse(text))
    }

    private struct Response: Decodable {
        let five_hour: Window?
        let seven_day: Window?
        let seven_day_sonnet: Window?
        let seven_day_opus: Window?
    }

    private struct Window: Decodable {
        let utilization: Double?
        let resets_at: String?
    }
}
