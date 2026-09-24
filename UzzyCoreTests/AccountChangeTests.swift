import Foundation
import Testing
import UzzyCore

/// Quotas of one account are never shown as another's: a change of account
/// or an identity that cannot be verified hides the previous figures.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AccountChangeTests {
    let clock = ManualClock(Samples.readingMoment)
    let sessionReader = ControlledSessionReader()
    let transport = ControlledTransport()
    let core: UsageCore
    let refreshInterval: TimeInterval = 5 * 60
    let otherAccount = Session(accessToken: "other-token", accountID: "other-account")

    init() {
        core = UsageCore(claudeSessionReader: sessionReader, transport: transport, clock: clock, log: RecordingLog())
    }

    func claudeContent() -> CardContent? {
        core.state.cards.first(where: { $0.provider == .claude })?.content
    }

    @Test func anotherAccountClearsThePreviousReadingAtOnceWhileItsQuotasAreQueried() async {
        core.panelOpened()
        await core.queriesFinished()

        await sessionReader.answer(with: .session(otherAccount))
        await transport.hold()
        core.refresh()
        await transport.waitForRequests(2)

        #expect(claudeContent() == .loadingNewAccount)
        await transport.release()
        await core.queriesFinished()
    }

    @Test func anUnverifiableIdentityHidesThePreviousReadingAtOnce() async {
        core.panelOpened()
        await core.queriesFinished()

        await sessionReader.answer(with: .session(Session(accessToken: "sample-token", accountID: nil)))
        await transport.hold()
        core.refresh()
        await transport.waitForRequests(2)

        #expect(claudeContent() == .loading)
        await transport.release()
        await core.queriesFinished()
    }

    /// The reading is younger than the cadence, so opening the panel does not
    /// query for it; it still checks whose session it is.
    @Test func reopeningThePanelWithAnotherAccountClearsEvenAFreshReading() async {
        core.panelOpened()
        await core.queriesFinished()
        core.panelClosed()

        await sessionReader.answer(with: .session(otherAccount))
        await transport.hold()
        clock.advance(by: 60)
        core.panelOpened()
        await transport.waitForRequests(2)

        #expect(claudeContent() == .loadingNewAccount)
        #expect(await transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer other-token")
        await transport.release()
        await core.queriesFinished()
    }

    @Test func reopeningThePanelWithTheSameAccountAndAFreshReadingDoesNotQuery() async {
        core.panelOpened()
        await core.queriesFinished()
        core.panelClosed()

        await sessionReader.answer(with: .session(Session(accessToken: "renewed-token", accountID: "sample-account")))
        clock.advance(by: 60)
        core.panelOpened()
        await core.queriesFinished()

        #expect(await sessionReader.reads == 2)
        #expect(await transport.requests.count == 1)
        #expect(claudeReadAt() == Samples.readingMoment)
    }

    @Test func theCadenceQueriesWithTheSessionReadWhenThePanelWasReopened() async {
        core.panelOpened()
        await core.queriesFinished()
        core.panelClosed()

        await sessionReader.answer(with: .session(Session(accessToken: "renewed-token", accountID: "sample-account")))
        clock.advance(by: 60)
        core.panelOpened()
        await core.queriesFinished()
        clock.advance(by: refreshInterval)
        await core.queriesFinished()

        #expect(await transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer renewed-token")
    }

    /// With the same session there is nothing new to verify, even when its
    /// identity is unknown, so a fresh reading is not queried again.
    @Test func reopeningThePanelWithTheSameUnverifiableSessionDoesNotQuery() async {
        await sessionReader.answer(with: .session(Session(accessToken: "sample-token", accountID: nil)))
        core.panelOpened()
        await core.queriesFinished()
        core.panelClosed()

        clock.advance(by: 60)
        core.panelOpened()
        await core.queriesFinished()

        #expect(await transport.requests.count == 1)
        #expect(claudeReadAt() == Samples.readingMoment)
    }

    @Test func reopeningThePanelWithAnotherUnverifiableSessionHidesAFreshReading() async {
        await sessionReader.answer(with: .session(Session(accessToken: "sample-token", accountID: nil)))
        core.panelOpened()
        await core.queriesFinished()
        core.panelClosed()

        await sessionReader.answer(with: .session(Session(accessToken: "other-token", accountID: nil)))
        await transport.answer(with: .networkError)
        clock.advance(by: 60)
        core.panelOpened()
        await core.queriesFinished()

        #expect(claudeContent() == .failed(.offline))
    }

    @Test func theSameAccountWithARenewedSessionKeepsItsReadingAfterAFailure() async {
        core.panelOpened()
        await core.queriesFinished()

        await sessionReader.answer(with: .session(Session(accessToken: "renewed-token", accountID: "sample-account")))
        await transport.answer(with: .networkError)
        core.refresh()
        await core.queriesFinished()

        guard case .stale(let quotas, failure: .offline) = claudeContent() else {
            Issue.record("Expected the stale reading")
            return
        }
        #expect(quotas.allSatisfy { $0.isStale && $0.readAt == Samples.readingMoment })
    }

    @Test func theNewAccountsQuotasReplaceThePreviousOnes() async {
        core.panelOpened()
        await core.queriesFinished()

        await sessionReader.answer(with: .session(otherAccount))
        clock.advance(by: 60)
        core.refresh()
        await core.queriesFinished()

        #expect(claudeReadAt() == clock.now())
    }

    /// The app never falls back on the previous account's session: queries
    /// no user action asked for use only the session read last.
    @Test func afterAChangeOfAccountThePreviousSessionIsNeverUsed() async {
        core.panelOpened()
        await core.queriesFinished()

        await sessionReader.answer(with: .session(otherAccount))
        core.refresh()
        await core.queriesFinished()
        clock.advance(by: refreshInterval)
        await core.queriesFinished()
        core.systemWoke()
        await core.queriesFinished()

        let tokens = await transport.requests.dropFirst().map { $0.value(forHTTPHeaderField: "Authorization") }
        #expect(tokens == Array(repeating: "Bearer other-token", count: 3))
    }

    @Test func withoutASessionThePreviousOneIsNeverUsed() async {
        core.panelOpened()
        await core.queriesFinished()

        await sessionReader.answer(with: .noSession)
        core.refresh()
        await core.queriesFinished()
        clock.advance(by: refreshInterval)
        await core.queriesFinished()
        core.systemWoke()
        await core.queriesFinished()

        #expect(await transport.requests.count == 1)
        #expect(claudeContent() == .failed(.noSession))
    }

    func claudeReadAt() -> Date? {
        guard case .quotas(let quotas) = claudeContent() else { return nil }
        return quotas.first?.readAt
    }
}
