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
    @AppStorage("accentHue")           var accentHue:     Double = 0.58 // blue-ish

    private init() {}
}
