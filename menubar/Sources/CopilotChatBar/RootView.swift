import SwiftUI
import AppKit

struct RootView: View {
    @EnvironmentObject var model: ChatModel
    @EnvironmentObject var settings: Settings
    @State private var tab: Tab = .chat

    enum Tab { case chat, settings }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            switch tab {
            case .chat:     ChatView()
            case .settings: SettingsView()
            }
        }
        .frame(width: 400, height: 560)
        .tint(settings.accentColor)
        .preferredColorScheme(settings.colorScheme)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.connected ? .green : .orange)
                .frame(width: 8, height: 8)
            Text("Copilot Chat")
                .font(.headline)
            Spacer()
            Picker("", selection: $tab) {
                Image(systemName: "bubble.left.and.bubble.right").tag(Tab.chat)
                Image(systemName: "gearshape").tag(Tab.settings)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 80)
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit Copilot Chat")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Settings pane

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var model: ChatModel

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    Text("Auto").tag("auto")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)

                Picker("Menu bar icon", selection: $settings.iconStyle) {
                    Label("Bubbles",  systemImage: "bubble.left.and.bubble.right").tag("bubble")
                    Label("Sparkles", systemImage: "sparkles").tag("sparkles")
                    Label("Message",  systemImage: "message").tag("message")
                }
                .onChange(of: settings.iconStyle) { _, _ in
                    model.onUnreadChanged?()
                }

                HStack {
                    Text("Accent")
                    Slider(value: $settings.accentHue, in: 0...1) {
                        Text("Hue")
                    }
                    Circle()
                        .fill(settings.accentColor)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(.white.opacity(0.2)))
                }
            }
            Section("Notifications") {
                Toggle("Show banners", isOn: $settings.notifyEnabled)
                Toggle("Play sound", isOn: $settings.soundEnabled)
                    .disabled(!settings.notifyEnabled)
                Toggle("Notify on agent progress updates",
                       isOn: $settings.notifyOnUpdates)
                    .disabled(!settings.notifyEnabled)
                Toggle("Clicking a banner opens this window",
                       isOn: $settings.openPopoverOnNotificationClick)
            }
            Section("Connection") {
                HStack {
                    Text("Server")
                    TextField("ws://…", text: $settings.serverURL)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Button("Reconnect") { model.reconnect() }
                    Spacer()
                    Text(model.connected ? "connected" : "disconnected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Chat") {
                Button("Clear history") { model.clearHistory() }
            }
            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                Link("GitHub",
                     destination: URL(string:
                     "https://github.com/Levi-Smokrovic/copilot-chat-mcp")!)
                Text("Not affiliated with GitHub, Microsoft, or any AI provider. "
                   + "Use at your own risk — may violate provider terms of service.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
