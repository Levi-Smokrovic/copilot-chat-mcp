import SwiftUI
import AppKit

/// Menu-bar app built on AppKit's NSStatusItem / NSPopover. SwiftUI's
/// `MenuBarExtra` looked nicer on paper but its click handling is fragile
/// after losing focus to a notification / another app, which is exactly
/// what happens here. AppKit gives us direct control.
@main
struct CopilotChatBarApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate,
                         @preconcurrency NSUserNotificationCenterDelegate,
                         NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let model = ChatModel()

    func applicationDidFinishLaunching(_: Notification) {
        NSUserNotificationCenter.default.delegate = self

        // Popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: RootView()
                .environmentObject(model)
                .environmentObject(Settings.shared)
        )
        popover.contentSize = NSSize(width: 400, height: 560)

        // Status bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refreshIcon()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(toggle(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Repaint the icon whenever unread state changes.
        model.onUnreadChanged = { [weak self] in self?.refreshIcon() }
    }

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let name = model.hasUnread
            ? "bubble.left.and.bubble.right.fill"
            : "bubble.left.and.bubble.right"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Copilot Chat")
        img?.isTemplate = true
        button.image = img
    }

    @objc private func toggle(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        model.markRead()
        refreshIcon()
    }

    // MARK: - Notifications

    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                shouldPresent notification: NSUserNotification) -> Bool {
        true
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                didActivate notification: NSUserNotification) {
        guard Settings.shared.openPopoverOnNotificationClick else { return }
        DispatchQueue.main.async { [weak self] in
            self?.showPopover()
        }
    }
}
