import Foundation

public enum Provider: Sendable, Equatable {
    case claude
}

public struct PanelState: Sendable, Equatable {
    public var cards: [Card]

    public init(cards: [Card]) {
        self.cards = cards
    }
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
    /// Name of the quota period, e.g. "5 horas" or "Semanal".
    public let period: String
    /// Used quota, as a 0–100 percentage, as reported by the provider.
    public let usedPercent: Double
    public let reset: Reset
    /// When the query that produced this value was made.
    public let readAt: Date

    public init(period: String, usedPercent: Double, reset: Reset, readAt: Date) {
        self.period = period
        self.usedPercent = usedPercent
        self.reset = reset
        self.readAt = readAt
    }
}

public enum Reset: Sendable, Equatable {
    case at(Date)
    case unknown
}
