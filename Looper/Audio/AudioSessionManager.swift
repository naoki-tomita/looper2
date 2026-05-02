import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()

    var onRouteChange: (() -> Void)?
    var onInterruption: ((Bool) -> Void)?  // true = began, false = ended

    private init() {}

    func configure() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetooth, .defaultToSpeaker, .allowBluetoothA2DP]
        )
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .categoryChange:
            DispatchQueue.main.async { self.onRouteChange?() }
        default:
            break
        }
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        DispatchQueue.main.async {
            self.onInterruption?(type == .began)
        }
    }
}
