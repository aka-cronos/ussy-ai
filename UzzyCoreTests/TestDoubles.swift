import Foundation
import Synchronization
import UzzyCore

/// A clock the test moves by hand. Moving it runs, in order, the work
/// scheduled up to the new moment.
final class ManualClock: WallClock {
    private struct Scheduled {
        let deadline: Date
        let action: @MainActor @Sendable () -> Void
    }

    private let state: Mutex<(moment: Date, scheduled: [Scheduled])>

    init(_ moment: Date) {
        state = Mutex((moment, []))
    }

    func now() -> Date {
        state.withLock { $0.moment }
    }

    func schedule(at deadline: Date, _ action: @escaping @MainActor @Sendable () -> Void) {
        state.withLock { $0.scheduled.append(Scheduled(deadline: deadline, action: action)) }
    }

    @MainActor
    func move(to moment: Date) {
        while let next = nextDue(by: moment) {
            next.action()
        }
        state.withLock { $0.moment = moment }
    }

    @MainActor
    func advance(by interval: TimeInterval) {
        move(to: now().addingTimeInterval(interval))
    }

    /// Takes the earliest work due by `moment` and moves the clock to its deadline.
    private func nextDue(by moment: Date) -> Scheduled? {
        state.withLock { state in
            guard let index = state.scheduled.indices
                .filter({ state.scheduled[$0].deadline <= moment })
                .min(by: { state.scheduled[$0].deadline < state.scheduled[$1].deadline })
            else { return nil }
            let next = state.scheduled.remove(at: index)
            state.moment = max(state.moment, next.deadline)
            return next
        }
    }
}

/// Returns the sample session, or `reading` when set, and counts the reads.
/// Reading a real session can show the Keychain prompt.
actor ControlledSessionReader: SessionReader {
    private(set) var reads = 0
    private var reading: SessionReading

    init(answering reading: SessionReading = .session(Samples.session)) {
        self.reading = reading
    }

    func read() async -> SessionReading {
        reads += 1
        return reading
    }

    func answer(with reading: SessionReading) {
        self.reading = reading
    }
}

/// A provider signed out of its official app: the panel never queries it.
struct NoSessionReader: SessionReader {
    func read() async -> SessionReading {
        .noSession
    }
}

/// Answers each provider's requests with its sample response, or with the
/// result set for it. While a provider is held, its requests wait until the
/// test releases them.
actor ControlledTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private var results: [Provider: HTTPResult] = [.claude: .claudeSample, .codex: .codexSample]
    private var held: Set<Provider> = []
    private var heldRequests: [CheckedContinuation<Void, Never>] = []
    private var requestWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func send(_ request: URLRequest) async -> HTTPResult {
        requests.append(request)
        let arrived = requestWaiters.filter { $0.count <= requests.count }
        requestWaiters.removeAll { $0.count <= requests.count }
        arrived.forEach { $0.continuation.resume() }
        guard let provider = Provider(of: request) else { return .networkError }
        if held.contains(provider) {
            await withCheckedContinuation { heldRequests.append($0) }
        }
        return results[provider] ?? .networkError
    }

    /// Answers the requests of `provider`, or of every provider, with `result`.
    func answer(with result: HTTPResult, for provider: Provider? = nil) {
        for each in provider.map({ [$0] }) ?? Provider.all {
            results[each] = result
        }
    }

    /// Holds the requests of `provider`, or of every provider.
    func hold(_ provider: Provider? = nil) {
        held.formUnion(provider.map { [$0] } ?? Provider.all)
    }

    func release() {
        held.removeAll()
        heldRequests.forEach { $0.resume() }
        heldRequests.removeAll()
    }

    /// The requests sent to `provider`.
    func requests(to provider: Provider) -> [URLRequest] {
        requests.filter { Provider(of: $0) == provider }
    }

    /// Returns once `count` requests have arrived.
    func waitForRequests(_ count: Int) async {
        guard requests.count < count else { return }
        await withCheckedContinuation { requestWaiters.append((count, $0)) }
    }
}

extension Provider {
    static let all: [Provider] = [.claude, .codex]

    /// The provider a request is sent to, by its host.
    init?(of request: URLRequest) {
        switch request.url?.host {
        case "api.anthropic.com": self = .claude
        case "chatgpt.com": self = .codex
        default: return nil
        }
    }
}

extension HTTPResult {
    /// The sample Claude response, answered with a 200.
    static let claudeSample = HTTPResult.response(
        HTTPResponse(status: 200, headers: ["Content-Type": "application/json"], body: Samples.claudeUsageResponse)
    )

    /// The sample Codex response, answered with a 200.
    static let codexSample = HTTPResult.response(
        HTTPResponse(status: 200, headers: ["Content-Type": "application/json"], body: Samples.codexUsageResponse)
    )

    /// A Codex response, answered with a 200, with the given `rate_limit`
    /// and `additional_rate_limits` JSON.
    static func codex(rateLimit: String, additional: String = "null") -> HTTPResult {
        let body = #"{"plan_type": "plus", "rate_limit": \#(rateLimit), "additional_rate_limits": \#(additional)}"#
        return .response(HTTPResponse(status: 200, headers: ["Content-Type": "application/json"], body: Data(body.utf8)))
    }

    /// An empty response with `status`.
    static func status(_ status: Int) -> HTTPResult {
        .response(HTTPResponse(status: status, headers: [:], body: Data()))
    }
}

/// Keeps the events the core logs.
final class RecordingLog: EventLog {
    private let recorded = Mutex<[LogEvent]>([])

    var events: [LogEvent] {
        recorded.withLock { $0 }
    }

    func record(_ event: LogEvent) {
        recorded.withLock { $0.append(event) }
    }
}
