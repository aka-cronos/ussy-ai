import AppKit
import SwiftUI
import UssyCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var eventMonitors: [Any] = []
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
        // The app closes the panel itself: `.transient` misses clicks in other
        // apps for an accessory app, and races with the icon's own toggle.
        popover.behavior = .applicationDefined
        popover.delegate = self

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "UssyAi")
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item
    }

    @objc private func togglePanel() {
        if popover.isShown {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func openPanel() {
        guard let button = statusItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
        watchForDismissal()
        Task { await core.panelOpened() }
    }

    /// Closes the panel like a macOS menu: on Escape or on a click in another app.
    private func watchForDismissal() {
        let escapeKeyCode: UInt16 = 53
        if let escape = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == escapeKeyCode else { return event }
            self?.closePanel()
            return nil
        }) {
            eventMonitors.append(escape)
        }
        // Clicks on the status item also arrive as global events; the icon
        // toggles the panel itself, so they are left to `togglePanel`.
        if let outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            guard let self, !isOnStatusItem(NSEvent.mouseLocation) else { return }
            closePanel()
        }) {
            eventMonitors.append(outsideClick)
        }
    }

    private func isOnStatusItem(_ screenPoint: NSPoint) -> Bool {
        guard let button = statusItem?.button, let window = button.window else { return false }
        return window.convertToScreen(button.convert(button.bounds, to: nil)).contains(screenPoint)
    }

    /// Closes instantly, like a menu. While a close animation runs the popover
    /// still reports `isShown`, so a quick click on the icon would be lost.
    private func closePanel() {
        popover.animates = false
        popover.performClose(nil)
        popover.animates = true
    }

    func popoverDidClose(_ notification: Notification) {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors.removeAll()
    }
}
