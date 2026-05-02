import AVFoundation

final class TrackAudioNode {
    let trackNumber: Int
    let playerNode: AVAudioPlayerNode
    let mixerNode: AVAudioMixerNode
    let bufferStack: BufferStack

    // Pre-allocated recording buffer: written from real-time audio thread.
    // Allocated on main thread before recording starts; not mutated from main thread
    // until isCapturing becomes false (written atomically on audio thread).
    private var recordingBuffer: AVAudioPCMBuffer?
    // Written only from audio thread while isCapturing = true; read on main thread after isCapturing = false.
    nonisolated(unsafe) private(set) var recordingFramePosition: AVAudioFrameCount = 0
    nonisolated(unsafe) var isCapturing: Bool = false

    // How many seconds of audio to pre-allocate for recording
    private static let maxRecordingSeconds: Double = 300

    let canonicalFormat: AVAudioFormat

    init(trackNumber: Int, format: AVAudioFormat) {
        self.trackNumber = trackNumber
        self.playerNode = AVAudioPlayerNode()
        self.mixerNode = AVAudioMixerNode()
        self.canonicalFormat = format
        self.bufferStack = BufferStack(format: format)
    }

    // Call from main thread before recording starts
    func prepareForRecording() {
        let maxFrames = AVAudioFrameCount(TrackAudioNode.maxRecordingSeconds * canonicalFormat.sampleRate)
        recordingBuffer = AVAudioPCMBuffer(pcmFormat: canonicalFormat, frameCapacity: maxFrames)
        recordingBuffer?.frameLength = 0
        recordingFramePosition = 0
        isCapturing = true
    }

    // Called from the real-time audio thread tap callback.
    // Only safe memcpy + counter increment; no allocations.
    func appendAudioData(_ buffer: AVAudioPCMBuffer) {
        guard isCapturing,
              let dest = recordingBuffer,
              recordingFramePosition + buffer.frameLength <= dest.frameCapacity else { return }

        let channelCount = Int(canonicalFormat.channelCount)
        let frames = Int(buffer.frameLength)
        for ch in 0..<channelCount {
            guard let src = buffer.floatChannelData?[ch],
                  let destData = dest.floatChannelData?[ch] else { continue }
            memcpy(destData.advanced(by: Int(recordingFramePosition)), src, frames * MemoryLayout<Float>.size)
        }
        recordingFramePosition += buffer.frameLength
    }

    // Call from main thread to stop recording
    func stopCapturing() {
        isCapturing = false
    }

    // Call from main thread after stopCapturing().
    // Trims/pads to masterLength, pushes to BufferStack.
    // Returns the finalized frame count (= masterFrameCount if provided, else actual recorded length).
    func finalizeRecording(masterLength: AVAudioFrameCount?) -> AVAudioFrameCount {
        guard var raw = recordingBuffer else { return 0 }
        raw.frameLength = recordingFramePosition
        recordingBuffer = nil

        let finalBuffer: AVAudioPCMBuffer
        if let master = masterLength {
            finalBuffer = raw.frameLength >= master ? raw.trimmed(to: master) : raw.padded(to: master)
        } else {
            finalBuffer = raw
        }

        bufferStack.push(finalBuffer)
        return finalBuffer.frameLength
    }

    // Schedule the mixed-down buffer for looping playback starting at `startTime`.
    func scheduleLoop(at startTime: AVAudioTime) {
        guard let buffer = bufferStack.mixedBuffer else { return }
        playerNode.stop()
        playerNode.scheduleBuffer(buffer, at: startTime, options: .loops, completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    // Reschedule after overdub: align start to the next loop boundary.
    func rescheduleLoop(clock: LoopClock, now: AVAudioTime) {
        guard bufferStack.mixedBuffer != nil else {
            playerNode.stop()
            return
        }
        let nextBoundary = clock.nextBoundary(after: now)
        scheduleLoop(at: nextBoundary)
    }

    // Remove the most-recent layer and reschedule. If no layers remain, stop.
    func undoLastLayer(clock: LoopClock, now: AVAudioTime) {
        let hasMore = bufferStack.popLayer()
        if hasMore {
            rescheduleLoop(clock: clock, now: now)
        } else {
            playerNode.stop()
        }
    }

    func setMuted(_ muted: Bool) {
        mixerNode.outputVolume = muted ? 0.0 : 1.0
    }

    func stop() {
        isCapturing = false
        playerNode.stop()
    }

    func clear() {
        isCapturing = false
        playerNode.stop()
        bufferStack.clear()
        recordingBuffer = nil
        recordingFramePosition = 0
    }
}
