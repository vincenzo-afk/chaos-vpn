import Foundation
import AVFoundation

/**
 * Root-level audio router for iOS.
 *
 * iOS does not support system-wide mic injection or root-level audio routing
 * due to sandbox restrictions. This class provides the scaffolding expected
 * by the shared MethodChannel API, but always returns `false` for
 * `isDeviceRooted()` and `activate()`.
 *
 * **iOS Limitations:**
 * - No API exists to inject audio system-wide
 * - AVAudioSession is isolated per-app
 * - Regular phone calls (CoreTelephony) are fully isolated
 * - Only VoIP/communication apps sharing the audio session are reachable
 *
 * See the Android `RootAudioRouter.kt` for the actual root-mode implementation.
 */
class RootAudioRouter {

    static let shared = RootAudioRouter()

    private var isRootModeActive = false

    private init() {}

    /// iOS is never rooted — always returns false.
    func isDeviceRooted() -> Bool {
        return false
    }

    /// Initialize — no-op on iOS.
    func initialize() -> Bool {
        return false
    }

    /// Activate — no-op on iOS. Returns false.
    func activate() -> Bool {
        return false
    }

    /// Write audio data — no-op on iOS.
    func write(_ buffer: AVAudioPCMBuffer) -> Bool {
        return false
    }

    /// Deactivate and release resources.
    func deactivate() {
        isRootModeActive = false
    }

    func isActive() -> Bool {
        return isRootModeActive
    }
}
