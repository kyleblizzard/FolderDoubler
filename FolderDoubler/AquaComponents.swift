// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import SwiftUI

// MARK: - Aqua Gel Button Style (Tier 5)
//
// This is the signature Aqua button — saturated blue fill with the six-layer
// lighting stack from the design spec (Section 3). Used for primary CTAs.
//
// The six layers (from back to front):
// 1. Base fill — solid aqua blue (or aqua deep when pressed)
// 2. Translucent overlay — subtle white wash to soften
// 3. Top highlight — gradient that creates the "lit from above" gel effect
// 4. Inner specular — (built into the gradient for simplicity)
// 5. Border — white outer stroke that defines the material edge
// 6. State glow — focus ring (handled by macOS focus system)
//
// The tint and tintDeep colors are configurable so this style can be
// reused for destructive (red) or custom-colored buttons.

struct AquaGelButtonStyle: ButtonStyle {
    /// The resting fill color (defaults to Aqua primary blue)
    var tint: Color = Color(hex: "3AA9FF")

    /// The pressed-state fill color (defaults to Aqua deep blue)
    var tintDeep: Color = Color(hex: "0A84D6")

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        AquaGelButtonBody(
            configuration: configuration,
            tint: tint,
            tintDeep: tintDeep,
            isEnabled: isEnabled
        )
    }
}

/// Inner view for AquaGelButtonStyle that tracks hover state.
/// ButtonStyle.makeBody only gives us isPressed — we need @State for hover.
private struct AquaGelButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color
    let tintDeep: Color
    let isEnabled: Bool

    @State private var isHovered = false

    private var isPressed: Bool { configuration.isPressed }

    var body: some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, AquaTheme.space5)
            .padding(.vertical, AquaTheme.space3)
            .frame(minWidth: 80)
            .background(fillStack)
            .clipShape(RoundedRectangle(cornerRadius: AquaTheme.radiusMd, style: .continuous))
            // Layer 5: Border — defines the material edge
            .overlay(
                RoundedRectangle(cornerRadius: AquaTheme.radiusMd, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )
            // Shadow: changes between resting, hover, and pressed
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: shadowRadius,
                y: shadowY
            )
            // Scale: 0.98 when pressed for tactile "push" feedback
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.4)
            // Micro spring for press (spec: response 0.18, damping 0.80)
            .animation(.spring(response: 0.18, dampingFraction: 0.80), value: isPressed)
            // Instant hover color change (spec: 100ms)
            .animation(.linear(duration: 0.10), value: isHovered)
            .onHover { hovering in isHovered = hovering }
    }

    // MARK: Layer Stack

    /// Layers 1-4: base fill + translucent overlay + top highlight + specular
    private var fillStack: some View {
        ZStack {
            // Layer 1: Base fill — aqua primary, deep when pressed, lightened on hover
            fillColor

            // Layer 2: Translucent white overlay to soften
            Color.white.opacity(isPressed ? 0.04 : 0.12)

            // Layer 3 & 4: Top highlight gradient (gel effect)
            LinearGradient(
                colors: [Color.white.opacity(highlightOpacity), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.55)
            )
        }
    }

    /// Resolves the current fill color based on press/hover state
    private var fillColor: Color {
        if isPressed { return tintDeep }
        if isHovered { return tint.opacity(0.92) }
        return tint
    }

    /// Highlight opacity: 45% resting, 55% hover, 20% pressed
    private var highlightOpacity: Double {
        if isPressed { return 0.20 }
        if isHovered { return 0.55 }
        return 0.45
    }

    // MARK: Shadow by State

    private var shadowOpacity: Double {
        if isPressed { return 0.05 }
        if isHovered { return 0.14 }
        return 0.10
    }

    private var shadowRadius: CGFloat {
        if isPressed { return 1 }
        if isHovered { return 6 }
        return 4
    }

    private var shadowY: CGFloat {
        if isPressed { return 0 }
        if isHovered { return 3 }
        return 2
    }
}

// MARK: - Aqua Secondary Button Style
//
// A frosted glass-like button for secondary actions (Cancel, Choose, etc.).
// Uses the control fill + top highlight + subtle border from the token system.
// This is a manual approximation of Tier 4 Liquid Glass for pre-Tahoe targets.

struct AquaSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        AquaSecondaryButtonBody(
            configuration: configuration,
            colorScheme: colorScheme,
            isEnabled: isEnabled
        )
    }
}

private struct AquaSecondaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let colorScheme: ColorScheme
    let isEnabled: Bool

    @State private var isHovered = false

    private var theme: AquaTheme { AquaTheme(colorScheme: colorScheme) }
    private var isPressed: Bool { configuration.isPressed }

    var body: some View {
        configuration.label
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, AquaTheme.space4)
            .padding(.vertical, AquaTheme.space2 + 2)
            .background(
                ZStack {
                    theme.bgControl
                    // Top highlight for depth
                    LinearGradient(
                        colors: [theme.highlightTop.opacity(0.5), Color.clear],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.4)
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AquaTheme.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AquaTheme.radiusMd, style: .continuous)
                    .strokeBorder(theme.strokeControl, lineWidth: 1)
            )
            .shadow(
                color: theme.shadowSoft,
                radius: isPressed ? 1 : (isHovered ? 4 : 2),
                y: isPressed ? 0 : (isHovered ? 2 : 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(.spring(response: 0.18, dampingFraction: 0.80), value: isPressed)
            .animation(.linear(duration: 0.10), value: isHovered)
            .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Aqua Panel Modifier
//
// Turns any view into a frosted Aqua panel (Tier 2 — Frosted Surface).
// Applies: regularMaterial background, top highlight gradient, subtle border,
// panel shadow, and rounded corners at --radius-lg (16pt).
//
// Usage: SomeView().aquaPanel()

struct AquaPanelModifier: ViewModifier {
    /// Configurable inner padding — defaults to space6 (24pt) for full windows,
    /// use space4 (16pt) or space3 (12pt) for compact layouts like menu bar popovers.
    var padding: CGFloat = AquaTheme.space6

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let theme = AquaTheme(colorScheme: colorScheme)

        content
            .padding(padding)
            .background(.regularMaterial)
            // Top highlight: white → clear over the top 30% of the panel
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(theme.isDark ? 0.06 : 0.40), Color.clear],
                    startPoint: .top,
                    endPoint: .init(x: 0.5, y: 0.3)
                )
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: AquaTheme.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AquaTheme.radiusLg, style: .continuous)
                    .strokeBorder(theme.strokeSubtle, lineWidth: 1)
            )
            .shadow(color: theme.shadowSoft, radius: 8, y: 4)
    }
}

extension View {
    /// Wraps this view in a frosted Aqua panel with top highlight, border, and shadow.
    /// Pass a smaller padding value for compact layouts (e.g. menu bar popovers).
    func aquaPanel(padding: CGFloat = AquaTheme.space6) -> some View {
        modifier(AquaPanelModifier(padding: padding))
    }
}

// MARK: - Aqua Recessed Field
//
// Mimics the recessed text field look from the spec (Section 4.5).
// Used for displaying folder paths — not an actual text input, but styled
// to look like an inset well for visual consistency.

struct AquaRecessedFieldModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let theme = AquaTheme(colorScheme: colorScheme)

        content
            .padding(.horizontal, AquaTheme.space3)
            .padding(.vertical, AquaTheme.space2)
            .background(theme.bgRecessed)
            .clipShape(RoundedRectangle(cornerRadius: AquaTheme.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AquaTheme.radiusMd, style: .continuous)
                    .strokeBorder(theme.strokeSubtle, lineWidth: 1)
            )
            // Inner top shadow for the "inset" effect
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.04), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: AquaTheme.radiusMd, style: .continuous))
            }
    }
}

extension View {
    /// Styles this view as a recessed well (like a text field background)
    func aquaRecessedField() -> some View {
        modifier(AquaRecessedFieldModifier())
    }
}

// MARK: - Aqua Status Badge
//
// A small pill-shaped indicator showing the sync status with a colored dot.
// Uses the Aqua glow color for active states, semantic colors for others.

struct AquaStatusBadge: View {
    let status: SyncStatus

    @Environment(\.colorScheme) private var colorScheme

    private var theme: AquaTheme { AquaTheme(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 6) {
            // Pulsing dot for active states
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(dotColor.opacity(0.4))
                        .frame(width: 14, height: 14)
                        .opacity(isPulsing ? 1 : 0)
                )
                .animation(
                    isPulsing
                        ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                        : .default,
                    value: isPulsing
                )

            Text(status.rawValue)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, AquaTheme.space3)
        .padding(.vertical, AquaTheme.space1 + 2)
        .background(dotColor.opacity(0.10))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(dotColor.opacity(0.20), lineWidth: 1)
        )
    }

    /// Maps status to a display color
    private var dotColor: Color {
        switch status {
        case .idle:       return theme.textTertiary
        case .monitoring: return AquaTheme.accentMint
        case .syncing:    return theme.aquaPrimary
        case .error:      return AquaTheme.accentRed
        }
    }

    /// Whether the dot should pulse (active states only)
    private var isPulsing: Bool {
        status == .monitoring || status == .syncing
    }
}

// MARK: - Aqua Section Header
//
// A small label styled as a section header per the spec:
// --type-label-sm (11pt medium, tracking +0.3), --color-text-tertiary

struct AquaSectionHeader: View {
    let title: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .tracking(0.3)
            .foregroundColor(AquaTheme(colorScheme: colorScheme).textTertiary)
    }
}

// MARK: - Aqua Popover Style
//
// Elevated glass panel (Tier 3) for popovers with the spec's shadow and radius.

struct AquaPopoverModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let theme = AquaTheme(colorScheme: colorScheme)

        content
            .padding(AquaTheme.space6)
            .background(.thinMaterial)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(theme.isDark ? 0.04 : 0.30), Color.clear],
                    startPoint: .top,
                    endPoint: .init(x: 0.5, y: 0.3)
                )
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: AquaTheme.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AquaTheme.radiusLg, style: .continuous)
                    .strokeBorder(theme.strokeSubtle, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 24, y: 8)
    }
}

extension View {
    /// Styles this view as an elevated Aqua popover
    func aquaPopover() -> some View {
        modifier(AquaPopoverModifier())
    }
}
