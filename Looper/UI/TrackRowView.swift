import SwiftUI

struct TrackRowView: View {
    @ObservedObject var track: TrackModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Track number badge
                Text("\(track.id.number)")
                    .font(DesignTokens.trackNumFont)
                    .foregroundColor(stateAccentColor.opacity(0.7))
                    .frame(width: 22)

                // Level meter
                LevelMeterView(level: track.level)
                    .frame(width: 5, height: 44)

                // State stripe
                RoundedRectangle(cornerRadius: 2)
                    .fill(stateAccentColor)
                    .frame(width: 3, height: 44)

                Spacer()

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
                .stroke(stateAccentColor.opacity(0.25), lineWidth: 1)
        )
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
        case .empty:       return DesignTokens.ledDim.opacity(0.3)
        case .recording:   return DesignTokens.ledRed
        case .playing:     return DesignTokens.ledGreen
        case .muted:       return DesignTokens.ledBlue
        case .overdubbing: return DesignTokens.ledAmber
        }
    }
}
