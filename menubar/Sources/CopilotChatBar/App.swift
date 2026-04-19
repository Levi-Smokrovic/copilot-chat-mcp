import SwiftUI
import AppKit
import UserNotifications

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
                         @preconcurrency UNUserNotificationCenterDelegate,
                         NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let model = ChatModel()

    func applicationDidFinishLaunching(_: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

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
        let names = Settings.shared.iconSymbolName
        let name = model.hasUnread ? names.unread : names.idle
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Copilot Chat")
        img?.isTemplate = true
        button.image = img
    }

    @objc private func toggle(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            guard let button = statusItem?.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            model.markRead()
            refreshIcon()
        }
    }

    /// Used by the notification-click handler. Performs a real click
    /// on the status button so AppKit resolves the popover anchor the
    /// same way it does for a user click — otherwise the popover ends
    /// up floating at the top-left of the screen after the app becomes
    /// active from the background.
    func showPopover() {
        guard let button = statusItem?.button, !popover.isShown else { return }
        button.performClick(nil)
    }

    // MARK: - Notifications

    // Show banners even when our app is frontmost.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Click/tap on banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler:
                                    @escaping () -> Void) {
        if Settings.shared.openPopoverOnNotificationClick {
            // Tiny delay so the status item finishes re-layout after the
            // app becomes active; otherwise the popover can attach to a
            // stale button frame and appear in the wrong spot.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.showPopover()
            }
        }
        completionHandler()
    }
}
