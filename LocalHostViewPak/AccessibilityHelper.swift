import Cocoa

/// Checks / requests the “Accessibility” permission that AppleScript needs
struct AccessibilityHelper {
    /// Call this early (e.g. in `App`’s `init()` or `ContentView.onAppear`) to prompt the user.
    static func ensurePermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            // The system will show the prompt automatically because we passed `true`.
            // You can also show your own UI telling the user to enable the permission.
            print("⚠️ Accessibility permission not granted – user will be prompted.")
        }
    }

    /// Returns `true` if the permission is already granted.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }
}
