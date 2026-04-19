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
                         NSPopoverDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var chatWindow: NSWindow?
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

    /// Used by the notification-click handler. Opens the chat as a
    /// standalone floating window instead of a popover — this works
    /// reliably regardless of whether the status bar button has been
    /// laid out yet after the app activates from the background.
    func showPopover() {
        showChatWindow()
    }

    private func showChatWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let w = chatWindow {
            w.makeKeyAndOrderFront(nil)
            model.markRead()
            refreshIcon()
            return
        }

        let host = NSHostingController(
            rootView: RootView()
                .environmentObject(model)
                .environmentObject(Settings.shared)
        )
        let w = NSWindow(contentViewController: host)
        w.title = "Copilot Chat"
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: 400, height: 560))
        w.center()
        w.level = .floating
        w.delegate = self
        chatWindow = w
        w.makeKeyAndOrderFront(nil)
        model.markRead()
        refreshIcon()
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
            DispatchQueue.main.async { [weak self] in
                self?.showChatWindow()
            }
        }
        completionHandler()
    }

    // MARK: - Window

    func windowWillClose(_ notification: Notification) {
        if let w = notification.object as? NSWindow, w == chatWindow {
            chatWindow = nil
        }
    }
}
