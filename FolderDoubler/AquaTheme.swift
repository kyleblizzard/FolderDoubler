// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import SwiftUI

// MARK: - Color Hex Initializer
// Lets us write Color(hex: "3AA9FF") instead of manually calculating RGB floats.
// Supports 6-digit (#RRGGBB) and 8-digit (#RRGGBBAA) hex strings.

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = (int >> 24 & 0xFF, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

// MARK: - AquaTheme
// Centralized design tokens based on the Modern Aqua Design Spec v1.1.
// All colors, spacing, radii, and shadows are defined here — nothing is
// invented at the component level. Resolves light/dark automatically
// from the current colorScheme.

struct AquaTheme {
    let colorScheme: ColorScheme

    var isDark: Bool { colorScheme == .dark }

    // MARK: Background Tokens
    // These define the five background tiers from the material model.

    /// App/window background — the base canvas everything sits on
    var bgBase: Color {
        isDark ? Color(hex: "111720") : Color(hex: "F2F5F9")
    }

    /// Frosted panel fill (Tier 2) — cards, sidebars, sections
    var bgSurface: Color {
        isDark ? Color(hex: "1C2636").opacity(0.82) : Color.white.opacity(0.72)
    }

    /// Elevated glass fill (Tier 3) — popovers, modals
    var bgElevated: Color {
        isDark ? Color(hex: "243044").opacity(0.92) : Color.white.opacity(0.88)
    }

    /// Control fill — button backgrounds, interactive surfaces
    var bgControl: Color {
        isDark ? Color.white.opacity(0.10) : Color.white.opacity(0.60)
    }

    /// Recessed fill — text field wells, inset areas
    var bgRecessed: Color {
        isDark ? Color.black.opacity(0.20) : Color(hex: "243446").opacity(0.06)
    }

    // MARK: Stroke Tokens

    /// Subtle border for panels and cards
    var strokeSubtle: Color {
        isDark ? Color.white.opacity(0.08) : Color(hex: "243446").opacity(0.10)
    }

    /// Button and control borders
    var strokeControl: Color {
        isDark ? Color.white.opacity(0.14) : Color(hex: "243446").opacity(0.16)
    }

    /// Focus ring color
    var strokeFocus: Color {
        isDark ? Color(hex: "3AA9FF").opacity(0.70) : Color(hex: "3AA9FF").opacity(0.80)
    }

    // MARK: Highlight & Shadow Tokens
    // These create the Aqua "lit from top-front" lighting effect.

    /// Top edge gleam — the bright highlight along the top of surfaces
    var highlightTop: Color {
        isDark ? Color.white.opacity(0.10) : Color.white.opacity(0.65)
    }

    /// Inner surface sheen
    var highlightInner: Color {
        isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.40)
    }

    /// Resting component shadow
    var shadowSoft: Color {
        isDark ? Color.black.opacity(0.30) : Color(hex: "243446").opacity(0.12)
    }

    /// Hover/lift shadow
    var shadowContact: Color {
        isDark ? Color.black.opacity(0.45) : Color(hex: "243446").opacity(0.20)
    }

    // MARK: Aqua Accent Tokens
    // The signature Aqua blue that gives the design its identity.

    /// Primary blue for active controls, selections, links
    var aquaPrimary: Color {
        isDark ? Color(hex: "409CFF") : Color(hex: "3AA9FF")
    }

    /// Deeper blue for pressed states and filled primary buttons
    var aquaDeep: Color {
        isDark ? Color(hex: "1A7FD4") : Color(hex: "0A84D6")
    }

    /// Soft blue glow for focus/selection ambient effects
    var aquaGlow: Color {
        isDark ? Color(hex: "409CFF").opacity(0.20) : Color(hex: "3AA9FF").opacity(0.22)
    }

    /// Toggle track on-state fill
    var aquaTrack: Color {
        isDark ? Color(hex: "409CFF").opacity(0.35) : Color(hex: "3AA9FF").opacity(0.30)
    }

    // MARK: Text Tokens

    /// Primary body text
    var textPrimary: Color {
        isDark ? Color(hex: "F0F6FF").opacity(0.92) : Color(hex: "0E1824").opacity(0.90)
    }

    /// Secondary/supporting text
    var textSecondary: Color {
        isDark ? Color(hex: "F0F6FF").opacity(0.55) : Color(hex: "0E1824").opacity(0.55)
    }

    /// Tertiary text — labels, hints, disabled
    var textTertiary: Color {
        isDark ? Color(hex: "F0F6FF").opacity(0.30) : Color(hex: "0E1824").opacity(0.35)
    }

    /// Link text
    var textLink: Color {
        isDark ? Color(hex: "409CFF") : Color(hex: "0A84D6")
    }

    /// Destructive/error text
    var textDestructive: Color {
        isDark ? Color(hex: "FF6961") : Color(hex: "D93025")
    }

    // MARK: Semantic Accent Colors

    static let accentMint  = Color(hex: "34C88A")
    static let accentAmber = Color(hex: "F5A623")
    static let accentRed   = Color(hex: "D93025")

    // MARK: Spacing Scale (base unit: 4pt)

    static let space1: CGFloat  = 4
    static let space2: CGFloat  = 8
    static let space3: CGFloat  = 12
    static let space4: CGFloat  = 16
    static let space5: CGFloat  = 20
    static let space6: CGFloat  = 24
    static let space8: CGFloat  = 32
    static let space10: CGFloat = 40
    static let space12: CGFloat = 48

    // MARK: Corner Radius Scale

    static let radiusSm: CGFloat   = 8    // tags, chips, compact buttons
    static let radiusMd: CGFloat   = 12   // standard controls
    static let radiusLg: CGFloat   = 16   // panels, cards
    static let radiusXl: CGFloat   = 22   // sheets, modals
    static let radiusPill: CGFloat = 999  // capsule shapes
}
