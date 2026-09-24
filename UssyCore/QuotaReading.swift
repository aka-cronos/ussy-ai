import Foundation

/// A quota as the provider reported it, before the presentation rules apply.
///
/// A provider may report the same quota more than once. Every copy is kept so
/// that copies that disagree can be told apart from a single figure.
struct QuotaReading: Sendable, Equatable {
    let period: QuotaPeriod
    /// Every used percentage reported for this quota, unchecked. Empty when
    /// the quota was not reported.
    let usedPercents: [Double]
    /// Every valid reset date reported for this quota.
    let resets: [Date]
    let readAt: Date

    /// Copies of a figure that differ by more than this contradict each other.
    /// It matches the precision the figures are checked against.
    static let percentAgreement = 1.0
    static let resetAgreement: TimeInterval = 60

    func quota(in magnitude: QuotaMagnitude, at now: Date) -> Quota {
        Quota(period: period, value: value(in: magnitude), reset: reset(at: now), readAt: readAt)
    }

    private func reset(at now: Date) -> Reset {
        guard let reset = resets.first,
              resets.allSatisfy({ abs($0.timeIntervalSince(reset)) <= Self.resetAgreement })
        else { return .unknown }
        return reset > now ? .at(reset) : .pendingConfirmation
    }

    private func value(in magnitude: QuotaMagnitude) -> QuotaValue {
        guard let usedPercent = usedPercents.first else { return .unavailable }
        guard usedPercents.allSatisfy({ $0.isFinite && (0...100).contains($0) }),
              usedPercents.allSatisfy({ abs($0 - usedPercent) <= Self.percentAgreement })
        else { return .uninterpretable }
        return switch magnitude {
        case .used: .percent(usedPercent, calculated: false)
        case .remaining: .percent(100 - usedPercent, calculated: true)
        }
    }
}
