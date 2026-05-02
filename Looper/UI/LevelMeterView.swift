import SwiftUI

struct LevelMeterView: View {
    let level: Float    // 0.0 – 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.12))

                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(height: geo.size.height * CGFloat(min(level, 1.0)))
            }
        }
    }

    private var barColor: Color {
        if level > 0.85 { return DesignTokens.ledRed }
        if level > 0.55 { return DesignTokens.ledAmber }
        return DesignTokens.ledGreen
    }
}

// Loop position progress bar shown at the bottom of each track row
struct LoopPositionBar: View {
    let progress: Double   // 0.0 – 1.0; 0 if no loop running

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(white: 0.15))
                    .frame(height: 2)

                Rectangle()
                    .fill(DesignTokens.ledGreen.opacity(0.7))
                    .frame(width: geo.size.width * CGFloat(min(progress, 1.0)), height: 2)
            }
        }
        .frame(height: 2)
    }
}
