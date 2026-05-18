import UIKit
import Flutter
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure AVAudioSession for voice processing
        configureAudioSession()

        // Register MethodChannel
        let controller = window?.rootViewController as! FlutterViewController
        let audioChannel = FlutterMethodChannel(
            name: "com.chaosvoice/audio",
            binaryMessenger: controller.binaryMessenger
        )

        audioChannel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "startService":
                self?.startAudioService(call, result: result)
            case "stopService":
                self?.stopAudioService(call, result: result)
            case "isRunning":
                result(AudioEngineManager.shared.isActive)
            case "updateParams":
                self?.updateParams(call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // TODO: Register for remote notifications (required for VoIP)
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Forward token to VoIP provider if needed
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            print("[AppDelegate] Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - MethodChannel Handlers

    private func startAudioService(_ call: FlutterMethodCall, result: FlutterResult) {
        do {
            try AudioEngineManager.shared.start()
            result(true)
        } catch {
            print("[AppDelegate] startAudioService failed: \(error)")
            result(false)
        }
    }

    private func stopAudioService(_ call: FlutterMethodCall, result: FlutterResult) {
        AudioEngineManager.shared.stop()
        result(true)
    }

    private func updateParams(_ call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(nil)
            return
        }
        let manager = AudioEngineManager.shared
        if let gain = args["gain"] as? Double {
            manager.updateGain(Float(gain))
        }
        if let crackleIntensity = args["crackleIntensity"] as? Double {
            manager.crackleProb = Float(crackleIntensity)
        }
        if let dropoutRate = args["dropoutRate"] as? Double {
            manager.dropoutProb = Float(dropoutRate)
        }
        result(nil)
    }
}
