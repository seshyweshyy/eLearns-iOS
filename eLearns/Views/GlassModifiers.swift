import SwiftUI

// MARK: - Glass panel (replaces .ultraThinMaterial backgrounds on floating cards)
//
// iOS 26+  → real Liquid Glass via .glassEffect()
// iOS 16–25 → .ultraThinMaterial fallback (looks identical to before)

struct GlassPanelModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Frosted glass panel (thicker, less transparent — for sheets/modals)

struct GlassFrostedModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.tint(.primary.opacity(0.08)), in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    func glassFrosted(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassFrostedModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass circle button (replaces .ultraThinMaterial + Circle() on icon buttons)

struct GlassCircleButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: Circle())
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}

// MARK: - Glass button (replaces .ultraThinMaterial on action buttons like "Preview")

struct GlassButtonModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.glass)
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Glass pill button style
// iOS 26+  → .glassEffect on a Capsule with interactive press morphing
// iOS 16–25 → .ultraThinMaterial + scale press animation

struct GlassPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            configuration.label
                .glassEffect(
                    .regular.interactive(),
                    in: Capsule()
                )
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .animation(.spring(duration: 0.2), value: configuration.isPressed)
        } else {
            configuration.label
                .background(.ultraThinMaterial, in: Capsule())
                .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                .opacity(configuration.isPressed ? 0.85 : 1.0)
                .animation(.spring(duration: 0.2), value: configuration.isPressed)
        }
    }
}

// MARK: - Convenience extensions

extension View {
    func glassPanel(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }

    func glassCircleButton() -> some View {
        modifier(GlassCircleButtonModifier())
    }

    func glassButton(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassButtonModifier(cornerRadius: cornerRadius))
    }
}

extension ButtonStyle where Self == GlassPillButtonStyle {
    static var glassPill: GlassPillButtonStyle { GlassPillButtonStyle() }
}

// MARK: - Interactive glass circle button style

struct GlassCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            configuration.label
                .glassEffect(
                    .regular.interactive(),
                    in: Circle()
                )
                .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
                .animation(.spring(duration: 0.2), value: configuration.isPressed)
        } else {
            configuration.label
                .background(.ultraThinMaterial, in: Circle())
                .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
                .opacity(configuration.isPressed ? 0.8 : 1.0)
                .animation(.spring(duration: 0.2), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == GlassCircleButtonStyle {
    static var glassCircle: GlassCircleButtonStyle { GlassCircleButtonStyle() }
}

// MARK: - Interactive glass rounded rectangle button style

struct GlassRoundedButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            configuration.label
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(duration: 0.2), value: configuration.isPressed)
        } else {
            configuration.label
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .opacity(configuration.isPressed ? 0.85 : 1.0)
                .animation(.spring(duration: 0.2), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == GlassRoundedButtonStyle {
    static var glassRounded: GlassRoundedButtonStyle { GlassRoundedButtonStyle() }
    static func glassRounded(cornerRadius: CGFloat) -> GlassRoundedButtonStyle {
        GlassRoundedButtonStyle(cornerRadius: cornerRadius)
    }
}
