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
}
