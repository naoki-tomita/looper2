import AVFoundation
import Accelerate

// Stores individual recording layers and produces a mixed-down buffer on demand.
// Layer 0 = first recording; top of stack = most recent overdub.
final class BufferStack {
    private var layers: [AVAudioPCMBuffer] = []
    let format: AVAudioFormat
    private var cachedMix: AVAudioPCMBuffer?

    static let maxLayers = 5

    init(format: AVAudioFormat) {
        self.format = format
    }

    var isEmpty: Bool { layers.isEmpty }
    var count: Int { layers.count }

    func push(_ buffer: AVAudioPCMBuffer) {
        if layers.count >= BufferStack.maxLayers {
            layers.removeFirst()
        }
        layers.append(buffer)
        cachedMix = nil
    }

    @discardableResult
    func popLayer() -> Bool {
        guard !layers.isEmpty else { return false }
        layers.removeLast()
        cachedMix = nil
        return !layers.isEmpty
    }

    func clear() {
        layers.removeAll()
        cachedMix = nil
    }

    var mixedBuffer: AVAudioPCMBuffer? {
        if let cached = cachedMix { return cached }
        guard let first = layers.first else { return nil }
        let mix = rebuildMix(frameCount: first.frameLength)
        cachedMix = mix
        return mix
    }

    private func rebuildMix(frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer {
        guard let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            fatalError("BufferStack: failed to allocate mix buffer")
        }
        result.frameLength = frameCount
        let channelCount = Int(format.channelCount)
        let length = vDSP_Length(frameCount)

        // Zero result
        for ch in 0..<channelCount {
            if let dest = result.floatChannelData?[ch] {
                vDSP_vclr(dest, 1, length)
            }
        }

        // Sum all layers using vDSP for efficiency
        for layer in layers {
            let layerLength = vDSP_Length(min(layer.frameLength, frameCount))
            for ch in 0..<channelCount {
                guard let src = layer.floatChannelData?[ch],
                      let dest = result.floatChannelData?[ch] else { continue }
                vDSP_vadd(dest, 1, src, 1, dest, 1, layerLength)
            }
        }

        // Soft-clip to prevent distortion when many layers are summed
        for ch in 0..<channelCount {
            guard let data = result.floatChannelData?[ch] else { continue }
            var peak: Float = 0
            vDSP_maxmgv(data, 1, &peak, length)
            if peak > 1.0 {
                var scale = 1.0 / peak
                vDSP_vsmul(data, 1, &scale, data, 1, length)
            }
        }

        return result
    }
}
