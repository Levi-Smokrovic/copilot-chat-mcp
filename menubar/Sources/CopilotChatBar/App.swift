import SwiftUI
import AppKit

@main
struct CopilotChatBarApp: App {
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
