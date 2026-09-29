import SwiftUI

/// An equal-width Liquid Glass tile with the icon above a short title.
///
/// Rows of tiles fill the available width and share one height, so a group of
/// actions always lines up whatever their titles are.
struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TileButtonBody(configuration: configuration)
    }
}

private struct TileButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .labelStyle(TileLabelStyle())
            .foregroundStyle(configuration.role == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .contentShape(.rect(cornerRadius: 14))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

private struct TileLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 5) {
            configuration.icon
                .font(.system(size: 15, weight: .medium))
                .frame(height: 17)
            configuration.title
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 4)
    }
}

/// A small, equal-width Liquid Glass capsule with the icon beside the title,
/// for compact rows of actions such as the menu bar panel's, or at a large
/// control size, for a sheet's buttons. A destructive
/// one is red, since it only confirms something that can't be undone; a
/// prominent one takes the accent color, for the action a row is there for.
struct GlassCapsuleButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        GlassCapsuleButtonBody(configuration: configuration, isProminent: isProminent)
    }
}

private struct GlassCapsuleButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isProminent: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    private var isLarge: Bool { controlSize >= .large }

    private var tint: Color? {
        if configuration.role == .destructive { return .red }
        return isProminent ? .accentColor : nil
    }

    var body: some View {
        configuration.label
            .labelStyle(CapsuleLabelStyle(isLarge: isLarge))
            .foregroundStyle(tint == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
            .frame(maxWidth: .infinity)
            .frame(height: isLarge ? 34 : 28)
            .contentShape(.capsule)
            .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

private struct CapsuleLabelStyle: LabelStyle {
    let isLarge: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: isLarge ? 5 : 4) {
            configuration.icon
                .font(.system(size: isLarge ? 12 : 10, weight: .semibold))
            configuration.title
                .font((isLarge ? Font.body : .subheadline).weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
    }
}

/// A round Liquid Glass button that shows only its icon.
struct GlassIconButtonStyle: ButtonStyle {
    var diameter: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        GlassIconButtonBody(configuration: configuration, diameter: diameter)
    }
}

private struct GlassIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let diameter: CGFloat
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: diameter * 0.42, weight: .semibold))
            .foregroundStyle(configuration.role == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            .frame(width: diameter, height: diameter)
            .contentShape(.circle)
            .glassEffect(.regular.interactive(), in: .circle)
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

extension ButtonStyle where Self == TileButtonStyle {
    static var tile: TileButtonStyle { TileButtonStyle() }
}

extension ButtonStyle where Self == GlassCapsuleButtonStyle {
    static var glassCapsule: GlassCapsuleButtonStyle { GlassCapsuleButtonStyle() }
    static func glassCapsule(prominent: Bool) -> GlassCapsuleButtonStyle { GlassCapsuleButtonStyle(isProminent: prominent) }
}

extension ButtonStyle where Self == GlassIconButtonStyle {
    static var glassIcon: GlassIconButtonStyle { GlassIconButtonStyle() }
    static func glassIcon(diameter: CGFloat) -> GlassIconButtonStyle { GlassIconButtonStyle(diameter: diameter) }
}
