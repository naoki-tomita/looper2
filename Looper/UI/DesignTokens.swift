import SwiftUI

enum DesignTokens {
    // Backgrounds
    static let background    = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let trackSurface  = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let borderSubtle  = Color(white: 0.22)

    // LED accent colors (Boss RC / hardware looper aesthetic)
    static let ledRed        = Color(red: 1.00, green: 0.15, blue: 0.10)
    static let ledGreen      = Color(red: 0.18, green: 0.92, blue: 0.35)
    static let ledAmber      = Color(red: 1.00, green: 0.65, blue: 0.00)
    static let ledBlue       = Color(red: 0.25, green: 0.55, blue: 1.00)
    static let ledDim        = Color(white: 0.28)

    // Buttons
    static let buttonRaised  = Color(red: 0.20, green: 0.20, blue: 0.23)
    static let buttonDanger  = Color(red: 0.30, green: 0.10, blue: 0.10)

    // Typography
    static let labelFont     = Font.system(.caption, design: .monospaced).weight(.semibold)
    static let trackNumFont  = Font.system(.headline, design: .monospaced).weight(.black)
    static let monoBody      = Font.system(.body, design: .monospaced)
}
