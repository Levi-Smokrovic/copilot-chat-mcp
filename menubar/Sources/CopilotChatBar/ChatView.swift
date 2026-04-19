import SwiftUI

struct ChatView: View {
    @EnvironmentObject var model: ChatModel
    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            composer
        }
        .background(.clear)
        .onAppear {
            model.markRead()
            inputFocused = true
        }
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(model.messages) { msg in
                        MessageBubble(msg: msg).id(msg.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .onChange(of: model.messages.count) { _, _ in
                if let last = model.messages.last {
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message Copilot…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                .focused($inputFocused)
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .tint(.accentColor)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func send() {
        let text = draft
        draft = ""
        model.send(text)
    }
}

// MARK: - Bubble

private struct MessageBubble: View {
    @EnvironmentObject var settings: Settings
    let msg: ChatMessage

    var body: some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 3) {
                metaLabel
                Text(linkified(msg.text))
                    .font(.system(size: 13))
                    .foregroundStyle(msg.kind == .update ? .secondary : .primary)
                    .textSelection(.enabled)
                    .tint(.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: 280, alignment: .leading)
            .glassEffect(
                .regular.tint(tint).interactive(),
                in: RoundedRectangle(cornerRadius: settings.bubbleCornerRadius)
            )
            if msg.role == .assistant { Spacer(minLength: 40) }
        }
    }

    /// Detect URLs in the message and turn them into clickable links.
    /// SwiftUI's `Text` renders `AttributedString` links natively.
    private func linkified(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        )
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        detector?.enumerateMatches(in: text, options: [], range: range) { m, _, _ in
            guard let m, let url = m.url else { return }
            if let r = Range(m.range, in: text),
               let ar = Range(r, in: attr) {
                attr[ar].link = url
                attr[ar].foregroundColor = .accentColor
                attr[ar].underlineStyle = .single
            }
        }
        return attr
    }

    private var tint: Color {
        let roleStr = msg.role == .user ? "user" : "assistant"
        let kindStr: String = {
            switch msg.kind {
            case .question: return "question"
            case .update:   return "update"
            case .normal:   return "normal"
            }
        }()
        return settings.bubbleTint(role: roleStr, kind: kindStr)
    }

    @ViewBuilder private var metaLabel: some View {
        let label: String = {
            switch (msg.role, msg.kind) {
            case (.user, _):
                return msg.source == "telegram" ? "you · telegram"
                     : msg.source == "menubar"  ? "you · menubar"
                     : "you · web"
            case (.assistant, .question): return "copilot · question"
            case (.assistant, .update):   return "copilot · update"
            case (.assistant, _):         return "copilot"
            }
        }()
        Text(label)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
