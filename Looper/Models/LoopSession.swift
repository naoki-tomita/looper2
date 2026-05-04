import Foundation
import Combine
import AVFoundation

@MainActor
final class LoopSession: ObservableObject, LevelUpdateTarget {
    static let trackCount = 6

    @Published var tracks: [TrackModel]
    @Published var engineError: String? = nil
    let loopClock: LoopClock
    let audioEngine: AudioEngine

    private var levelTimer: AnyCancellable?

    init() {
        loopClock = LoopClock()
        audioEngine = AudioEngine(trackCount: LoopSession.trackCount, clock: loopClock)

        let ids = (1...LoopSession.trackCount).map { TrackID(number: $0) }
        tracks = ids.map { TrackModel(id: $0) }
        tracks.forEach { $0.audioEngine = audioEngine }

        // Update level meters at ~30fps
        levelTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateLevels() }

        // Request mic permission then start the engine synchronously on the main actor.
        // Using requestRecordPermission so the dialog appears before the user can tap REC.
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if !granted {
                    self.engineError = "マイクへのアクセスが拒否されました。設定アプリから許可してください。"
                    return
                }
                do {
                    try self.audioEngine.start()
                } catch {
                    self.engineError = "オーディオエンジンの起動に失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }

    private func updateLevels() {
        for track in tracks {
            track.level = audioEngine.rmsLevel(for: track.id.number)
            if track.state == .recording || track.state == .overdubbing {
                track.recordingSeconds = audioEngine.recordingSeconds(for: track.id.number)
            }
        }
    }

    func masterStop() {
        audioEngine.masterStop()
        // Abort any active recordings; leave playing/muted tracks as-is (audio stopped by engine)
        for track in tracks {
            switch track.state {
            case .recording:
                track.state = .empty
            case .overdubbing:
                track.state = .playing
            default:
                break
            }
        }
    }

    func masterClear() {
        audioEngine.masterClear()
        for track in tracks {
            track.state = .empty
            track.layerCount = 0
            track.level = 0
        }
    }
}
