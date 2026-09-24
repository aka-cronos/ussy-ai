import Foundation
import Testing
import UssyCore

@MainActor
struct ClaudePanelTests {
    let readingMoment = Samples.readingMoment

    func core(transport: SampleTransport) -> UsageCore {
        UsageCore(
            claudeSessionReader: SampleSessionReader(),
            transport: transport,
            clock: FixedClock(readingMoment)
        )
    }

    @Test func beforeTheFirstReadingTheClaudeCardIsLoading() {
        let core = core(transport: SampleTransport(claudeResponse: Samples.claudeUsageResponse))

        #expect(core.state == PanelState(magnitude: .used, cards: [Card(provider: .claude, content: .loading)]))
    }

    @Test func openingThePanelShowsEachClaudeQuotaSeparately() async {
        let core = core(transport: SampleTransport(claudeResponse: Samples.claudeUsageResponse))

        await core.panelOpened()

        #expect(core.state == PanelState(magnitude: .used, cards: [
            Card(provider: .claude, content: .quotas([
                Quota(
                    period: .fiveHours,
                    value: .percent(35, calculated: false),
                    // 2026-09-23T17:00:00Z
                    reset: .at(Date(timeIntervalSince1970: 1_790_182_800)),
                    readAt: readingMoment
                ),
                Quota(
                    period: .weekly,
                    value: .percent(62, calculated: false),
                    // 2026-09-25T09:00:00Z
                    reset: .at(Date(timeIntervalSince1970: 1_790_326_800)),
                    readAt: readingMoment
                ),
            ])),
        ]))
    }

    @Test func queriesClaudeUsageWithOnlyTheAccessToken() async {
        let transport = SampleTransport(claudeResponse: Samples.claudeUsageResponse)
        let core = core(transport: transport)

        await core.panelOpened()

        let requests = await transport.requests
        #expect(requests.count == 1)
        #expect(requests.first?.httpMethod == "GET")
        #expect(requests.first?.url == URL(string: "https://api.anthropic.com/api/oauth/usage"))
        #expect(requests.first?.allHTTPHeaderFields == ["Authorization": "Bearer sample-token"])
    }
}
