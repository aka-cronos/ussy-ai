import Foundation
import Observation

/// Refresh coordinator and in-memory panel state.
/// It is the only test seam: its external dependencies are injected.
@MainActor
@Observable
public final class UsageCore {
    /// Depends on the clock too: a reset that passes changes the state.
    public var state: PanelState {
        let now = clock.now()
        return PanelState(magnitude: magnitude, cards: [
            Card(provider: .claude, content: claude.content(in: magnitude, at: now)),
        ])
    }

    private var magnitude = QuotaMagnitude.used
    private var claude = ProviderReading.loading

    private let claudeSessionReader: any SessionReader
    private let transport: any HTTPTransport
    private let clock: any WallClock

    public init(claudeSessionReader: any SessionReader, transport: any HTTPTransport, clock: any WallClock) {
        self.claudeSessionReader = claudeSessionReader
        self.transport = transport
        self.clock = clock
    }

    public func now() -> Date {
        clock.now()
    }

    /// Expresses every quota as used or remaining quota.
    public func show(_ magnitude: QuotaMagnitude) {
        self.magnitude = magnitude
    }

    public func panelOpened() async {
        await refreshClaude()
    }

    private func refreshClaude() async {
        guard case .session(let session) = await claudeSessionReader.read(),
              case .response(let response) = await transport.send(Claude.request(accessToken: session.accessToken)),
              response.status == 200,
              let quotas = Claude.quotas(from: response.body, readAt: clock.now())
        else {
            claude = .queryFailed
            return
        }
        claude = .quotas(quotas)
    }
}

/// What the core last learned from a provider.
private enum ProviderReading {
    case loading
    case quotas([QuotaReading])
    case queryFailed

    func content(in magnitude: QuotaMagnitude, at now: Date) -> CardContent {
        switch self {
        case .loading: .loading
        case .quotas(let quotas): .quotas(quotas.map { $0.quota(in: magnitude, at: now) })
        case .queryFailed: .queryFailed
        }
    }
}
