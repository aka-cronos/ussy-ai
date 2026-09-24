import Foundation
import Observation

/// Refresh coordinator and in-memory panel state.
/// It is the only test seam: its external dependencies are injected.
@MainActor
@Observable
public final class UsageCore {
    /// Depends on the clock too: a reset that passes changes the state.
    public var state: PanelState {
        let now = clock.now()
        return PanelState(
            magnitude: magnitude,
            cards: providers.filter(\.isEnabled).map { Card(provider: $0.provider, content: $0.content(in: magnitude, at: now)) },
            isQuerying: providers.contains { $0.isEnabled && $0.isQuerying }
        )
    }

    public var enabledProviders: Set<Provider> {
        Set(providers.filter(\.isEnabled).map(\.provider))
    }

    /// How often providers are queried while the panel is open. Opening the
    /// panel does not query a provider whose reading is younger than this.
    nonisolated static let refreshInterval: TimeInterval = 5 * 60

    private var magnitude: QuotaMagnitude
    /// One per card, in the panel's order. Each is queried on its own.
    private let providers: [ProviderRefresh]
    /// Identifies the only scheduled query that may still run. `nil` while
    /// the panel is closed.
    @ObservationIgnored private var cadence: UUID?

    private let clock: any WallClock

    public init(
        claudeSessionReader: any SessionReader,
        codexSessionReader: any SessionReader,
        cursorSessionReader: any SessionReader,
        transport: any HTTPTransport,
        clock: any WallClock,
        log: any EventLog = SystemLog(),
        initialMagnitude: QuotaMagnitude = .used,
        initialEnabledProviders: Set<Provider> = Set(Provider.allCases)
    ) {
        self.clock = clock
        magnitude = initialMagnitude
        providers = [
            ProviderRefresh(Claude.self, sessionReader: claudeSessionReader, transport: transport, clock: clock, log: log,
                            isEnabled: initialEnabledProviders.contains(.claude)),
            ProviderRefresh(Codex.self, sessionReader: codexSessionReader, transport: transport, clock: clock, log: log,
                            isEnabled: initialEnabledProviders.contains(.codex)),
            ProviderRefresh(Cursor.self, sessionReader: cursorSessionReader, transport: transport, clock: clock, log: log,
                            isEnabled: initialEnabledProviders.contains(.cursor)),
        ]
    }

    public func now() -> Date {
        clock.now()
    }

    /// Expresses every quota as used or remaining quota.
    public func show(_ magnitude: QuotaMagnitude) {
        self.magnitude = magnitude
    }

    /// A disabled provider has neither a card nor session or network work.
    public func setEnabled(_ enabled: Bool, for provider: Provider) {
        providers.first(where: { $0.provider == provider })?.setEnabled(enabled)
    }

    /// Reads the sessions again, which may show the Keychain prompt: opening
    /// the panel is a user action.
    public func panelOpened() {
        scheduleNextQuery()
        providers.forEach { $0.panelOpened() }
    }

    /// The Actualizar button: reads the sessions and queries even when the
    /// readings are fresh or the sessions were rejected.
    public func refresh() {
        providers.forEach { $0.refresh() }
    }

    /// Queries on waking from sleep while the panel is open, and restarts the
    /// cadence from then.
    public func systemWoke() {
        guard cadence != nil else { return }
        providers.forEach { $0.queryOnItsOwn() }
        scheduleNextQuery()
    }

    /// Stops scheduling queries. A query in flight still finishes.
    public func panelClosed() {
        cadence = nil
        providers.forEach { $0.panelClosed() }
    }

    /// Returns once no query of `provider`, or of any provider, is in flight.
    public func queriesFinished(of provider: Provider? = nil) async {
        for refresh in providers where provider == nil || refresh.provider == provider {
            await refresh.queryFinished()
        }
    }

    /// Replaces any query scheduled before.
    private func scheduleNextQuery() {
        let cadence = UUID()
        self.cadence = cadence
        clock.schedule(at: clock.now().addingTimeInterval(Self.refreshInterval)) { [weak self] in
            guard let self, self.cadence == cadence else { return }
            providers.forEach { $0.queryOnItsOwn() }
            scheduleNextQuery()
        }
    }
}
