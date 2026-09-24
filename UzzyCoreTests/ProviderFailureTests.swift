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
}
