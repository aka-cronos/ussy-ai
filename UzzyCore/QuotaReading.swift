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
    /// Every used percentage calculated from other data of this quota,
    /// unchecked. They are checked like the reported ones, which are shown
    /// first when there are any.
    let calculatedUsedPercents: [Double]
    /// Every reset date reported for this quota, unchecked. Text that is not
    /// a date is left out.
    let resets: [Date]
    let readAt: Date

    init(period: QuotaPeriod, usedPercents: [Double], calculatedUsedPercents: [Double] = [], resets: [Date], readAt: Date) {
        self.period = period
        self.usedPercents = usedPercents
        self.calculatedUsedPercents = calculatedUsedPercents
        self.resets = resets
        self.readAt = readAt
    }

    /// Copies of a figure that differ by more than this contradict each other.
    /// It matches the precision the figures are checked against.
    static let percentAgreement = 1.0
    static let resetAgreement: TimeInterval = 60
    /// A reset further than this from the reading, in either direction, is
    /// not a date the quota can have. A year, leap years included.
    static let maxResetDistance: TimeInterval = 366 * 86_400

    /// `stale` when a later query failed. A reset that passed without a new
    /// reading makes the figure stale too.
    func quota(in magnitude: QuotaMagnitude, at now: Date, stale: Bool = false) -> Quota {
        let reset = reset(at: now)
        return Quota(
            period: period,
            value: value(in: magnitude),
            reset: reset,
            readAt: readAt,
            isStale: stale || reset == .pendingConfirmation
        )
    }

    private func reset(at now: Date) -> Reset {
        guard let reset = resets.first,
              resets.allSatisfy({ abs($0.timeIntervalSince(readAt)) <= Self.maxResetDistance }),
              resets.allSatisfy({ abs($0.timeIntervalSince(reset)) <= Self.resetAgreement })
        else { return .unknown }
        return reset > now ? .at(reset) : .pendingConfirmation
    }

    private func value(in magnitude: QuotaMagnitude) -> QuotaValue {
        let figures = usedPercents + calculatedUsedPercents
        guard let usedPercent = figures.first else { return .unavailable }
        guard figures.allSatisfy({ $0.isFinite && (0...100).contains($0) }),
              figures.allSatisfy({ abs($0 - usedPercent) <= Self.percentAgreement })
        else { return .uninterpretable }
        return switch magnitude {
        case .used: .percent(usedPercent, calculated: usedPercents.isEmpty)
        case .remaining: .percent(100 - usedPercent, calculated: true)
        }
    }
}
