import Foundation

/// Cursor adapter: builds the usage query of Cursor's session and translates
/// its response into the two bags of the billing cycle.
enum Cursor: ProviderAdapter {
    static let provider = Provider.cursor

    /// A Connect call with an empty JSON message. There is no REST fallback.
    static func request(for session: Session) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.httpBody = Data("{}".utf8)
        return request
    }

    /// Returns `nil` when the response does not have the expected format.
    ///
    /// Both bags share the billing cycle and its end. `totalPercentUsed`
    /// contradicts the usage the provider shows, so it is never read, and
    /// neither are the amounts or the text messages.
    static func quotas(from body: Data, readAt moment: Date) -> [QuotaReading]? {
        guard let response = try? JSONDecoder().decode(Response.self, from: body),
              let usage = response.planUsage
        else { return nil }
        let resets = [response.billingCycleEnd.flatMap(date(fromMilliseconds:))].compactMap { $0 }
        func reading(_ bag: String, _ usedPercent: Double?) -> QuotaReading {
            QuotaReading(
                period: .limit(bag, .billingCycle),
                usedPercents: [usedPercent].compactMap { $0 },
                resets: resets,
                readAt: moment
            )
        }
        return [
            reading("Cursor Models", usage.autoPercentUsed),
            reading("Other Models", usage.apiPercentUsed),
        ]
    }

    /// `billingCycleEnd` is a string of epoch milliseconds.
    private static func date(fromMilliseconds text: String) -> Date? {
        guard let milliseconds = Int64(text), milliseconds > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }

    private struct Response: Decodable {
        let billingCycleEnd: String?
        let planUsage: PlanUsage?
    }

    private struct PlanUsage: Decodable {
        let autoPercentUsed: Double?
        let apiPercentUsed: Double?
    }
}
