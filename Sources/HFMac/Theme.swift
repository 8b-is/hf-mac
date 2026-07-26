import SwiftUI

/// The pocoo.vaked.dev palette — near-black blue ground, cyan accent, mono type,
/// enhanced with native macOS glass materials and liquid vibrancy.
enum Theme {
    static let bg      = Color(hex: 0x070B16)
    static let surface = Color(hex: 0x0A0A14)
    static let card    = Color(hex: 0x14141F)
    static let fg      = Color(hex: 0xE0E8F5)
    static let accent  = Color(hex: 0x00D4FF)
    static let green   = Color(hex: 0x00E660)
    static let dim     = Color(hex: 0x6878A0)
    static let border  = Color(hex: 0x26304A)
    static let warn    = Color(hex: 0xFFB020)

    // MARK: - Native macOS Glass Materials
    static let glassMaterial: Material = .ultraThinMaterial
    static let glassBarMaterial: Material = .thinMaterial
    static let glassBorder = Color.white.opacity(0.12)
    static let glassBorderHighlight = Color(hex: 0x00D4FF).opacity(0.35)
    static let glassGlow = Color(hex: 0x00D4FF).opacity(0.15)

    /// Uppercase mono micro-label, pocoo style.
    static func eyebrow(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(.caption2, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Theme.dim)
    }
}

extension Color {
    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}
