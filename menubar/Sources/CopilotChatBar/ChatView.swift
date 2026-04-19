import SwiftUI

struct ChatView: View {
    @EnvironmentObject var model: ChatModel
    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            messagesList
            composer
        }
        .background(.clear)
        .onAppear {
            model.markRead()
            inputFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.connected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text("Copilot Chat")
                .font(.headline)
            Spacer()
            Text(model.connected ? "connected" : "reconnecting…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
    let msg: ChatMessage

    var body: some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 3) {
                metaLabel
                Text(msg.text)
                    .font(.system(size: 13))
                    .foregroundStyle(msg.kind == .update ? .secondary : .primary)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: 280, alignment: .leading)
            .glassEffect(
                .regular.tint(tint).interactive(),
                in: RoundedRectangle(cornerRadius: 16)
            )
            if msg.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var tint: Color {
        switch (msg.role, msg.kind) {
        case (.user, _):        return .green.opacity(0.35)
        case (_, .question):    return .orange.opacity(0.35)
        case (_, .update):      return .gray.opacity(0.20)
        case (.assistant, _):   return .blue.opacity(0.30)
        }
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
