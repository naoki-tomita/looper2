import SwiftUI

struct MasterControlBar: View {
    @ObservedObject var session: LoopSession

    var body: some View {
        HStack(spacing: 16) {
            // Loop length / BPM display
            VStack(alignment: .leading, spacing: 3) {
                Text("LOOP LENGTH")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(DesignTokens.ledDim)
                    .tracking(1)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(loopLengthText)
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text("sec")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(DesignTokens.ledDim)
                }
            }

            Spacer()

            // STOP ALL
            Button(action: { session.masterStop() }) {
                Label("STOP ALL", systemImage: "stop.fill")
                    .font(DesignTokens.labelFont)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(DesignTokens.buttonDanger)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.ledRed.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            // CLEAR
            Button(action: { session.masterClear() }) {
                Text("CLEAR")
                    .font(DesignTokens.labelFont)
                    .foregroundColor(DesignTokens.ledDim)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(DesignTokens.buttonRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var loopLengthText: String {
        guard let frames = session.loopClock.masterFrameCount else { return "--.-" }
        let seconds = Double(frames) / session.loopClock.sampleRate
        return String(format: "%.1f", seconds)
    }
}
