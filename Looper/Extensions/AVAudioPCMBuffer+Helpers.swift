import AVFoundation

extension AVAudioPCMBuffer {
    static func concatenate(_ buffers: [AVAudioPCMBuffer], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let totalFrames = buffers.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        guard totalFrames > 0,
              let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return nil }

        result.frameLength = totalFrames
        let channelCount = Int(format.channelCount)
        var offset = AVAudioFrameCount(0)

        for buffer in buffers {
            let frames = buffer.frameLength
            for ch in 0..<channelCount {
                guard let src = buffer.floatChannelData?[ch],
                      let dest = result.floatChannelData?[ch] else { continue }
                memcpy(dest.advanced(by: Int(offset)), src, Int(frames) * MemoryLayout<Float>.size)
            }
            offset += frames
        }
        return result
    }

    func trimmed(to targetFrames: AVAudioFrameCount) -> AVAudioPCMBuffer {
        let clipped = min(targetFrames, frameLength)
        guard let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: clipped) else { return self }
        result.frameLength = clipped
        let channelCount = Int(format.channelCount)
        for ch in 0..<channelCount {
            guard let src = floatChannelData?[ch],
                  let dest = result.floatChannelData?[ch] else { continue }
            memcpy(dest, src, Int(clipped) * MemoryLayout<Float>.size)
        }
        return result
    }

    func padded(to targetFrames: AVAudioFrameCount) -> AVAudioPCMBuffer {
        guard targetFrames > frameLength,
              let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: targetFrames) else { return self }
        result.frameLength = targetFrames
        let channelCount = Int(format.channelCount)
        let srcBytes = Int(frameLength) * MemoryLayout<Float>.size
        let padBytes = Int(targetFrames - frameLength) * MemoryLayout<Float>.size
        for ch in 0..<channelCount {
            guard let src = floatChannelData?[ch],
                  let dest = result.floatChannelData?[ch] else { continue }
            memcpy(dest, src, srcBytes)
            memset(dest.advanced(by: Int(frameLength)), 0, padBytes)
        }
        return result
    }
}
