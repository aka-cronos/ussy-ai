import AppKit
import SwiftUI
import UssyCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let core = UsageCore(
        claudeSessionReader: SampleSessionReader(),
        transport: SampleTransport(claudeResponse: Samples.claudeUsageResponse),
        clock: FixedClock(Samples.readingMoment)
    )

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let content = NSHostingController(rootView: PanelView(core: core))
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        // Transient: a click outside or Escape closes it, like a macOS menu.
        popover.behavior = .transient

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "UssyAi")
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item
    }

    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
        Task { await core.panelOpened() }
    }
}
