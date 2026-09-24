import Foundation
import Observation

/// Refresh coordinator and in-memory panel state.
/// It is the only test seam: its external dependencies are injected.
@MainActor
@Observable
public final class UsageCore {
    public private(set) var state = PanelState(cards: [Card(provider: .claude, content: .loading)])

    private let claudeSessionReader: any SessionReader
    private let transport: any HTTPTransport
    private let clock: any WallClock

    public init(claudeSessionReader: any SessionReader, transport: any HTTPTransport, clock: any WallClock) {
        self.claudeSessionReader = claudeSessionReader
        self.transport = transport
        self.clock = clock
    }

    public func now() -> Date {
        clock.now()
    }

    public func panelOpened() async {
        await refreshClaude()
    }

    private func refreshClaude() async {
        guard case .session(let session) = await claudeSessionReader.read(),
              case .response(let response) = await transport.send(Claude.request(accessToken: session.accessToken)),
              response.status == 200,
              let quotas = Claude.quotas(from: response.body, readAt: clock.now())
        else {
            show(.queryFailed, on: .claude)
            return
        }
        show(.quotas(quotas), on: .claude)
    }

    private func show(_ content: CardContent, on provider: Provider) {
        guard let index = state.cards.firstIndex(where: { $0.provider == provider }) else { return }
        state.cards[index].content = content
    }
}
