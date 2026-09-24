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
    /// After a network or server failure, automatic queries wait this long,
    /// doubling with each consecutive failure up to `longestRetryWait`.
    nonisolated static let firstRetryWait: TimeInterval = 30
    nonisolated static let longestRetryWait: TimeInterval = 15 * 60

    private var magnitude = QuotaMagnitude.used
    private var claude = ProviderReading.loading
    private var claudeQuery: Task<Void, Never>?
    /// The last session read on a user action, reused by the queries no user
    /// action asked for. `nil` when that read gave no usable session.
    @ObservationIgnored private var claudeSession: Session?
    /// Identifies the only scheduled query that may still run. `nil` while
    /// the panel is closed.
    @ObservationIgnored private var cadence: UUID?
    /// Consecutive network or server failures of Claude.
    @ObservationIgnored private var claudeFailures = 0
    /// Queries no user action asked for wait until then.
    @ObservationIgnored private var claudeRetryAt: Date?
    /// No query at all is made before then, not even on Actualizar: Claude
    /// asked to wait (429 with `Retry-After`).
    @ObservationIgnored private var claudeWaitsUntil: Date?
    /// Identifies the only scheduled retry that may still run.
    @ObservationIgnored private var claudeRetry: UUID?

    private let claudeSessionReader: any SessionReader
    private let transport: any HTTPTransport
    private let clock: any WallClock
    private let log: any EventLog

    public init(
        claudeSessionReader: any SessionReader,
        transport: any HTTPTransport,
        clock: any WallClock,
        log: any EventLog = SystemLog()
    ) {
        self.claudeSessionReader = claudeSessionReader
        self.transport = transport
        self.clock = clock
        self.log = log
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
        case .failed(.sessionAccessDenied, _):
            // The user said no; only Actualizar asks again.
            break
        case .failed(let failure, _) where failure.isRejection:
            // Only a session that changed since the rejection is worth a query.
            queryClaude(.read(skipping: claudeSession))
        default:
            if !claude.isFresh(at: clock.now()) {
                queryClaude(.read(skipping: nil))
            }
        }
        scheduleNextQuery()
        scheduleClaudeRetry()
    }

    /// The Actualizar button: reads the session and queries even when the
    /// reading is fresh or the session was rejected.
    public func refresh() {
        queryClaude(.read(skipping: nil))
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
        claudeRetry = nil
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
    /// provider rejects a session, or the user denies access to it, only the
    /// user asks again.
    private func queryClaudeOnItsOwn() {
        guard !claude.waitsForTheUser, let claudeSession, claudeRetryAt.map({ clock.now() >= $0 }) ?? true
        else { return }
        queryClaude(.reuse(claudeSession))
    }

    /// Never two queries of the same provider at once: a repeated request
    /// joins the one in flight.
    private func queryClaude(_ source: SessionSource) {
        guard claudeQuery == nil, claudeWaitsUntil.map({ clock.now() >= $0 }) ?? true else { return }
        claudeQuery = Task {
            if let reading = await readClaude(source) {
                claude = reading
                planClaudeRetry(after: reading)
            }
            claudeQuery = nil
        }
    }

    /// Network and server failures are retried on their own, each time
    /// waiting longer, up to a cap. When Claude says how long to wait, that
    /// is the wait. Anything else ends the wait.
    private func planClaudeRetry(after reading: ProviderReading) {
        claudeWaitsUntil = nil
        guard case .failed(let failure, _) = reading, failure.isWorthRetrying else {
            claudeFailures = 0
            claudeRetryAt = nil
            return
        }
        claudeFailures += 1
        if case .rateLimited(let until?) = failure {
            claudeWaitsUntil = until
            claudeRetryAt = until
        } else {
            let wait = min(Self.firstRetryWait * pow(2, Double(claudeFailures - 1)), Self.longestRetryWait)
            claudeRetryAt = clock.now().addingTimeInterval(wait)
        }
        scheduleClaudeRetry()
    }

    /// Only while the panel is open. Replaces any retry scheduled before.
    private func scheduleClaudeRetry() {
        guard cadence != nil, let claudeRetryAt else { return }
        let retry = UUID()
        claudeRetry = retry
        clock.schedule(at: claudeRetryAt) { [weak self] in
            guard let self, self.claudeRetry == retry else { return }
            queryClaudeOnItsOwn()
        }
    }

    /// `nil` when the card keeps what it shows: the session read is the one
    /// to skip, or the provider rejected a reused session.
    private func readClaude(_ source: SessionSource) async -> ProviderReading? {
        let session: Session
        switch source {
        case .reuse(let reused):
            session = reused
        case .read(let skipped):
            let reading = await claudeSessionReader.read()
            if let failure = Failure(reading) {
                claudeSession = nil
                return .failed(failure, keeping: nil)
            }
            guard case .session(let read) = reading, read != skipped else { return nil }
            session = read
            claudeSession = read
        }
        let result = await transport.send(Claude.request(accessToken: session.accessToken))
        let failure: Failure
        switch Self.answer(to: result, at: clock.now()) {
        case .quotas(let quotas): return .quotas(LastValidReading(quotas: quotas, accountID: session.accountID))
        case .failed(let why): failure = why
        }
        log.record(.queryFailed(.claude, failure))
        if failure.isRejection, case .reuse = source {
            // The official app may have renewed the token since it was
            // read, so the session is not called expired. Automatic
            // queries stop; the next user action reads it again.
            claudeSession = nil
            return nil
        }
        return .failed(failure, keeping: claude.lastValidReading(of: session.accountID))
    }

    /// The quotas in the provider's answer, or why there are none.
    private static func answer(to result: HTTPResult, at moment: Date) -> Answer {
        let response: HTTPResponse
        switch result {
        case .response(let answer): response = answer
        case .networkError: return .failed(.offline)
        case .timeout: return .failed(.timedOut)
        }
        switch response.status {
        case 200:
            guard let quotas = Claude.quotas(from: response.body, readAt: moment) else { return .failed(.incompatibleResponse) }
            return .quotas(quotas)
        case 401: return .failed(.sessionExpired)
        case 403: return .failed(.accessRefused)
        case 429: return .failed(.rateLimited(until: retryAfter(response.headers, from: moment)))
        case 500...599: return .failed(.serverError(status: response.status))
        // Anything else means the route or its format changed.
        default: return .failed(.incompatibleResponse)
        }
    }
}

/// What a provider's answer to a query says.
private enum Answer {
    case quotas([QuotaReading])
    case failed(Failure)
}

/// Where a query takes the provider's session from.
private enum SessionSource {
    /// Reads it, which may show the Keychain prompt. Skips the query when the
    /// session read is `skipping`, e.g. the one the provider rejected.
    case read(skipping: Session?)
    /// Reuses a session read before, without reading it again.
    case reuse(Session)
}

private extension Failure {
    /// Why a session reading gave no session; `nil` when it gave one.
    init?(_ reading: SessionReading) {
        switch reading {
        case .session: return nil
        case .noSession: self = .noSession
        case .accessDenied: self = .sessionAccessDenied
        case .unknownFormat: self = .incompatibleSession
        }
    }

    /// The network or the provider's server failed, or the provider asked to
    /// wait: it may work shortly.
    var isWorthRetrying: Bool {
        switch self {
        case .offline, .timedOut, .serverError, .rateLimited: true
        default: false
        }
    }

    var isRejection: Bool {
        self == .sessionExpired || self == .accessRefused
    }
}

/// What the core last learned from a provider.
private enum ProviderReading {
    case loading
    case quotas(LastValidReading)
    /// `keeping` the last valid reading of the same account, now stale.
    case failed(Failure, keeping: LastValidReading?)

    func isFresh(at now: Date) -> Bool {
        guard case .quotas(let reading) = self, let readAt = reading.quotas.map(\.readAt).min() else { return false }
        return now.timeIntervalSince(readAt) < UsageCore.refreshInterval
    }

    /// The provider rejected the session, or the user denied access to it.
    var waitsForTheUser: Bool {
        guard case .failed(let failure, _) = self else { return false }
        return failure.isRejection || failure == .sessionAccessDenied
    }

    /// The last valid reading, if it belongs to `accountID`. A reading whose
    /// account cannot be verified belongs to no one.
    func lastValidReading(of accountID: String?) -> LastValidReading? {
        let last: LastValidReading?
        switch self {
        case .loading: last = nil
        case .quotas(let reading): last = reading
        case .failed(_, let kept): last = kept
        }
        guard let last, let accountID, last.accountID == accountID else { return nil }
        return last
    }

    func content(in magnitude: QuotaMagnitude, at now: Date) -> CardContent {
        switch self {
        case .loading:
            .loading
        case .quotas(let reading):
            .quotas(reading.quotas.map { $0.quota(in: magnitude, at: now) })
        case .failed(let failure, let kept?):
            .stale(kept.quotas.map { $0.quota(in: magnitude, at: now, stale: true) }, failure: failure)
        case .failed(let failure, nil):
            .failed(failure)
        }
    }
}

/// The quotas of a provider's last valid query, and the account they belong
/// to; `nil` when it could not be verified.
private struct LastValidReading {
    let quotas: [QuotaReading]
    let accountID: String?
}

/// When a `Retry-After` header, in seconds or as an HTTP date, says to query
/// again; `nil` without a valid one.
private func retryAfter(_ headers: [String: String], from moment: Date) -> Date? {
    guard let value = headers.first(where: { $0.key.caseInsensitiveCompare("Retry-After") == .orderedSame })?.value
        .trimmingCharacters(in: .whitespaces)
    else { return nil }
    if let seconds = Int(value), seconds >= 0 {
        return moment.addingTimeInterval(TimeInterval(seconds))
    }
    let format = DateFormatter()
    format.locale = Locale(identifier: "en_US_POSIX")
    format.timeZone = TimeZone(identifier: "GMT")
    format.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    return format.date(from: value)
}
