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
    /// `extra_usage` adds the usage-credit limit after them; nothing else in
    /// the response about spend or amounts is read.
    static func quotas(from body: Data, readAt moment: Date) -> Result<[QuotaReading], Failure> {
        guard let response = try? JSONDecoder().decode(Response.self, from: body) else { return .failure(.incompatibleResponse) }
        let limits = response.limits ?? []
        // One pass groups the entries, so reading each quota does not scan
        // `limits[]` again.
        var entries: [Limit.Key: [Window]] = [:]
        for limit in limits {
            entries[limit.key, default: []].append(limit.window)
        }
        func copies(_ window: Window?, kind: String, model: String? = nil) -> [Window] {
            [window].compactMap { $0 } + entries[Limit.Key(kind: kind, model: model), default: []]
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
        var quotas = base + perModel
        if let usageCredits = usageCredits(response.extra_usage, at: moment) {
            quotas.append(usageCredits)
        }
        return .success(quotas)
    }

    /// The share of the usage-credit limit used, or nothing when there is no
    /// limit to measure against or no figure for it.
    private static func usageCredits(_ extraUsage: ExtraUsage?, at moment: Date) -> QuotaReading? {
        guard let extraUsage, let limit = extraUsage.monthlyLimit else { return nil }
        let reported = extraUsage.utilization.values
        // Both operands come from the same object, so they share one unit.
        let calculated = extraUsage.usedCredits.values.map { 100 * $0 / limit }
        guard !reported.isEmpty || !calculated.isEmpty else { return nil }
        // The provider sends no period boundary, so the reset stays unknown.
        return QuotaReading(
            period: .usageCredits,
            usedPercents: reported,
            calculatedUsedPercents: calculated,
            resets: [],
            readAt: moment
        )
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
        let extra_usage: ExtraUsage?
    }

    /// `extra_usage`, the usage-credit meter. It is read leniently: no value
    /// in it can make the response incompatible. Amounts and `currency` are
    /// never kept.
    private struct ExtraUsage: Decodable {
        /// A finite, positive monthly limit, when usage credits are enabled.
        /// Otherwise there is no limit to measure against.
        let monthlyLimit: Double?
        let utilization: Figure
        let usedCredits: Figure

        /// A figure of `extra_usage`: a JSON number, nothing, or a value that
        /// is not a usable number.
        enum Figure {
            case number(Double)
            case absent
            case invalid

            /// The figure as the values a reading checks. An invalid figure
            /// gives NaN, so the quota it belongs to is uninterpretable.
            var values: [Double] {
                switch self {
                case .number(let value): [value]
                case .absent: []
                case .invalid: [.nan]
                }
            }
        }

        private enum CodingKeys: String, CodingKey {
            case is_enabled, monthly_limit, used_credits, utilization
        }

        init(from decoder: any Decoder) {
            guard let values = try? decoder.container(keyedBy: CodingKeys.self) else {
                monthlyLimit = nil
                utilization = .absent
                usedCredits = .absent
                return
            }
            let isEnabled = (try? values.decodeIfPresent(Bool.self, forKey: .is_enabled)) == true
            let limit = try? values.decodeIfPresent(Double.self, forKey: .monthly_limit)
            monthlyLimit = if isEnabled, let limit, limit.isFinite, limit > 0 { limit } else { nil }
            utilization = Self.figure(values, .utilization)
            usedCredits = Self.figure(values, .used_credits)
        }

        private static func figure(_ values: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Figure {
            do {
                return try values.decodeIfPresent(Double.self, forKey: key).map(Figure.number) ?? .absent
            } catch {
                return .invalid
            }
        }
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
        var key: Key { Key(kind: kind, model: scope?.model?.display_name) }

        /// The quota an entry is a copy of: its kind and, if scoped, its model.
        struct Key: Hashable {
            let kind: String?
            let model: String?
        }

        struct Scope: Decodable {
            let model: Model?
        }

        struct Model: Decodable {
            let display_name: String?
        }
    }
}
