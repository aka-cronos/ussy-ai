import Foundation

/// Claude adapter: builds the usage query and translates its response into
/// normalized quotas.
enum Claude: ProviderAdapter {
    static let provider = Provider.claude

    static func request(for session: Session) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// Returns an error when the response does not have the expected format.
    ///
    /// `limits[]` repeats the windows (`session`, `weekly_all`) and carries the
    /// per-model limits (`weekly_scoped`), so a quota can arrive more than once.
    /// Every copy goes into the reading, which decides whether they agree.
    static func quotas(from body: Data, readAt moment: Date) -> Result<[QuotaReading], Failure> {
        guard let response = try? JSONDecoder().decode(Response.self, from: body) else { return .failure(.incompatibleResponse) }
        let limits = response.limits ?? []
        func copies(_ window: Window?, kind: String, model: String? = nil) -> [Window] {
            [window].compactMap { $0 }
                + limits.filter { $0.kind == kind && $0.scope?.model?.display_name == model }.map(\.window)
        }

        // A missing window is still a quota: it shows as unavailable.
        let base = [
            reading(.fiveHours, copies(response.five_hour, kind: "session"), at: moment),
            reading(.weekly, copies(response.seven_day, kind: "weekly_all"), at: moment),
        ]
        // Per-model limits only count when sent explicitly and with data.
        let legacy = ["Sonnet": response.seven_day_sonnet, "Opus": response.seven_day_opus]
        let models = ["Sonnet", "Opus"] + limits.compactMap { $0.kind == "weekly_scoped" ? $0.scope?.model?.display_name : nil }
        let perModel = models.uniqued().compactMap { model in
            let windows = copies(legacy[model] ?? nil, kind: "weekly_scoped", model: model)
            return windows.contains { $0.utilization != nil } ? reading(.limit(model, .weekly), windows, at: moment) : nil
        }
        return .success(base + perModel)
    }

    private static func reading(_ period: QuotaPeriod, _ windows: [Window], at moment: Date) -> QuotaReading {
        QuotaReading(
            period: period,
            usedPercents: windows.compactMap(\.utilization),
            resets: windows.compactMap { reset($0.resets_at) },
            readAt: moment
        )
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
        let limits: [Limit]?
    }

    private struct Window: Decodable {
        let utilization: Double?
        let resets_at: String?
    }

    /// An entry of `limits[]`. Its `percent` is 0–100, like `utilization`.
    private struct Limit: Decodable {
        let kind: String?
        let percent: Double?
        let resets_at: String?
        let scope: Scope?

        var window: Window { Window(utilization: percent, resets_at: resets_at) }

        struct Scope: Decodable {
            let model: Model?
        }

        struct Model: Decodable {
            let display_name: String?
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
