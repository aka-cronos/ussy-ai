import Foundation

public enum Provider: Sendable, Equatable {
    case claude
}

public struct PanelState: Sendable, Equatable {
    /// The magnitude every quota value in the panel is expressed in.
    public var magnitude: QuotaMagnitude
    public var cards: [Card]

    public init(magnitude: QuotaMagnitude, cards: [Card]) {
        self.magnitude = magnitude
        self.cards = cards
    }
}

public enum QuotaMagnitude: Sendable, Equatable {
    case used
    case remaining
}

public struct Card: Sendable, Equatable {
    public let provider: Provider
    public var content: CardContent

    public init(provider: Provider, content: CardContent) {
        self.provider = provider
        self.content = content
    }
}

public enum CardContent: Sendable, Equatable {
    /// No valid reading yet.
    case loading
    case quotas([Quota])
    /// The query failed. Specific reasons arrive with the failure states.
    case queryFailed
}

/// A subscription quota, independent of the provider's other quotas.
public struct Quota: Sendable, Equatable {
    public let period: QuotaPeriod
    public let value: QuotaValue
    public let reset: Reset
    /// When the query that produced this value was made.
    public let readAt: Date

    public init(period: QuotaPeriod, value: QuotaValue, reset: Reset, readAt: Date) {
        self.period = period
        self.value = value
        self.reset = reset
        self.readAt = readAt
    }
}

public enum QuotaPeriod: Sendable, Hashable {
    case fiveHours
    case weekly
    /// A weekly limit of a single model, e.g. "Sonnet".
    case weeklyForModel(String)
}

/// A quota's value in the panel's magnitude.
public enum QuotaValue: Sendable, Equatable {
    /// A 0–100 percentage. `calculated` when derived rather than reported by
    /// the provider.
    case percent(Double, calculated: Bool)
    /// The provider reported a negative, over-100 or contradictory figure.
    /// It is not clamped or corrected, and nothing is calculated from it.
    case uninterpretable
    /// The provider did not report this quota. Never taken as zero.
    case unavailable
}

public enum Reset: Sendable, Equatable {
    /// Still ahead.
    case at(Date)
    /// The provider gave no valid date. Never inferred from the period.
    case unknown
    /// The reset passed without a new reading, so the quota's figure no longer
    /// confirms the current quota.
    case pendingConfirmation
}
