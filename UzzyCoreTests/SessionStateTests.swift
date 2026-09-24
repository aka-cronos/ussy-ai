import Foundation
import Testing
import UzzyCore

/// What the card shows when the provider's session is of no use, and how the
/// panel avoids retrying or prompting for it on its own.
@MainActor
struct SessionStateTests {
    let clock = ManualClock(Samples.readingMoment)
    let sessionReader = ControlledSessionReader()
    let transport = ControlledTransport()
    let core: UsageCore

    init() {
        core = UsageCore(claudeSessionReader: sessionReader, transport: transport, clock: clock)
    }

    func claudeContent() -> CardContent? {
        core.state.cards.first(where: { $0.provider == .claude })?.content
    }

    @Test func withoutASessionTheCardSaysSoAndNothingIsQueried() async {
        await sessionReader.answer(with: .noSession)

        core.panelOpened()
        await core.queriesFinished()

        #expect(claudeContent() == .failed(.noSession))
        #expect(await transport.requests.isEmpty)
    }

    @Test func aSessionTheProviderRejectsIsExpired() async {
        await transport.answer(with: Self.status(401))

        core.panelOpened()
        await core.queriesFinished()

        #expect(claudeContent() == .failed(.sessionExpired))
    }

    @Test func aForbiddenQueryIsRefusedAccessAndNotAnExpiredSession() async {
        await transport.answer(with: Self.status(403))

        core.panelOpened()
        await core.queriesFinished()

        #expect(claudeContent() == .failed(.accessRefused))
    }

    @Test func deniedAccessToTheSessionIsShownAndNothingIsQueried() async {
        await sessionReader.answer(with: .accessDenied)

        core.panelOpened()
        await core.queriesFinished()

        #expect(claudeContent() == .failed(.sessionAccessDenied))
        #expect(await transport.requests.isEmpty)
    }

    @Test func aSessionInAnUnknownFormatIsIncompatibleAndNothingIsQueried() async {
        await sessionReader.answer(with: .unknownFormat)

        core.panelOpened()
        await core.queriesFinished()

        // The state carries no credential to show.
        #expect(claudeContent() == .failed(.incompatibleSession))
        #expect(await transport.requests.isEmpty)
    }

    static func status(_ status: Int) -> HTTPResult {
        .response(HTTPResponse(status: status, headers: [:], body: Data()))
    }
}
