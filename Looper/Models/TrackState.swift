import Foundation

enum TrackState: Equatable {
    case empty
    case recording
    case playing
    case muted
    case overdubbing
}

struct TrackID: Hashable, Identifiable {
    let number: Int
    var id: Int { number }
}

@MainActor
final class TrackModel: ObservableObject, Identifiable {
    let id: TrackID
    @Published var state: TrackState = .empty
    @Published var layerCount: Int = 0
    @Published var level: Float = 0.0

    // Set by LoopSession after init
    var audioEngine: AudioEngine?

    init(id: TrackID) {
        self.id = id
    }

    func tapRec() {
        audioEngine?.handleRec(trackNumber: id.number, model: self)
    }

    func tapMute() {
        audioEngine?.handleMute(trackNumber: id.number, model: self)
    }

    func tapUndo() {
        audioEngine?.handleUndo(trackNumber: id.number, model: self)
    }
}
