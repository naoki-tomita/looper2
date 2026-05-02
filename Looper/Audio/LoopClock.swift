import AVFoundation

// Authority on master loop length and timing anchor.
// All methods called from main thread.
final class LoopClock {
    private(set) var masterFrameCount: AVAudioFrameCount?
    // hostTime-based AVAudioTime marking when the first loop's playback began
    private(set) var anchorTime: AVAudioTime?
    private(set) var sampleRate: Double = 44100.0

    var isRunning: Bool { masterFrameCount != nil }

    func setMaster(frameCount: AVAudioFrameCount, anchor: AVAudioTime, sampleRate: Double) {
        self.masterFrameCount = frameCount
        self.anchorTime = anchor
        self.sampleRate = sampleRate
    }

    // Returns the next loop boundary as a hostTime-based AVAudioTime.
    // `now` must be a hostTime-valid AVAudioTime (e.g. from outputNode.lastRenderTime).
    func nextBoundary(after now: AVAudioTime) -> AVAudioTime {
        guard let master = masterFrameCount,
              let anchor = anchorTime,
              now.isHostTimeValid, anchor.isHostTimeValid else {
            return AVAudioTime.futureTime(secondsFromNow: 0.05)
        }

        // Compute elapsed time in seconds from anchor to now
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let numer = Double(info.numer)
        let denom = Double(info.denom)

        let nowNs: Double
        let anchorNs: Double
        if now.hostTime >= anchor.hostTime {
            let diffMach = now.hostTime - anchor.hostTime
            nowNs = Double(diffMach) * numer / denom
            anchorNs = 0
        } else {
            // now is before anchor (shouldn't happen in practice)
            return anchor
        }

        let elapsedSeconds = nowNs / 1_000_000_000.0
        let elapsedFrames = elapsedSeconds * sampleRate
        let masterD = Double(master)
        let positionInLoop = elapsedFrames.truncatingRemainder(dividingBy: masterD)
        let framesUntilNext = masterD - positionInLoop
        let secondsUntilNext = framesUntilNext / sampleRate

        return now.advanced(byFrames: AVAudioFramePosition(framesUntilNext), sampleRate: sampleRate)
    }

    func reset() {
        masterFrameCount = nil
        anchorTime = nil
    }
}
