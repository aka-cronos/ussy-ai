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
