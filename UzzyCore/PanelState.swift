import Foundation

public enum Provider: Sendable, Equatable {
    case claude
}

public struct PanelState: Sendable, Equatable {
    /// The magnitude every quota value in the panel is expressed in.
    public var magnitude: QuotaMagnitude
    public var cards: [Card]
    /// A query is in flight. Each card still changes as soon as its own
    /// result arrives.
    public var isQuerying: Bool

    public init(magnitude: QuotaMagnitude, cards: [Card], isQuerying: Bool = false) {
        self.magnitude = magnitude
        self.cards = cards
        self.isQuerying = isQuerying
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
    /// The last valid reading of the same account, kept after a failed query.
    /// Its quotas are stale and keep the time of their query.
    case stale([Quota], failure: Failure)
    /// The card has no quotas to show, and this is why.
    case failed(Failure)
}

/// Why a card has no quotas to show, or only stale ones.
public enum Failure: Sendable, Equatable {
    /// The official app has no session on this Mac.
    case noSession
    /// The user denied access to the session (the Keychain prompt).
    case sessionAccessDenied
    /// The session is stored in a format the app does not know. The
    /// credential is never shown.
    case incompatibleSession
    /// The provider rejected the session (401): it has to be renewed in the
    /// official app.
    case sessionExpired
    /// The provider refused the query (403). It may be a restriction other
    /// than the session, so it is not taken as an expired session.
    case accessRefused
    /// The provider could not be reached: the network is down.
    case offline
    /// The provider did not answer within the time limit.
    case timedOut
    /// The provider failed to answer the query (5xx).
    case serverError(status: Int)
    /// The provider answered with something the app does not understand, e.g.
    /// because it changed its format. No alternative route is tried.
    case incompatibleResponse
}

/// A subscription quota, independent of the provider's other quotas.
public struct Quota: Sendable, Equatable {
    public let period: QuotaPeriod
    public let value: QuotaValue
    public let reset: Reset
    /// When the query that produced this value was made.
    public let readAt: Date
    /// The value no longer confirms the current quota: a later query failed,
    /// or the reset passed without a new reading.
    public let isStale: Bool

    public init(period: QuotaPeriod, value: QuotaValue, reset: Reset, readAt: Date, isStale: Bool = false) {
        self.period = period
        self.value = value
        self.reset = reset
        self.readAt = readAt
        self.isStale = isStale
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
