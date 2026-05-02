import Foundation
import Combine

@MainActor
final class LoopSession: ObservableObject, LevelUpdateTarget {
    static let trackCount = 6

    @Published var tracks: [TrackModel]
    let loopClock: LoopClock
    let audioEngine: AudioEngine

    private var levelTimer: AnyCancellable?

    init() {
        loopClock = LoopClock()
        audioEngine = AudioEngine(trackCount: LoopSession.trackCount, clock: loopClock)

        let ids = (1...LoopSession.trackCount).map { TrackID(number: $0) }
        tracks = ids.map { TrackModel(id: $0) }
        tracks.forEach { $0.audioEngine = audioEngine }

        Task {
            do {
                try audioEngine.start()
            } catch {
                print("AudioEngine start failed: \(error)")
            }
        }

        // Update level meters at ~30fps
        levelTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateLevels() }
    }

    private func updateLevels() {
        for track in tracks {
            track.level = audioEngine.rmsLevel(for: track.id.number)
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
