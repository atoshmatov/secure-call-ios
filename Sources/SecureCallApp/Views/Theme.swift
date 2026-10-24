import SwiftUI

// ==========================================
// 💎 PREMIUM DARK LUXURY PALETTE (UNIFIED iOS & ANDROID)
// ==========================================

public extension Color {
    // Backgrounds & Surfaces
    static let premiumBg = Color(hex: 0x0C0E12)              // Deep Space Charcoal
    static let premiumSurface = Color(hex: 0x14171E)         // Frosted Dark Graphite
    static let premiumCard = Color(hex: 0x1A1E26)            // Card background
    static let premiumCardElevated = Color(hex: 0x222733)    // Hover / Active Card
    static let premiumBorder = Color.white.opacity(0.10)     // Translucent Hairline Glass Border (10%)
    static let premiumBorderSubtle = Color.white.opacity(0.05)// Ultra subtle divider (5%)

    // Refined Accents (Restrained luxury, no harsh neons)
    static let sapphireBlue = Color(hex: 0x3B82F6)           // Royal Sapphire
    static let sapphireBlueDark = Color(hex: 0x1D4ED8)
    static let nordicEmerald = Color(hex: 0x10B981)          // Security Verified Emerald
    static let nordicEmeraldMuted = Color(hex: 0x10B981).opacity(0.12)
    static let velvetRose = Color(hex: 0xE11D48)             // Crimson Hangup Red
    static let velvetRoseMuted = Color(hex: 0xE11D48).opacity(0.15)
    static let amberWarm = Color(hex: 0xF59E0B)              // Warm Amber Ringing

    // Text Hierarchy
    static let textPrimary = Color(hex: 0xF8FAFC)            // Crisp Pure Off-White
    static let textSecondary = Color(hex: 0x94A3B8)          // Balanced Slate Muted
    static let textTertiary = Color(hex: 0x64748B)           // De-emphasized Caption

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
