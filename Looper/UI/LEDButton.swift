import SwiftUI

struct LEDButton: View {
    let label: String
    let ledColor: Color
    let isActive: Bool
    let isBlinking: Bool
    let action: () -> Void

    @State private var blinkPhase = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                // LED dot
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: isActive ? ledColor.opacity(0.8) : .clear, radius: 4)

                // Button body
                RoundedRectangle(cornerRadius: 7)
                    .fill(DesignTokens.buttonRaised)
                    .overlay(
                        Text(label)
                            .font(DesignTokens.labelFont)
                            .foregroundColor(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(DesignTokens.borderSubtle, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 2)
                    .frame(width: 64, height: 44)
            }
        }
        .buttonStyle(.plain)
        .onAppear { if isBlinking { startBlink() } }
        .onChange(of: isBlinking) { newValue in
            if newValue { startBlink() } else { blinkPhase = false }
        }
    }

    private var dotColor: Color {
        guard isActive else { return DesignTokens.ledDim }
        if isBlinking { return blinkPhase ? ledColor : .clear }
        return ledColor
    }

    private func startBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { timer in
            guard isBlinking else { timer.invalidate(); return }
            blinkPhase.toggle()
        }
    }
}
