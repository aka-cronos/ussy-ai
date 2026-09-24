import Foundation
import Testing
import UzzyCore

/// What the card shows when a query fails because of the network or the
/// provider, and how the panel retries it.
@MainActor
struct ProviderFailureTests {
    let clock = ManualClock(Samples.readingMoment)
    let transport = ControlledTransport()
    let log = RecordingLog()
    let core: UsageCore
    let refreshInterval: TimeInterval = 5 * 60
    // 2026-09-23T17:00:00Z and 2026-09-25T09:00:00Z, from the sample response.
    let fiveHourReset = Date(timeIntervalSince1970: 1_790_182_800)
    let weeklyReset = Date(timeIntervalSince1970: 1_790_326_800)

    init() {
        core = UsageCore(claudeSessionReader: SampleSessionReader(), transport: transport, clock: clock, log: log)
    }

    func claudeContent() -> CardContent? {
        core.state.cards.first(where: { $0.provider == .claude })?.content
    }

    @Test(arguments: [
        (HTTPResult.networkError, Failure.offline),
        (.timeout, .timedOut),
        (.status(500), .serverError(status: 500)),
        (.status(503), .serverError(status: 503)),
    ])
    func withoutAPreviousReadingTheCardExplainsTheFailure(result: HTTPResult, failure: Failure) async {
        await transport.answer(with: result)

        core.panelOpened()
        await core.queriesFinished()

        #expect(claudeContent() == .failed(failure))
    }

    @Test(arguments: [
        (HTTPResult.networkError, Failure.offline),
        (.timeout, .timedOut),
        (.status(500), .serverError(status: 500)),
        (.response(HTTPResponse(status: 200, headers: [:], body: Data("<html></html>".utf8))), .incompatibleResponse),
    ])
    func withAPreviousReadingTheCardKeepsItAsStaleWithItsOriginalTime(result: HTTPResult, failure: Failure) async {
        core.panelOpened()
        await core.queriesFinished()

        await transport.answer(with: result)
        clock.advance(by: refreshInterval)
        await core.queriesFinished()

        #expect(claudeContent() == .stale([
            Quota(period: .fiveHours, value: .percent(35, calculated: false), reset: .at(fiveHourReset), readAt: Samples.readingMoment, isStale: true),
            Quota(period: .weekly, value: .percent(62, calculated: false), reset: .at(weeklyReset), readAt: Samples.readingMoment, isStale: true),
        ], failure: failure))
    }

    @Test func aNewValidReadingReplacesTheStaleOne() async {
        core.panelOpened()
        await core.queriesFinished()
        await transport.answer(with: .networkError)
        clock.advance(by: refreshInterval)
        await core.queriesFinished()

        await transport.answer(with: .claudeSample)
        core.refresh()
        await core.queriesFinished()

        guard case .quotas(let quotas) = claudeContent() else {
            Issue.record("Expected fresh quotas")
            return
        }
        #expect(quotas.allSatisfy { !$0.isStale && $0.readAt == clock.now() })
    }

    @Test func aSessionFailureDoesNotKeepThePreviousReading() async {
        let sessionReader = ControlledSessionReader()
        let core = UsageCore(claudeSessionReader: sessionReader, transport: transport, clock: clock, log: log)
        core.panelOpened()
        await core.queriesFinished()

        await sessionReader.answer(with: .noSession)
        core.refresh()
        await core.queriesFinished()

        #expect(core.state.cards.first?.content == .failed(.noSession))
    }

    @Test func aReadingOfAnotherAccountIsNotKeptAfterAFailure() async {
        let sessionReader = ControlledSessionReader()
        let core = UsageCore(claudeSessionReader: sessionReader, transport: transport, clock: clock, log: log)
        core.panelOpened()
        await core.queriesFinished()

        await sessionReader.answer(with: .session(Session(accessToken: "other-token", accountID: "other-account")))
        await transport.answer(with: .networkError)
        core.refresh()
        await core.queriesFinished()

        #expect(core.state.cards.first?.content == .failed(.offline))
    }

    @Test func aReadingIsNotKeptWhenTheAccountCannotBeVerified() async {
        let sessionReader = ControlledSessionReader()
        let core = UsageCore(claudeSessionReader: sessionReader, transport: transport, clock: clock, log: log)
        core.panelOpened()
        await core.queriesFinished()

        await sessionReader.answer(with: .session(Session(accessToken: "sample-token", accountID: nil)))
        await transport.answer(with: .networkError)
        core.refresh()
        await core.queriesFinished()

        #expect(core.state.cards.first?.content == .failed(.offline))
    }

    @Test(arguments: [
        HTTPResult.response(HTTPResponse(status: 200, headers: [:], body: Data(#"{"five_hour": "sample-secret"}"#.utf8))),
        .response(HTTPResponse(status: 200, headers: [:], body: Data("<html>sample-secret</html>".utf8))),
        .response(HTTPResponse(status: 404, headers: [:], body: Data("sample-secret".utf8))),
    ])
    func aResponseThatCannotBeUnderstoodIsIncompatibleAndNoOtherRouteIsTried(result: HTTPResult) async {
        await transport.answer(with: result)

        core.panelOpened()
        await core.queriesFinished()

        #expect(claudeContent() == .failed(.incompatibleResponse))
        #expect(await transport.requests.count == 1)
    }

    @Test func theLogKeepsOnlyTheCategoryOfAnIncompatibleResponse() async {
        await transport.answer(with: .response(HTTPResponse(status: 200, headers: [:], body: Data("sample-secret".utf8))))

        core.panelOpened()
        await core.queriesFinished()

        #expect(log.events == [.queryFailed(.claude, .incompatibleResponse)])
    }

    @Test(arguments: [
        (HTTPResult.networkError, Failure.offline),
        (.timeout, .timedOut),
        (.status(502), .serverError(status: 502)),
    ])
    func theLogKeepsOnlyTheCategoryAndCodeOfAFailure(result: HTTPResult, failure: Failure) async {
        await transport.answer(with: result)

        core.panelOpened()
        await core.queriesFinished()

        #expect(log.events == [.queryFailed(.claude, failure)])
    }

    // MARK: Retries

    @Test(arguments: [HTTPResult.networkError, .timeout, .status(500)])
    func networkAndServerFailuresAreRetriedWithAProgressiveWaitUpToACap(result: HTTPResult) async {
        await transport.answer(with: result)
        core.panelOpened()
        await core.queriesFinished()

        let times = await requestTimes(over: 2 * 60 * 60)

        // Seconds after the first query. The 5-minute cadence does not query
        // while a retry is pending.
        #expect(times == [30, 90, 210, 450, 930, 1830, 2730, 3630, 4530, 5430, 6330])
    }

    @Test func aValidReadingResetsTheWait() async {
        await transport.answer(with: .networkError)
        core.panelOpened()
        await core.queriesFinished()
        clock.advance(by: 30)
        await core.queriesFinished()
        clock.advance(by: 60)
        await core.queriesFinished()

        await transport.answer(with: .claudeSample)
        core.refresh()
        await core.queriesFinished()
        await transport.answer(with: .networkError)
        core.refresh()
        await core.queriesFinished()

        #expect(await requestTimes(over: 31) == [30])
    }

    @Test func closingThePanelStopsTheRetries() async {
        await transport.answer(with: .networkError)
        core.panelOpened()
        await core.queriesFinished()

        core.panelClosed()
        clock.advance(by: 60 * 60)
        await core.queriesFinished()

        #expect(await transport.requests.count == 1)
    }

    @Test func wakingFromSleepWaitsForThePendingRetry() async {
        await transport.answer(with: .networkError)
        core.panelOpened()
        await core.queriesFinished()

        clock.advance(by: 10)
        core.systemWoke()
        await core.queriesFinished()

        #expect(await transport.requests.count == 1)
    }

    @Test func actualizarDoesNotWaitForTheRetry() async {
        await transport.answer(with: .networkError)
        core.panelOpened()
        await core.queriesFinished()

        clock.advance(by: 1)
        core.refresh()
        await core.queriesFinished()

        #expect(await transport.requests.count == 2)
    }

    @Test func anIncompatibleResponseIsNotRetriedBeforeTheCadence() async {
        await transport.answer(with: .response(HTTPResponse(status: 200, headers: [:], body: Data("<html></html>".utf8))))
        core.panelOpened()
        await core.queriesFinished()

        #expect(await requestTimes(over: refreshInterval) == [refreshInterval])
    }

    // MARK: Rate limit

    @Test(arguments: ["Retry-After", "retry-after"])
    func tooManyQueriesShowsUntilWhenTheProviderAsksToWait(header: String) async {
        await transport.answer(with: .response(HTTPResponse(status: 429, headers: [header: "120"], body: Data())))

        core.panelOpened()
        await core.queriesFinished()

        #expect(claudeContent() == .failed(.rateLimited(until: Samples.readingMoment.addingTimeInterval(120))))
    }

    @Test func retryAfterAsADateIsRespected() async {
        // 2026-09-23T14:42:00Z, ten minutes after the reading moment.
        await transport.answer(with: .response(HTTPResponse(
            status: 429, headers: ["Retry-After": "Wed, 23 Sep 2026 14:42:00 GMT"], body: Data()
        )))

        core.panelOpened()
        await core.queriesFinished()

        #expect(claudeContent() == .failed(.rateLimited(until: Samples.readingMoment.addingTimeInterval(600))))
    }

    @Test func actualizarAndOpeningThePanelRespectRetryAfter() async {
        await transport.answer(with: .response(HTTPResponse(status: 429, headers: ["Retry-After": "120"], body: Data())))
        core.panelOpened()
        await core.queriesFinished()

        clock.advance(by: 60)
        core.refresh()
        await core.queriesFinished()
        core.panelClosed()
        core.panelOpened()
        await core.queriesFinished()

        #expect(await transport.requests.count == 1)
    }

    @Test func afterRetryAfterTheOpenPanelQueriesOnItsOwn() async {
        await transport.answer(with: .response(HTTPResponse(status: 429, headers: ["Retry-After": "120"], body: Data())))
        core.panelOpened()
        await core.queriesFinished()

        await transport.answer(with: .claudeSample)
        #expect(await requestTimes(over: 120) == [120])
        #expect(claudeContent().map { if case .quotas = $0 { true } else { false } } == true)
    }

    @Test func actualizarQueriesOnceRetryAfterHasPassed() async {
        await transport.answer(with: .response(HTTPResponse(status: 429, headers: ["Retry-After": "120"], body: Data())))
        core.panelOpened()
        await core.queriesFinished()
        core.panelClosed()

        clock.advance(by: 120)
        core.refresh()
        await core.queriesFinished()

        #expect(await transport.requests.count == 2)
    }

    @Test func tooManyQueriesWithoutRetryAfterIsRetriedWithAProgressiveWait() async {
        await transport.answer(with: .status(429))
        core.panelOpened()
        await core.queriesFinished()

        #expect(claudeContent() == .failed(.rateLimited(until: nil)))
        #expect(await requestTimes(over: 100) == [30, 90])
    }

    @Test func tooManyQueriesKeepsThePreviousReadingAsStale() async {
        core.panelOpened()
        await core.queriesFinished()

        await transport.answer(with: .response(HTTPResponse(status: 429, headers: ["Retry-After": "120"], body: Data())))
        core.refresh()
        await core.queriesFinished()

        guard case .stale(_, let failure) = claudeContent() else {
            Issue.record("Expected the stale reading")
            return
        }
        #expect(failure == .rateLimited(until: Samples.readingMoment.addingTimeInterval(120)))
    }

    /// Moves the clock `duration` seconds in 10-second steps and returns when
    /// each new request arrived, in seconds from now.
    func requestTimes(over duration: TimeInterval) async -> [TimeInterval] {
        let start = clock.now()
        var seen = await transport.requests.count
        var times: [TimeInterval] = []
        for _ in 0..<Int((duration / 10).rounded(.up)) {
            let step = min(10, duration - clock.now().timeIntervalSince(start))
            clock.advance(by: step)
            await core.queriesFinished()
            let count = await transport.requests.count
            times += Array(repeating: clock.now().timeIntervalSince(start), count: count - seen)
            seen = count
        }
        return times
    }
}
