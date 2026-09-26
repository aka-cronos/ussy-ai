import Foundation
import Testing
import UzzyCore

/// Claude's usage-credit limit («Créditos de uso»): the share of the monthly
/// spend cap on usage credits used, read from `extra_usage`. It is not a
/// subscription quota, and it never shows amounts or a reset.
@MainActor
struct UsageCreditsTests {
    let readingMoment = Samples.readingMoment
    let subscriptionQuotas = [
        Quota(
            period: .fiveHours,
            value: .percent(35, calculated: false),
            // 2026-09-23T17:00:00Z
            reset: .at(Date(timeIntervalSince1970: 1_790_182_800)),
            readAt: Samples.readingMoment
        ),
        Quota(
            period: .weekly,
            value: .percent(62, calculated: false),
            // 2026-09-25T09:00:00Z
            reset: .at(Date(timeIntervalSince1970: 1_790_326_800)),
            readAt: Samples.readingMoment
        ),
    ]

    /// The 5-hour and weekly windows of the sample, with `extraUsage` as the
    /// raw JSON of `extra_usage`, or without the key when it is nil.
    static func response(extraUsage: String?) -> String {
        """
        {
          "five_hour": {"utilization": 35.0, "resets_at": "2026-09-23T17:00:00.000000+00:00"},
          "seven_day": {"utilization": 62.0, "resets_at": "2026-09-25T09:00:00.000000+00:00"}\
        \(extraUsage.map { ",\n  \"extra_usage\": \($0)" } ?? "")
        }
        """
    }

    func openedPanel(claudeResponse: String, magnitude: QuotaMagnitude = .used) async -> UsageCore {
        let core = UsageCore(
            claudeSessionReader: SampleSessionReader(),
            codexSessionReader: NoSessionReader(),
            cursorSessionReader: NoSessionReader(),
            transport: SampleTransport(claudeResponse: Data(claudeResponse.utf8)),
            clock: FixedClock(readingMoment),
            initialMagnitude: magnitude
        )
        core.panelOpened()
        await core.queriesFinished()
        return core
    }

    func claudeQuotas(_ core: UsageCore) -> [Quota]? {
        guard case .quotas(let quotas) = core.state.cards.first(where: { $0.provider == .claude })?.content else {
            return nil
        }
        return quotas
    }

    /// The usage-credits row of the Claude card, or nil when there is none.
    func usageCredits(extraUsage: String?, magnitude: QuotaMagnitude = .used) async -> Quota? {
        let core = await openedPanel(claudeResponse: Self.response(extraUsage: extraUsage), magnitude: magnitude)
        return claudeQuotas(core)?.first { $0.period == .usageCredits }
    }

    /// A panel whose first Claude reading has a 24 % usage-credits row, with
    /// a transport and a clock the test drives afterwards.
    func panelWithAUsageCreditsRow() async -> (UsageCore, ControlledTransport, ManualClock) {
        let clock = ManualClock(readingMoment)
        let transport = ControlledTransport()
        let core = UsageCore(
            claudeSessionReader: SampleSessionReader(),
            codexSessionReader: NoSessionReader(),
            cursorSessionReader: NoSessionReader(),
            transport: transport,
            clock: clock
        )
        await transport.answer(with: .json(Self.response(extraUsage: #"{"is_enabled": true, "monthly_limit": 5000, "utilization": 24.0}"#)), for: .claude)
        core.panelOpened()
        await core.queriesFinished()
        return (core, transport, clock)
    }

    func row(_ value: QuotaValue) -> Quota {
        Quota(period: .usageCredits, value: value, reset: .unknown, readAt: readingMoment)
    }

    @Test func theSampleResponseWithUsageCreditsDisabledShowsNoRow() async {
        let core = await openedPanel(claudeResponse: String(decoding: Samples.claudeUsageResponse, as: UTF8.self))

        #expect(claudeQuotas(core) == subscriptionQuotas)
    }

    @Test(arguments: [
        nil,
        "null",
        #""enabled""#,
        "[]",
        #"{"monthly_limit": 5000, "used_credits": 1200, "utilization": 24.0}"#,
        #"{"is_enabled": null, "monthly_limit": 5000, "used_credits": 1200, "utilization": 24.0}"#,
        #"{"is_enabled": false, "monthly_limit": 5000, "used_credits": 1200, "utilization": 24.0}"#,
        #"{"is_enabled": 1, "monthly_limit": 5000, "used_credits": 1200, "utilization": 24.0}"#,
        #"{"is_enabled": "true", "monthly_limit": 5000, "used_credits": 1200, "utilization": 24.0}"#,
    ])
    func withoutEnabledUsageCreditsThereIsNoRow(extraUsage: String?) async {
        #expect(await usageCredits(extraUsage: extraUsage) == nil)
    }

    @Test(arguments: [
        #"{"is_enabled": true, "used_credits": 1200, "utilization": 24.0}"#,
        #"{"is_enabled": true, "monthly_limit": null, "used_credits": 2146, "utilization": null}"#,
        #"{"is_enabled": true, "monthly_limit": 0, "used_credits": 0, "utilization": 0}"#,
        #"{"is_enabled": true, "monthly_limit": -5000, "used_credits": 1200, "utilization": 24.0}"#,
        #"{"is_enabled": true, "monthly_limit": "5000", "used_credits": 1200, "utilization": 24.0}"#,
        #"{"is_enabled": true, "monthly_limit": 1e400, "used_credits": 1200, "utilization": 24.0}"#,
    ])
    func anUncappedOrUnusableLimitShowsNoRow(extraUsage: String) async {
        #expect(await usageCredits(extraUsage: extraUsage) == nil)
    }

    @Test(arguments: [
        #"{"is_enabled": true, "monthly_limit": 5000}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": null, "utilization": null}"#,
    ])
    func aLimitWithoutAnyFigureShowsNoRow(extraUsage: String) async {
        #expect(await usageCredits(extraUsage: extraUsage) == nil)
    }

    @Test(arguments: [
        #""enabled""#,
        #"{"is_enabled": "true", "monthly_limit": 5000, "utilization": 24.0}"#,
        #"{"is_enabled": true, "monthly_limit": 1e400, "used_credits": 1200}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": [1200], "utilization": "24"}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 1e400, "utilization": 1e400}"#,
    ])
    func malformedUsageCreditsNeverChangeTheSubscriptionQuotas(extraUsage: String) async {
        let core = await openedPanel(claudeResponse: Self.response(extraUsage: extraUsage))

        #expect(claudeQuotas(core)?.prefix(2) == subscriptionQuotas[...])
    }

    @Test func nothingSpentYetIsCalculatedAsZero() async {
        let quota = await usageCredits(extraUsage: #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 0, "utilization": null}"#)

        #expect(quota == row(.percent(0, calculated: true)))
    }

    @Test func aReportedFigureAloneIsShownAsReported() async {
        let quota = await usageCredits(extraUsage: #"{"is_enabled": true, "monthly_limit": 5000, "utilization": 24.0}"#)

        #expect(quota == row(.percent(24, calculated: false)))
    }

    @Test(arguments: [
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 1200, "utilization": 24.0, "currency": "USD"}"#,
        // 1245 / 5000 is 24.9 %, within a point of the reported 24 %.
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 1245, "utilization": 24.0, "currency": 7}"#,
    ])
    func reportedAndCalculatedFiguresThatAgreeShowTheReportedOne(extraUsage: String) async {
        #expect(await usageCredits(extraUsage: extraUsage) == row(.percent(24, calculated: false)))
    }

    @Test(arguments: [
        // 60 against 100 × 1200 / 5000 = 24.
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 1200, "utilization": 60.0}"#,
        // 1255 / 5000 is 25.1 %, just over a point from the reported 24 %.
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 1255, "utilization": 24.0}"#,
    ])
    func reportedAndCalculatedFiguresThatDisagreeAreUninterpretable(extraUsage: String) async {
        #expect(await usageCredits(extraUsage: extraUsage) == row(.uninterpretable))
    }

    @Test(arguments: [
        // Over the limit, reported and calculated: never clamped to 100.
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 5600, "utilization": 112.0}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "utilization": 100.5}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 5600}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": -50, "utilization": null}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "utilization": -1}"#,
        // A ratio too large to represent.
        #"{"is_enabled": true, "monthly_limit": 1e-300, "used_credits": 1e300}"#,
    ])
    func aFigureOutsideZeroToHundredIsUninterpretable(extraUsage: String) async {
        #expect(await usageCredits(extraUsage: extraUsage) == row(.uninterpretable))
    }

    @Test(arguments: [
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 1200, "utilization": "24"}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "utilization": true}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "utilization": [24]}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "utilization": {"value": 24}}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "utilization": 1e400}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": "1200", "utilization": 24.0}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": false}"#,
        #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 1e400, "utilization": 24.0}"#,
    ])
    func aFigureThatIsNotAUsableNumberIsUninterpretable(extraUsage: String) async {
        #expect(await usageCredits(extraUsage: extraUsage) == row(.uninterpretable))
    }

    @Test func theRemainingShareIsCalculatedFromTheUsedOne() async {
        let extraUsage = #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 1200, "utilization": 24.0}"#

        #expect(await usageCredits(extraUsage: extraUsage, magnitude: .remaining) == row(.percent(76, calculated: true)))
    }

    @Test func aCalculatedFigureStaysCalculatedAsTheRemainingShare() async {
        let extraUsage = #"{"is_enabled": true, "monthly_limit": 5000, "used_credits": 0, "utilization": null}"#

        #expect(await usageCredits(extraUsage: extraUsage, magnitude: .remaining) == row(.percent(100, calculated: true)))
    }

    @Test func theRowFollowsThePerModelLimits() async {
        let core = await openedPanel(claudeResponse: """
        {
          "five_hour": {"utilization": 35.0, "resets_at": "2026-09-23T17:00:00.000000+00:00"},
          "seven_day": {"utilization": 62.0, "resets_at": "2026-09-25T09:00:00.000000+00:00"},
          "extra_usage": {"is_enabled": true, "monthly_limit": 5000, "used_credits": 1200, "utilization": 24.0},
          "limits": [
            {"kind": "weekly_scoped", "percent": 20.0, "resets_at": "2026-09-25T09:00:00.000000+00:00",
             "scope": {"model": {"display_name": "Fable"}}}
          ]
        }
        """)

        #expect(claudeQuotas(core)?.map(\.period) == [.fiveHours, .weekly, .limit("Fable", .weekly), .usageCredits])
    }

    @Test func aReadingWithoutTheRowRemovesIt() async {
        let (core, transport, clock) = await panelWithAUsageCreditsRow()
        #expect(claudeQuotas(core)?.last?.period == .usageCredits)

        await transport.answer(with: .json(Self.response(extraUsage: #"{"is_enabled": false}"#)), for: .claude)
        clock.advance(by: 5 * 60)
        await core.queriesFinished()

        #expect(claudeQuotas(core)?.map(\.period) == [.fiveHours, .weekly])
    }

    @Test func aFailedRefreshKeepsTheRowStaleWithItsReadingTime() async {
        let (core, transport, clock) = await panelWithAUsageCreditsRow()

        await transport.answer(with: .networkError, for: .claude)
        clock.advance(by: 5 * 60)
        await core.queriesFinished()

        guard case .stale(let quotas, failure: .offline) = core.state.cards.first(where: { $0.provider == .claude })?.content else {
            Issue.record("Expected the stale reading")
            return
        }
        #expect(quotas.last == Quota(
            period: .usageCredits, value: .percent(24, calculated: false), reset: .unknown, readAt: readingMoment, isStale: true
        ))
    }
}
