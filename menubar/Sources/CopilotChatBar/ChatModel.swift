import Foundation
import SwiftUI
import AppKit

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    enum Role { case user, assistant }
    enum Kind { case normal, question, update }
    let role: Role
    let kind: Kind
    let text: String
    let source: String?   // "web" | "telegram" | "menubar" | nil
    let ts: Date
}

@MainActor
final class ChatModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var connected: Bool = false
    @Published var hasUnread: Bool = false

    private var socket: URLSessionWebSocketTask?
    private let session: URLSession
    private var reconnectTask: Task<Void, Never>?

    // Matches the MCP server defaults (see server.py).
    private let wsURL = URL(string: "ws://127.0.0.1:8765/ws")!

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)
        connect()
    }

    func markRead() { hasUnread = false }

    // MARK: - WebSocket lifecycle

    private func connect() {
        reconnectTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        let task = session.webSocketTask(with: wsURL)
        self.socket = task
        task.resume()
        Task { await self.receiveLoop(task: task) }
    }

    private func scheduleReconnect() {
        connected = false
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled, let self else { return }
            self.connect()
        }
    }

    private func receiveLoop(task: URLSessionWebSocketTask) async {
        connected = true
        while task === self.socket {
            do {
                let msg = try await task.receive()
                switch msg {
                case .string(let s):
                    self.handleIncoming(json: s)
                case .data(let d):
                    if let s = String(data: d, encoding: .utf8) {
                        self.handleIncoming(json: s)
                    }
                @unknown default: break
                }
            } catch {
                scheduleReconnect()
                return
            }
        }
    }

    // MARK: - Incoming JSON

    private func handleIncoming(json: String) {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        let role: ChatMessage.Role =
            (obj["role"] as? String) == "user" ? .user : .assistant
        let kindStr = obj["kind"] as? String ?? ""
        let kind: ChatMessage.Kind =
            kindStr == "question" ? .question :
            kindStr == "update"   ? .update   : .normal
        let text = obj["text"] as? String ?? ""
        let source = obj["source"] as? String
        let ts = (obj["ts"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date()

        // De-dup: server replays the last 100 messages on reconnect. Skip anything
        // whose (text, ts, role) already appears at the tail.
        if let last = messages.last,
           last.text == text, last.role == role,
           abs(last.ts.timeIntervalSince(ts)) < 0.5 {
            return
        }

        let m = ChatMessage(role: role, kind: kind, text: text, source: source, ts: ts)
        messages.append(m)
        if messages.count > 500 { messages.removeFirst(messages.count - 500) }

        if role == .assistant {
            hasUnread = true
            notify(for: m)
        }
    }

    // Uses the legacy NSUserNotification API. Deprecated but still
    // functional on macOS 26, and unlike UNUserNotificationCenter it
    // requires no authorization prompt for an ad-hoc-signed menu-bar
    // app. Clicks route back to this app (so the menu bar popover
    // opens), unlike `osascript display notification` whose clicks
    // go to Script Editor.
    private func notify(for m: ChatMessage) {
        let title: String
        switch m.kind {
        case .question: title = "Copilot is asking"
        case .update:   title = "Copilot update"
        case .normal:   title = "Copilot"
        }
        let n = NSUserNotification()
        n.title = title
        n.informativeText = m.text
        if m.kind != .update { n.soundName = NSUserNotificationDefaultSoundName }
        NSUserNotificationCenter.default.deliver(n)
    }

    // MARK: - Outgoing

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let socket else { return }
        let payload = ["text": trimmed, "source": "menubar"]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8)
        else { return }
        socket.send(.string(str)) { [weak self] err in
            if err != nil { Task { @MainActor in self?.scheduleReconnect() } }
        }
    }
}
