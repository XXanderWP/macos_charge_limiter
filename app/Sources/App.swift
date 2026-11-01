import AppKit
import SwiftUI
import Combine

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var monitor: Monitor!
    private var cancellables = Set<AnyCancellable>()

    nonisolated static func main() {
        MainActor.assumeIsolated { run() }
    }

    private static func run() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = Monitor()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        // The popover follows the SwiftUI content size, otherwise it is placed with a stale height
        let host = NSHostingController(rootView: PopoverView(monitor: monitor))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host

        // Icon changes only when the state changes, never re-created
        monitor.$snapshot.combineLatest(monitor.$config)
            .map { snapshot, config in Self.iconName(snapshot, config) }
            .removeDuplicates()
            .sink { [weak self] name in
                let image = NSImage(systemSymbolName: name, accessibilityDescription: "Charge Limiter")
                image?.isTemplate = true
                self?.statusItem.button?.image = image
            }
            .store(in: &cancellables)
    }

    private static func iconName(_ s: PowerSnapshot?, _ c: LimiterConfig) -> String {
        if s?.forcedDischarge == true { return "arrow.down.circle.fill" }
        return c.enabled ? "leaf.fill" : "bolt.fill"
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            monitor.visible = true
            if let view = popover.contentViewController?.view {
                view.layoutSubtreeIfNeeded()
                popover.contentSize = view.fittingSize
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        monitor.visible = false
    }
}
