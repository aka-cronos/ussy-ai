import Foundation

/// A quota as the provider reported it, before the presentation rules apply.
struct QuotaReading: Sendable, Equatable {
    let period: QuotaPeriod
    /// Used quota as a percentage, unchecked; `nil` when not reported.
    let usedPercent: Double?
    /// `nil` when the provider gave no valid date.
    let reset: Date?
    let readAt: Date

    func quota(in magnitude: QuotaMagnitude, at now: Date) -> Quota {
        Quota(period: period, value: value(in: magnitude), reset: reset(at: now), readAt: readAt)
    }

    private func reset(at now: Date) -> Reset {
        guard let reset else { return .unknown }
        return reset > now ? .at(reset) : .pendingConfirmation
    }

    private func value(in magnitude: QuotaMagnitude) -> QuotaValue {
        guard let usedPercent else { return .unavailable }
        guard usedPercent.isFinite, (0...100).contains(usedPercent) else { return .uninterpretable }
        return switch magnitude {
        case .used: .percent(usedPercent, calculated: false)
        case .remaining: .percent(100 - usedPercent, calculated: true)
        }
    }
}
