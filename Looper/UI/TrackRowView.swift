import SwiftUI

struct TrackRowView: View {
    @ObservedObject var track: TrackModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Track number badge
                Text("\(track.id.number)")
                    .font(DesignTokens.trackNumFont)
                    .foregroundColor(stateAccentColor.opacity(0.8))
                    .frame(width: 22)

                // Level meter
                LevelMeterView(level: track.level)
                    .frame(width: 5, height: 44)

                // State stripe
                RoundedRectangle(cornerRadius: 2)
                    .fill(stateAccentColor)
                    .frame(width: 3, height: 44)

                // State label (center area) — shows REC timer or loop info
                stateInfoView
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Undo button + layer count badge
                ZStack(alignment: .topTrailing) {
                    LEDButton(
                        label: "UNDO",
                        ledColor: DesignTokens.ledAmber,
                        isActive: track.layerCount > 0,
                        isBlinking: false,
                        action: { track.tapUndo() }
                    )
                    if track.layerCount > 1 {
                        Text("\(track.layerCount)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(3)
                            .background(DesignTokens.ledAmber)
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }

                // Mute button
                LEDButton(
                    label: "MUTE",
                    ledColor: DesignTokens.ledBlue,
                    isActive: track.state == .muted,
                    isBlinking: false,
                    action: { track.tapMute() }
                )

                // Primary REC/DUB/STOP button
                LEDButton(
                    label: recLabel,
                    ledColor: recLedColor,
                    isActive: track.state != .empty,
                    isBlinking: track.state == .recording || track.state == .overdubbing,
                    action: { track.tapRec() }
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(DesignTokens.trackSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(stateAccentColor.opacity(track.state == .empty ? 0.1 : 0.5), lineWidth: 1)
        )
    }

    // Center area: shows what this track is doing right now
    @ViewBuilder
    private var stateInfoView: some View {
        switch track.state {
        case .empty:
            Text("--")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(DesignTokens.ledDim)

        case .recording:
            HStack(spacing: 6) {
                // Big blinking red dot — unmistakable recording indicator
                RecordingDot()
                VStack(alignment: .leading, spacing: 1) {
                    Text("REC")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundColor(DesignTokens.ledRed)
                    Text(String(format: "%.1f s", track.recordingSeconds))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(DesignTokens.ledRed.opacity(0.8))
                        .monospacedDigit()
                }
            }

        case .playing:
            VStack(alignment: .leading, spacing: 1) {
                Text("PLAY")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignTokens.ledGreen)
                Text("\(track.layerCount) layer\(track.layerCount == 1 ? "" : "s")")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DesignTokens.ledGreen.opacity(0.6))
            }

        case .muted:
            VStack(alignment: .leading, spacing: 1) {
                Text("MUTED")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignTokens.ledBlue)
                Text("\(track.layerCount) layer\(track.layerCount == 1 ? "" : "s")")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DesignTokens.ledBlue.opacity(0.6))
            }

        case .overdubbing:
            HStack(spacing: 6) {
                RecordingDot(color: DesignTokens.ledAmber)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DUB")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundColor(DesignTokens.ledAmber)
                    Text(String(format: "+%.1f s", track.recordingSeconds))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(DesignTokens.ledAmber.opacity(0.8))
                        .monospacedDigit()
                }
            }
        }
    }

    private var recLabel: String {
        switch track.state {
        case .empty:       return "REC"
        case .recording:   return "STOP"
        case .playing:     return "DUB"
        case .muted:       return "DUB"
        case .overdubbing: return "STOP"
        }
    }

    private var recLedColor: Color {
        switch track.state {
        case .recording:   return DesignTokens.ledRed
        case .overdubbing: return DesignTokens.ledAmber
        case .playing:     return DesignTokens.ledGreen
        case .muted:       return DesignTokens.ledBlue
        default:           return DesignTokens.ledDim
        }
    }

    private var stateAccentColor: Color {
        switch track.state {
        case .empty:       return DesignTokens.ledDim
        case .recording:   return DesignTokens.ledRed
        case .playing:     return DesignTokens.ledGreen
        case .muted:       return DesignTokens.ledBlue
        case .overdubbing: return DesignTokens.ledAmber
        }
    }
}

// Animating red dot that pulses while recording
private struct RecordingDot: View {
    var color: Color = DesignTokens.ledRed
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .shadow(color: color, radius: pulsing ? 6 : 2)
            .scaleEffect(pulsing ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}
