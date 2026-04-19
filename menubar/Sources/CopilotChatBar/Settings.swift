import Foundation
import SwiftUI

/// Persisted user preferences. Stored in UserDefaults.
@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    @AppStorage("notifyEnabled")       var notifyEnabled: Bool   = true
    @AppStorage("notifySoundEnabled")  var soundEnabled:  Bool   = true
    @AppStorage("notifyOnUpdates")     var notifyOnUpdates: Bool = false
    @AppStorage("openPopoverOnClick")  var openPopoverOnNotificationClick: Bool = true
    @AppStorage("serverURL")           var serverURL:     String = "ws://127.0.0.1:8765/ws"

    // Appearance
    @AppStorage("accentHue")   var accentHue:   Double = 0.58   // 0…1
    @AppStorage("appearance")  var appearance:  String = "auto" // auto|light|dark
    @AppStorage("iconStyle")   var iconStyle:   String = "bubble" // bubble|sparkles|message

    // Chat bubbles (hue, 0…1)
    @AppStorage("userBubbleHue")      var userBubbleHue:      Double = 0.33  // green
    @AppStorage("assistantBubbleHue") var assistantBubbleHue: Double = 0.58  // blue
    @AppStorage("questionBubbleHue")  var questionBubbleHue:  Double = 0.09  // orange
    @AppStorage("bubbleOpacity")      var bubbleOpacity:      Double = 0.30
    @AppStorage("bubbleCornerRadius") var bubbleCornerRadius: Double = 16

    private init() {}

    var accentColor: Color {
        Color(hue: accentHue, saturation: 0.75, brightness: 0.95)
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var iconSymbolName: (idle: String, unread: String) {
        switch iconStyle {
        case "sparkles": return ("sparkles", "sparkles")
        case "message":  return ("message",  "message.fill")
        default:         return ("bubble.left.and.bubble.right",
                                 "bubble.left.and.bubble.right.fill")
        }
    }

    func bubbleTint(role: String, kind: String) -> Color {
        let hue: Double
        switch (role, kind) {
        case ("user", _):         hue = userBubbleHue
        case (_, "question"):     hue = questionBubbleHue
        case (_, "update"):       return Color.gray.opacity(bubbleOpacity * 0.66)
        default:                  hue = assistantBubbleHue
        }
        return Color(hue: hue, saturation: 0.7, brightness: 0.95)
            .opacity(bubbleOpacity)
    }
}
