import AVFoundation
import Darwin

extension AVAudioTime {
    // Returns a future AVAudioTime `frames` samples from `self`, using hostTime.
    // Requires self.isHostTimeValid.
    func advanced(byFrames frames: AVAudioFramePosition, sampleRate: Double) -> AVAudioTime {
        guard isHostTimeValid else { return self }
        let seconds = Double(frames) / sampleRate
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        // hostTime is in mach_absolute_time units; convert seconds → nanoseconds → machTime
        let deltaNs = seconds * 1_000_000_000.0
        let deltaMach = UInt64(deltaNs * Double(info.denom) / Double(info.numer))
        return AVAudioTime(hostTime: hostTime &+ deltaMach)
    }

    // Returns now + `seconds` as a hostTime-based AVAudioTime.
    static func futureTime(secondsFromNow: Double) -> AVAudioTime {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let deltaNs = secondsFromNow * 1_000_000_000.0
        let deltaMach = UInt64(deltaNs * Double(info.denom) / Double(info.numer))
        return AVAudioTime(hostTime: mach_absolute_time() &+ deltaMach)
    }
}
