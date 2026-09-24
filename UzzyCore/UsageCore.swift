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
    /// The last session read on a user action, reused by the queries no user
    /// action asked for. `nil` when that read gave no usable session.
    @ObservationIgnored private var claudeSession: Session?
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

    /// Reads the session again, which may show the Keychain prompt: opening
    /// the panel is a user action.
    public func panelOpened() {
        switch claude {
        case .failed(.sessionAccessDenied):
            // The user said no; only Actualizar asks again.
            break
        case .failed(.sessionExpired), .failed(.accessRefused):
            // Only a session that changed since the rejection is worth a query.
            queryClaude(.read(unlessItIs: claudeSession))
        default:
            if !claude.isFresh(at: clock.now()) {
                queryClaude(.read(unlessItIs: nil))
            }
        }
        scheduleNextQuery()
    }

    /// The Actualizar button: reads the session and queries even when the
    /// reading is fresh or the session was rejected.
    public func refresh() {
        queryClaude(.read(unlessItIs: nil))
    }

    /// Queries on waking from sleep while the panel is open, and restarts the
    /// cadence from then.
    public func systemWoke() {
        guard cadence != nil else { return }
        queryClaudeOnItsOwn()
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
            queryClaudeOnItsOwn()
            scheduleNextQuery()
        }
    }

    /// A query no user action asked for. It never reads the session, so it
    /// never shows the Keychain prompt: it reuses the last one read. After the
    /// provider rejects the session, or the user denies access to it, only
    /// the user asks again.
    private func queryClaudeOnItsOwn() {
        guard !claude.waitsForTheUser, let claudeSession else { return }
        queryClaude(.reuse(claudeSession))
    }

    /// Never two queries of the same provider at once: a repeated request
    /// joins the one in flight.
    private func queryClaude(_ source: SessionSource) {
        guard claudeQuery == nil else { return }
        claudeQuery = Task {
            if let reading = await readClaude(source) {
                claude = reading
            }
            claudeQuery = nil
        }
    }

    /// `nil` when the session read is the one to skip, so nothing was queried.
    private func readClaude(_ source: SessionSource) async -> ProviderReading? {
        let session: Session
        switch source {
        case .reuse(let reused):
            session = reused
        case .read(let skipped):
            let reading = await claudeSessionReader.read()
            guard case .session(let read) = reading else {
                claudeSession = nil
                return .failed(Failure(reading))
            }
            guard read != skipped else { return nil }
            session = read
            claudeSession = read
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

/// Where a query takes the provider's session from.
private enum SessionSource {
    /// Reads it, which may show the Keychain prompt, and skips the query when
    /// it is still `unlessItIs`.
    case read(unlessItIs: Session?)
    /// Reuses a session read before, without reading it again.
    case reuse(Session)
}

private extension Failure {
    /// Why a session reading gave no session.
    init(_ reading: SessionReading) {
        switch reading {
        case .noSession, .session: self = .noSession
        case .accessDenied: self = .sessionAccessDenied
        case .unknownFormat: self = .incompatibleSession
        }
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

    /// The provider rejected the session, or the user denied access to it.
    var waitsForTheUser: Bool {
        switch self {
        case .failed(.sessionExpired), .failed(.accessRefused), .failed(.sessionAccessDenied): true
        default: false
        }
    }

    func content(in magnitude: QuotaMagnitude, at now: Date) -> CardContent {
        switch self {
        case .loading: .loading
        case .quotas(let quotas): .quotas(quotas.map { $0.quota(in: magnitude, at: now) })
        case .failed(let failure): .failed(failure)
        }
    }
}
