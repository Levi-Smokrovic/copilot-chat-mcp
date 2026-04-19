// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "CopilotChatBar",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "CopilotChatBar",
            path: "Sources/CopilotChatBar"
        )
    ]
)
