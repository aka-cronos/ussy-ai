import Foundation
import Testing
import UzzyCore

/// The Codex card, end to end: the ChatGPT session of Codex CLI, its usage
/// query and its quotas, named by the length of their window.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CodexPanelTests {
    let clock = ManualClock(Samples.readingMoment)
    let claudeSessionReader = ControlledSessionReader()
    let codexSessionReader = ControlledSessionReader()
    let transport = ControlledTransport()
    let core: UsageCore
    // 2026-09-23T18:00:00Z and 2026-09-28T06:00:00Z, from the sample response.
    let fiveHourReset = Date(timeIntervalSince1970: 1_790_186_400)
    let weeklyReset = Date(timeIntervalSince1970: 1_790_575_200)

    init() {
        core = UsageCore(
            claudeSessionReader: claudeSessionReader,
            codexSessionReader: codexSessionReader,
            transport: transport,
            clock: clock,
            log: RecordingLog()
        )
    }

    func codexContent() -> CardContent? {
        core.state.cards.first(where: { $0.provider == .codex })?.content
    }

    func openPanel() async {
        core.panelOpened()
        await core.queriesFinished()
    }

    @Test func thePanelShowsTheClaudeCardAndThenTheCodexCard() {
        #expect(core.state.cards == [
            Card(provider: .claude, content: .loading),
            Card(provider: .codex, content: .loading),
        ])
    }

    @Test func openingThePanelShowsEachCodexQuotaSeparately() async {
        await openPanel()

        #expect(codexContent() == .quotas([
            Quota(period: .fiveHours, value: .percent(12, calculated: false), reset: .at(fiveHourReset), readAt: Samples.readingMoment),
            Quota(period: .weekly, value: .percent(41, calculated: false), reset: .at(weeklyReset), readAt: Samples.readingMoment),
        ]))
    }

    /// The provider may send its windows in any order, so position says nothing.
    @Test func windowsAreNamedByTheirLengthNotByTheirPosition() async {
        await transport.answer(with: .codex(rateLimit: """
            {
              "primary_window": {"used_percent": 41, "limit_window_seconds": 604800, "reset_at": 1790575200},
              "secondary_window": {"used_percent": 12, "limit_window_seconds": 18000, "reset_at": 1790186400}
            }
            """), for: .codex)

        await openPanel()

        #expect(codexContent() == .quotas([
            Quota(period: .fiveHours, value: .percent(12, calculated: false), reset: .at(fiveHourReset), readAt: Samples.readingMoment),
            Quota(period: .weekly, value: .percent(41, calculated: false), reset: .at(weeklyReset), readAt: Samples.readingMoment),
        ]))
    }

    @Test(arguments: [3_600, 86_400, 2_592_000])
    func aWindowOfAnotherLengthIsNamedByThatLength(seconds: Int) async {
        await transport.answer(with: .codex(rateLimit: """
            {"primary_window": {"used_percent": 7.5, "limit_window_seconds": \(seconds), "reset_at": 1790186400}}
            """), for: .codex)

        await openPanel()

        #expect(codexContent() == .quotas([
            Quota(period: .lasting(seconds: seconds),value: .percent(7.5, calculated: false), reset: .at(fiveHourReset), readAt: Samples.readingMoment),
        ]))
    }

    @Test func additionalLimitsAreShownAsSeparateQuotasNamedByTheProvider() async {
        await transport.answer(with: .codex(
            rateLimit: """
                {"primary_window": {"used_percent": 12, "limit_window_seconds": 18000, "reset_at": 1790186400}}
                """,
            additional: """
                [{
                  "limit_name": "Sample-Model",
                  "metered_feature": "sample_feature",
                  "rate_limit": {
                    "allowed": true,
                    "limit_reached": false,
                    "primary_window": {"used_percent": 3, "limit_window_seconds": 18000, "reset_at": 1790186400},
                    "secondary_window": {"used_percent": 9, "limit_window_seconds": 604800, "reset_at": 1790575200}
                  }
                }]
                """
        ), for: .codex)

        await openPanel()

        #expect(codexContent() == .quotas([
            Quota(period: .fiveHours, value: .percent(12, calculated: false), reset: .at(fiveHourReset), readAt: Samples.readingMoment),
            Quota(period: .limit("Sample-Model", .fiveHours), value: .percent(3, calculated: false), reset: .at(fiveHourReset), readAt: Samples.readingMoment),
            Quota(period: .limit("Sample-Model", .weekly), value: .percent(9, calculated: false), reset: .at(weeklyReset), readAt: Samples.readingMoment),
        ]))
    }

    @Test func aWindowWithoutUsageOrResetShowsWhatIsMissingWithoutInventingIt() async {
        await transport.answer(with: .codex(rateLimit: """
            {
              "primary_window": {"used_percent": null, "limit_window_seconds": 18000, "reset_at": 1790186400},
              "secondary_window": {"used_percent": 41, "limit_window_seconds": 604800, "reset_at": null}
            }
            """), for: .codex)

        await openPanel()

        #expect(codexContent() == .quotas([
            Quota(period: .fiveHours, value: .unavailable, reset: .at(fiveHourReset), readAt: Samples.readingMoment),
            Quota(period: .weekly, value: .percent(41, calculated: false), reset: .unknown, readAt: Samples.readingMoment),
        ]))
    }

    @Test func aPercentOutOfRangeIsUninterpretable() async {
        await transport.answer(with: .codex(rateLimit: """
            {"primary_window": {"used_percent": 104, "limit_window_seconds": 18000, "reset_at": 1790186400}}
            """), for: .codex)

        await openPanel()

        #expect(codexContent() == .quotas([
            Quota(period: .fiveHours, value: .uninterpretable, reset: .at(fiveHourReset), readAt: Samples.readingMoment),
        ]))
    }

    /// Without its length a window cannot be named, and it is never named by
    /// its position.
    @Test(arguments: [
        #"{"primary_window": {"used_percent": 12, "reset_at": 1790186400}}"#,
        #"{"primary_window": null, "secondary_window": null}"#,
        "null",
    ])
    func aResponseWithoutNamedWindowsIsIncompatible(rateLimit: String) async {
        await transport.answer(with: .codex(rateLimit: rateLimit), for: .codex)

        await openPanel()

        #expect(codexContent() == .failed(.incompatibleResponse))
    }

    /// E.g. Codex CLI signed in with an API key.
    @Test func aSessionWithoutSubscriptionQuotasSaysSoAndIsNotQueried() async {
        await codexSessionReader.answer(with: .withoutSubscriptionQuotas)

        await openPanel()
        clock.advance(by: 5 * 60)
        await core.queriesFinished()

        #expect(codexContent() == .failed(.sessionWithoutSubscriptionQuotas))
        #expect(await transport.requests(to: .codex).isEmpty)
    }

    @Test func anotherCodexAccountClearsThePreviousReadingAndIsQueriedWithItsOwnAccount() async {
        await openPanel()

        await codexSessionReader.answer(with: .session(Session(accessToken: "other-token", accountID: "other-account")))
        await transport.hold(.codex)
        core.refresh()
        await transport.waitForRequests(4)

        #expect(codexContent() == .loadingNewAccount)
        let request = await transport.requests(to: .codex).last
        #expect(request?.value(forHTTPHeaderField: "ChatGPT-Account-Id") == "other-account")
        await transport.release()
        await core.queriesFinished()
    }

    @Test func queriesCodexUsageWithTheAccessTokenAndTheAccount() async {
        await openPanel()

        let requests = await transport.requests.filter { $0.url?.host == "chatgpt.com" }
        #expect(requests.count == 1)
        #expect(requests.first?.httpMethod == "GET")
        #expect(requests.first?.url == URL(string: "https://chatgpt.com/backend-api/wham/usage"))
        #expect(requests.first?.allHTTPHeaderFields == [
            "Authorization": "Bearer sample-token",
            "ChatGPT-Account-Id": "sample-account",
        ])
    }
}
