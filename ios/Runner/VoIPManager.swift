import CallKit
import AVFoundation
import Foundation

/**
 * Manages CallKit integration for background audio processing.
 *
 * CallKit allows ChaosVoice to maintain an active audio session even when
 * the app is in the background, by presenting itself as a VoIP call.
 *
 * LIMITATION: Full CallKit integration requires a valid VoIP entitlement
 * from Apple (paid Developer account required). Without it, the audio
 * session may be suspended by the system after ~30 seconds in background.
 */
class VoIPManager: NSObject {
    static let shared = VoIPManager()

    private var provider: CXProvider?
    private let callController = CXCallController()

    private override init() {
        super.init()
        setupProvider()
    }

    private func setupProvider() {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        configuration.includesCallsInRecents = false

        provider = CXProvider(configuration: configuration)
        provider?.setDelegate(self, queue: nil)
    }

    /// Report a new incoming call to keep audio session alive in background.
    func reportIncomingCall() {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "ChaosVoice")
        update.hasVideo = false

        provider?.reportNewIncomingCall(
            with: UUID(),
            update: update
        ) { error in
            if let error = error {
                print("[VoIPManager] Failed to report call: \(error.localizedDescription)")
            } else {
                print("[VoIPManager] Call reported — audio session will persist")
            }
        }
    }

    /// End the reported call.
    func endCall() {
        let endCallAction = CXEndCallAction(call: UUID())
        let transaction = CXTransaction(action: endCallAction)
        callController.request(transaction) { error in
            if let error = error {
                print("[VoIPManager] Failed to end call: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CXProviderDelegate

extension VoIPManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        print("[VoIPManager] Provider did reset")
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
        AudioEngineManager.shared.stop()
    }
}
