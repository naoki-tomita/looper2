import AVFoundation

// Central orchestrator for all audio operations.
// All public methods must be called from the main thread.
final class AudioEngine {
    // Canonical recording/playback format used throughout the app.
    // Hardware format is converted to this on the way in.
    static let canonicalFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 44100,
        channels: 2,
        interleaved: false
    )!

    private let engine = AVAudioEngine()
    private let clock: LoopClock
    private let sessionManager = AudioSessionManager.shared
    // trackNodes is set at init and never mutated — safe to read from any thread.
    private(set) var trackNodes: [Int: TrackAudioNode] = [:]
    private var tapInstalled = false

    // Weak back-reference to update TrackModel.level from metering.
    private weak var levelUpdateTarget: LevelUpdateTarget?

    @MainActor
    init(trackCount: Int, clock: LoopClock) {
        self.clock = clock
        for i in 1...trackCount {
            trackNodes[i] = TrackAudioNode(trackNumber: i, format: Self.canonicalFormat)
        }
        buildGraph()
        sessionManager.onRouteChange = { [weak self] in self?.handleRouteChange() }
        sessionManager.onInterruption = { [weak self] began in
            if !began { try? self?.engine.start() }
        }
    }

    @MainActor
    private func buildGraph() {
        let mainMixer = engine.mainMixerNode
        for (_, node) in trackNodes {
            engine.attach(node.playerNode)
            engine.attach(node.mixerNode)
            engine.connect(node.playerNode, to: node.mixerNode, format: Self.canonicalFormat)
            // Use nil so the engine negotiates the format with the hardware output node,
            // avoiding sample-rate mismatches that cause engine.start() to throw.
            engine.connect(node.mixerNode, to: mainMixer, format: nil)
        }
    }

    @MainActor
    func start() throws {
        try sessionManager.configure()
        try engine.start()
        installCaptureTap()
    }

    @MainActor
    private func installCaptureTap() {
        guard !tapInstalled else { return }
        let inputNode = engine.inputNode

        // Pass nil so AVAudioEngine uses the node's native hardware format.
        // Querying outputFormat(forBus:) before the first render can return
        // a zero sample-rate format and crash; nil avoids that entirely.
        // The converter is built lazily on the first callback (audio thread, once only).
        var lazyConverter: AVAudioConverter? = nil

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
            guard let self else { return }

            // Build converter once, on first buffer delivery
            if lazyConverter == nil {
                lazyConverter = AVAudioConverter(from: buffer.format, to: Self.canonicalFormat)
            }

            let canonical: AVAudioPCMBuffer
            if let converter = lazyConverter,
               buffer.format != Self.canonicalFormat {
                let ratio = Self.canonicalFormat.sampleRate / buffer.format.sampleRate
                let outCapacity = max(1, AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1))
                guard let outBuf = AVAudioPCMBuffer(pcmFormat: Self.canonicalFormat,
                                                    frameCapacity: outCapacity) else { return }
                var error: NSError?
                var consumed = false
                converter.convert(to: outBuf, error: &error) { _, outStatus in
                    if consumed { outStatus.pointee = .endOfStream; return nil }
                    consumed = true
                    outStatus.pointee = .haveData
                    return buffer
                }
                guard error == nil, outBuf.frameLength > 0 else { return }
                canonical = outBuf
            } else {
                canonical = buffer
            }

            for (_, node) in self.trackNodes where node.isCapturing {
                node.appendAudioData(canonical)
            }
        }
        tapInstalled = true
    }

    @MainActor
    private func removeCaptureTap() {
        guard tapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    // MARK: - Track control (called from main thread via TrackModel)

    @MainActor
    func handleRec(trackNumber: Int, model: TrackModel) {
        guard let node = trackNodes[trackNumber] else { return }
        let now = engine.outputNode.lastRenderTime ?? AVAudioTime.futureTime(secondsFromNow: 0.05)

        switch model.state {
        case .empty:
            node.prepareForRecording()
            model.state = .recording

        case .recording:
            node.stopCapturing()
            let frameCount = node.finalizeRecording(masterLength: clock.masterFrameCount)
            guard frameCount > 0 else {
                model.state = .empty
                return
            }
            if !clock.isRunning {
                // First track — starts playing immediately; schedule slightly in the future
                let startTime = AVAudioTime.futureTime(secondsFromNow: 0.05)
                clock.setMaster(frameCount: frameCount, anchor: startTime, sampleRate: Self.canonicalFormat.sampleRate)
                node.scheduleLoop(at: startTime)
            } else {
                let startTime = clock.nextBoundary(after: now)
                node.scheduleLoop(at: startTime)
            }
            model.state = .playing
            model.layerCount = node.bufferStack.count

        case .playing, .muted:
            node.prepareForRecording()
            model.state = .overdubbing

        case .overdubbing:
            node.stopCapturing()
            let _ = node.finalizeRecording(masterLength: clock.masterFrameCount)
            node.rescheduleLoop(clock: clock, now: now)
            model.state = .playing
            model.layerCount = node.bufferStack.count
        }
    }

    @MainActor
    func handleMute(trackNumber: Int, model: TrackModel) {
        guard let node = trackNodes[trackNumber] else { return }
        switch model.state {
        case .playing:
            node.setMuted(true)
            model.state = .muted
        case .muted:
            node.setMuted(false)
            model.state = .playing
        default:
            break
        }
    }

    @MainActor
    func handleUndo(trackNumber: Int, model: TrackModel) {
        guard let node = trackNodes[trackNumber],
              model.state == .playing || model.state == .muted else { return }
        let now = engine.outputNode.lastRenderTime ?? AVAudioTime.futureTime(secondsFromNow: 0.05)
        node.undoLastLayer(clock: clock, now: now)
        model.layerCount = node.bufferStack.count
        if node.bufferStack.isEmpty {
            node.setMuted(false)
            model.state = .empty
        }
    }

    @MainActor
    func masterStop() {
        for (_, node) in trackNodes {
            node.stop()
        }
    }

    @MainActor
    func masterClear() {
        for (_, node) in trackNodes {
            node.clear()
        }
        clock.reset()
    }

    // MARK: - Level metering
    // Returns RMS level [0,1] for a track (called periodically from UI timer)
    @MainActor
    func rmsLevel(for trackNumber: Int) -> Float {
        guard let node = trackNodes[trackNumber] else { return 0 }
        let mixer = node.mixerNode
        // AVAudioMixerNode doesn't expose per-bus metering directly;
        // we approximate via outputVolume and player.isPlaying
        guard node.playerNode.isPlaying, mixer.outputVolume > 0 else { return 0 }
        return 0.6  // placeholder — replace with actual metering tap if needed
    }

    // MARK: - Route change

    @MainActor
    private func handleRouteChange() {
        removeCaptureTap()
        // Stop all recording tracks to avoid buffer corruption
        for (_, node) in trackNodes where node.isCapturing {
            node.stopCapturing()
        }
        try? engine.start()
        installCaptureTap()
    }
}

// Marker protocol so AudioEngine can weakly hold a level update target without importing SwiftUI
protocol LevelUpdateTarget: AnyObject {}
