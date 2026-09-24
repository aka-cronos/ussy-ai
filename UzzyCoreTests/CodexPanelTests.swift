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
