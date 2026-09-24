import AppKit
import SwiftUI
import UzzyCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var eventMonitors: [Any] = []
    private let realCore = UsageCore(
        claudeSessionReader: ClaudeCodeSessionReader(),
        codexSessionReader: CodexCLISessionReader(),
        cursorSessionReader: CursorSessionReader(),
        transport: URLSessionTransport(),
        clock: SystemClock(),
        initialMagnitude: QuotaMagnitude(
            rawValue: UserDefaults.standard.string(forKey: "displayMagnitude") ?? ""
        ) ?? .used
    )
    private var settingsWindow: NSWindow?
    #if DEBUG
    private lazy var scenarios = ScenarioSwitch(realCore: realCore)
    #endif

    /// The core the panel shows.
    private var core: UsageCore {
        #if DEBUG
        scenarios.core
        #else
        realCore
        #endif
    }

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        let content = NSHostingController(rootView: ScenarioPanel(scenarios: scenarios, openSettings: { [weak self] in
            self?.showSettings()
        }) { [weak self] scenario in
            guard let self else { return }
            Task { await self.scenarios.show(scenario, panelIsOpen: self.popover.isShown) }
        })
        #else
        let content = NSHostingController(rootView: PanelView(core: realCore, openSettings: { [weak self] in
            self?.showSettings()
        }))
        #endif
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        // The app closes the panel itself: `.transient` misses clicks in other
        // apps for an accessory app, and races with the icon's own toggle.
        popover.behavior = .applicationDefined
        popover.delegate = self

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: Format.appName)
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil
        )

        #if DEBUG
        // `-scenario <id>` opens the panel on that scenario, e.g. `-scenario stale`.
        // The icon waits for it, so the real accounts are never read.
        if let id = UserDefaults.standard.string(forKey: "scenario"),
           let scenario = Scenario.all.first(where: { $0.id == id }) {
            item.button?.isEnabled = false
            Task {
                await scenarios.show(scenario, panelIsOpen: false)
                item.button?.isEnabled = true
                if !popover.isShown {
                    openPanel()
                }
            }
        }
        #endif
    }

    @objc private func systemDidWake() {
        core.systemWoke()
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
        watchWhileOpen()
        core.panelOpened()
    }

    /// Closes the panel like a macOS menu: on Escape or on a click in another app.
    /// Also quits on ⌘Q, since the app has no menu bar menu to carry that shortcut.
    private func watchWhileOpen() {
        let escapeKeyCode: UInt16 = 53
        if let keyDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == escapeKeyCode {
                self?.closePanel()
                return nil
            }
            if event.modifierFlags.intersection([.command, .shift, .option, .control]) == .command,
               event.charactersIgnoringModifiers?.lowercased() == "q" {
                NSApp.terminate(nil)
                return nil
            }
            if event.modifierFlags.intersection([.command, .shift, .option, .control]) == .command,
               event.charactersIgnoringModifiers == "," {
                self?.showSettings()
                return nil
            }
            return event
        }) {
            eventMonitors.append(keyDown)
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

    private func showSettings() {
        closePanel()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 240),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Ajustes"
            window.contentViewController = NSHostingController(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        core.panelClosed()
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors.removeAll()
    }
}
