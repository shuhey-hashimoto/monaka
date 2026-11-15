import SwiftUI

/// 「集中」と「静寂」：黒・濃いグレー＋紺（システム要件定義書 5.4）。
enum Theme {
    static let background = Color(hex: 0x0B0D12)
    static let surface = Color(hex: 0x12151C)
    static let border = Color(hex: 0x1C202A)
    static let track = Color(hex: 0x1C212D)

    static let accent = Color(hex: 0x3E6FC9)
    static let accentBright = Color(hex: 0x7FA2E0)

    static let textPrimary = Color(hex: 0xE8EAF0)
    static let textSecondary = Color(hex: 0x9AA1AF)
    static let textTertiary = Color(hex: 0x8A91A0)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
