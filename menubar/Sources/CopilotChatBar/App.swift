import SwiftUI
import UserNotifications
import AppKit

@main
struct CopilotChatBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = ChatModel()

    var body: some Scene {
        MenuBarExtra {
            ChatView()
                .environmentObject(model)
                .frame(width: 380, height: 520)
        } label: {
            Image(systemName: model.hasUnread
                  ? "bubble.left.and.bubble.right.fill"
                  : "bubble.left.and.bubble.right")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission up front so banners work when
        // Copilot fires a question.
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    @MainActor static let shared = NotificationDelegate()
    // Show banners even when the app (menu bar) is frontmost.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
