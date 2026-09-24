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
    private var reading = SessionReading.session(Samples.session)

    func read() async -> SessionReading {
        reads += 1
        return reading
    }

    func answer(with reading: SessionReading) {
        self.reading = reading
    }
}

/// Answers every request with the sample Claude response, or with `result`
/// when set. While held, requests wait until the test releases them.
actor ControlledTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private var result = HTTPResult.claudeSample
    private var held = false
    private var heldRequests: [CheckedContinuation<Void, Never>] = []
    private var requestWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func send(_ request: URLRequest) async -> HTTPResult {
        requests.append(request)
        let arrived = requestWaiters.filter { $0.count <= requests.count }
        requestWaiters.removeAll { $0.count <= requests.count }
        arrived.forEach { $0.continuation.resume() }
        if held {
            await withCheckedContinuation { heldRequests.append($0) }
        }
        return result
    }

    func answer(with result: HTTPResult) {
        self.result = result
    }

    func hold() {
        held = true
    }

    func release() {
        held = false
        heldRequests.forEach { $0.resume() }
        heldRequests.removeAll()
    }

    /// Returns once `count` requests have arrived.
    func waitForRequests(_ count: Int) async {
        guard requests.count < count else { return }
        await withCheckedContinuation { requestWaiters.append((count, $0)) }
    }
}

extension HTTPResult {
    /// The sample Claude response, answered with a 200.
    static let claudeSample = HTTPResult.response(
        HTTPResponse(status: 200, headers: ["Content-Type": "application/json"], body: Samples.claudeUsageResponse)
    )

    /// An empty response with `status`.
    static func status(_ status: Int) -> HTTPResult {
        .response(HTTPResponse(status: status, headers: [:], body: Data()))
    }
}
