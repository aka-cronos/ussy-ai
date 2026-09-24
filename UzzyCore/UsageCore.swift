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
        ], isQuerying: claudeQuery != nil)
    }

    /// How often providers are queried while the panel is open. Opening the
    /// panel does not query a provider whose reading is younger than this.
    nonisolated static let refreshInterval: TimeInterval = 5 * 60

    private var magnitude = QuotaMagnitude.used
    private var claude = ProviderReading.loading
    private var claudeQuery: Task<Void, Never>?
    /// Identifies the only scheduled query that may still run. `nil` while
    /// the panel is closed.
    @ObservationIgnored private var cadence: UUID?

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

    public func panelOpened() {
        if !claude.isFresh(at: clock.now()) {
            queryClaude()
        }
        scheduleNextQuery()
    }

    /// The Actualizar button: queries even when the reading is fresh.
    public func refresh() {
        queryClaude()
    }

    /// Queries on waking from sleep while the panel is open, and restarts the
    /// cadence from then.
    public func systemWoke() {
        guard cadence != nil else { return }
        queryClaude()
        scheduleNextQuery()
    }

    /// Stops scheduling queries. A query in flight still finishes.
    public func panelClosed() {
        cadence = nil
    }

    /// Returns once no query is in flight.
    public func queriesFinished() async {
        await claudeQuery?.value
    }

    /// Replaces any query scheduled before.
    private func scheduleNextQuery() {
        let cadence = UUID()
        self.cadence = cadence
        clock.schedule(at: clock.now().addingTimeInterval(Self.refreshInterval)) { [weak self] in
            guard let self, self.cadence == cadence else { return }
            queryClaude()
            scheduleNextQuery()
        }
    }

    /// Never two queries of the same provider at once: a repeated request
    /// joins the one in flight.
    private func queryClaude() {
        guard claudeQuery == nil else { return }
        claudeQuery = Task {
            claude = await readClaude()
            claudeQuery = nil
        }
    }

    private func readClaude() async -> ProviderReading {
        let session: Session
        switch await claudeSessionReader.read() {
        case .session(let read): session = read
        case .noSession: return .failed(.noSession)
        case .accessDenied: return .failed(.sessionAccessDenied)
        case .unknownFormat: return .failed(.incompatibleSession)
        }
        guard case .response(let response) = await transport.send(Claude.request(accessToken: session.accessToken))
        else { return .failed(.queryFailed) }
        switch response.status {
        case 401: return .failed(.sessionExpired)
        case 403: return .failed(.accessRefused)
        default: break
        }
        guard response.status == 200,
              let quotas = Claude.quotas(from: response.body, readAt: clock.now())
        else { return .failed(.queryFailed) }
        return .quotas(quotas)
    }
}

/// What the core last learned from a provider.
private enum ProviderReading {
    case loading
    case quotas([QuotaReading])
    case failed(Failure)

    func isFresh(at now: Date) -> Bool {
        guard case .quotas(let quotas) = self, let readAt = quotas.map(\.readAt).min() else { return false }
        return now.timeIntervalSince(readAt) < UsageCore.refreshInterval
    }

    func content(in magnitude: QuotaMagnitude, at now: Date) -> CardContent {
        switch self {
        case .loading: .loading
        case .quotas(let quotas): .quotas(quotas.map { $0.quota(in: magnitude, at: now) })
        case .failed(let failure): .failed(failure)
        }
    }
}
