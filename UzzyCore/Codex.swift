import Foundation

/// Codex adapter: builds the usage query of a ChatGPT session and translates
/// its response into normalized quotas.
enum Codex: ProviderAdapter {
    static let provider = Provider.codex

    static func request(for session: Session) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        // The session reader always gives the account (`tokens.account_id`).
        if let accountID = session.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        return request
    }

    /// Returns an error when the response does not have the expected format.
    ///
    /// Each window is named by its length, never by its position: the
    /// provider may send the weekly window first. Windows of the same length
    /// are copies of one quota, and the reading decides whether they agree.
    /// Credits, spend control, model usage and every identifier are ignored.
    static func quotas(from body: Data, readAt moment: Date) -> Result<[QuotaReading], Failure> {
        guard let response = try? JSONDecoder().decode(Response.self, from: body) else { return .failure(.incompatibleResponse) }
        let limits = (response.additional_rate_limits ?? []).compactMap { limit in
            limit.limit_name.map { name in readings(of: limit.rate_limit, at: moment) { .limit(name, $0) } }
        }
        let quotas = readings(of: response.rate_limit, at: moment) { $0 } + limits.joined()
        // Nothing says the plan has no quotas, so a response without any
        // window is not understood.
        return quotas.isEmpty ? .failure(.incompatibleResponse) : .success(quotas)
    }

    /// One reading per window length, the shortest first.
    private static func readings(
        of rateLimit: RateLimit?,
        at moment: Date,
        named name: (QuotaPeriod) -> QuotaPeriod
    ) -> [QuotaReading] {
        let windows = [rateLimit?.primary_window, rateLimit?.secondary_window].compactMap { $0 }
        let lengths = Set(windows.map(\.limit_window_seconds)).sorted()
        return lengths.map { length in
            let copies = windows.filter { $0.limit_window_seconds == length }
            return QuotaReading(
                period: name(period(lasting: length)),
                usedPercents: copies.compactMap(\.used_percent),
                resets: copies.compactMap(\.reset_at).map { Date(timeIntervalSince1970: $0) },
                readAt: moment
            )
        }
    }

    private static func period(lasting seconds: Int) -> QuotaPeriod {
        switch seconds {
        case 18_000: .fiveHours
        case 604_800: .weekly
        default: .lasting(seconds: seconds)
        }
    }

    private struct Response: Decodable {
        let rate_limit: RateLimit?
        let additional_rate_limits: [AdditionalLimit]?
    }

    private struct RateLimit: Decodable {
        let primary_window: Window?
        let secondary_window: Window?
    }

    /// A limit the provider sends apart from the main windows, e.g. for a
    /// single model. Without a name it cannot be told apart, so it is left out.
    private struct AdditionalLimit: Decodable {
        let limit_name: String?
        let rate_limit: RateLimit?
    }

    private struct Window: Decodable {
        let used_percent: Double?
        let limit_window_seconds: Int
        let reset_at: Double?

        private enum CodingKeys: String, CodingKey {
            case used_percent, limit_window_seconds, reset_at
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            used_percent = try values.decodeIfPresent(Double.self, forKey: .used_percent)
            limit_window_seconds = try values.decode(Int.self, forKey: .limit_window_seconds)
            // A bad reset must not discard a valid percentage. Keep an
            // invalid value so another copy cannot supply a trusted reset.
            do {
                reset_at = try values.decodeIfPresent(Double.self, forKey: .reset_at)
            } catch {
                reset_at = .nan
            }
        }
    }
}
