import SwiftUI

struct WLIcon: View {
    let systemName: String
    var color: Color = WLPalette.ink
    var size: CGFloat = 16
    var weight: Font.Weight = .semibold

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: weight, design: .rounded))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
    }
}

enum WLAdaptiveGlassShape {
    case capsule
    case roundedRect(CGFloat)
}

struct WLHeroGlassGroup<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = WLSpacing.s, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    private var policy: WLLiquidGlassPolicy {
        WLLiquidGlassPolicy(
            reduceTransparency: reduceTransparency,
            colorSchemeContrast: colorSchemeContrast
        )
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26, *), policy.isEnabled {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

struct WLAdaptiveGlassSurface<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private let shape: WLAdaptiveGlassShape
    private let tint: Color?
    private let interactive: Bool
    private let fallbackFill: AnyShapeStyle
    private let fallbackStroke: Color
    private let fallbackShadowColor: Color
    private let fallbackShadowRadius: CGFloat
    private let fallbackShadowY: CGFloat
    private let content: Content

    init(
        shape: WLAdaptiveGlassShape,
        tint: Color? = nil,
        interactive: Bool = false,
        fallbackFill: some ShapeStyle,
        fallbackStroke: Color,
        fallbackShadowColor: Color = .clear,
        fallbackShadowRadius: CGFloat = 0,
        fallbackShadowY: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.shape = shape
        self.tint = tint
        self.interactive = interactive
        self.fallbackFill = AnyShapeStyle(fallbackFill)
        self.fallbackStroke = fallbackStroke
        self.fallbackShadowColor = fallbackShadowColor
        self.fallbackShadowRadius = fallbackShadowRadius
        self.fallbackShadowY = fallbackShadowY
        self.content = content()
    }

    private var policy: WLLiquidGlassPolicy {
        WLLiquidGlassPolicy(
            reduceTransparency: reduceTransparency,
            colorSchemeContrast: colorSchemeContrast
        )
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26, *), policy.isEnabled {
            glassBody
        } else {
            fallbackBody
        }
    }

    @available(iOS 26, *)
    @ViewBuilder
    private var glassBody: some View {
        switch shape {
        case .capsule:
            content
                .glassEffect(configuredGlass, in: .capsule)
        case let .roundedRect(radius):
            content
                .glassEffect(configuredGlass, in: .rect(cornerRadius: radius))
        }
    }

    @ViewBuilder
    private var fallbackBody: some View {
        switch shape {
        case .capsule:
            content
                .background(
                    Capsule(style: .continuous)
                        .fill(fallbackFill)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(fallbackStroke)
                )
                .shadow(color: fallbackShadowColor, radius: fallbackShadowRadius, x: 0, y: fallbackShadowY)
        case let .roundedRect(radius):
            content
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(fallbackFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(fallbackStroke)
                )
                .shadow(color: fallbackShadowColor, radius: fallbackShadowRadius, x: 0, y: fallbackShadowY)
        }
    }

    @available(iOS 26, *)
    private var configuredGlass: Glass {
        var glass = Glass.regular

        if let tint {
            glass = glass.tint(tint)
        }

        if interactive {
            glass = glass.interactive()
        }

        return glass
    }
}

struct WLSurfaceCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    init(padding: CGFloat = WLSpacing.l, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .wlCardSurface()
    }
}

struct WLPrimaryCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        WLSurfaceCard(content: { content })
    }
}

struct WLCompactCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(WLSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .wlCardSurface(
                fill: LinearGradient(
                    colors: [Color.white.opacity(0.98), WLPalette.surfaceMuted],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                shadowColor: WLElevation.shadow.opacity(0.35),
                radius: WLCorner.m
            )
    }
}

struct WLSecondarySurfaceCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .wlCardSurface(style: .secondary, radius: WLCorner.secondary)
    }
}

struct WLQuietCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    init(padding: CGFloat = WLSpacing.l, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .wlCardSurface(style: .quiet, radius: WLCorner.secondary)
    }
}

struct WLFeatureCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    init(padding: CGFloat = WLSpacing.l, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .wlCardSurface(style: .emphasis, radius: WLCorner.secondary)
    }
}

struct WLHeroSurface<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    init(padding: CGFloat = WLSpacing.xl, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: WLCorner.xl, style: .continuous)
                        .fill(WLGradient.hero)

                    Image("HeroPearl")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.42)
                        .blendMode(.screen)
                        .clipShape(RoundedRectangle(cornerRadius: WLCorner.xl, style: .continuous))
                        .accessibilityHidden(true)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: WLCorner.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.18))
            )
            .shadow(color: WLElevation.heroShadow, radius: 30, x: 0, y: 18)
    }
}

struct WLHeroCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    init(padding: CGFloat = WLSpacing.xl, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        WLHeroSurface(padding: padding, content: { content })
    }
}

struct WLSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.xs) {
            if let systemImage {
                HStack(spacing: WLSpacing.xs) {
                    WLIcon(systemName: systemImage, color: WLPalette.rose, size: 14)
                    Text(title)
                        .font(WLTypography.section)
                        .foregroundStyle(WLPalette.ink)
                }
            } else {
                Text(title)
                    .font(WLTypography.section)
                    .foregroundStyle(WLPalette.ink)
            }

            if let subtitle {
                Text(subtitle)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct WLDisclosureCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var statusTitle: String? = nil
    var systemImage: String? = nil
    var isExpanded: Bool
    let action: () -> Void

    private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        statusTitle: String? = nil,
        systemImage: String? = nil,
        isExpanded: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.statusTitle = statusTitle
        self.systemImage = systemImage
        self.isExpanded = isExpanded
        self.action = action
        self.content = content()
    }

    var body: some View {
        WLSecondarySurfaceCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                Button(action: action) {
                    ViewThatFits(in: .horizontal) {
                        headerRow
                        headerStack
                    }
                }
                .buttonStyle(.plain)

                if let subtitle {
                    Text(subtitle)
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isExpanded {
                    content
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: WLSpacing.s) {
            titleBlock
            Spacer(minLength: WLSpacing.s)
            accessoryBlock
        }
    }

    private var headerStack: some View {
        VStack(alignment: .leading, spacing: WLSpacing.s) {
            titleBlock
            accessoryBlock
        }
    }

    private var titleBlock: some View {
        HStack(spacing: WLSpacing.xs) {
            if let systemImage {
                WLIcon(systemName: systemImage, color: WLPalette.rose, size: 14)
            }

            Text(title)
                .font(WLTypography.bodyEmphasis)
                .foregroundStyle(WLPalette.ink)
                .multilineTextAlignment(.leading)
        }
    }

    private var accessoryBlock: some View {
        HStack(spacing: WLSpacing.xs) {
            if let statusTitle {
                WLPill(title: statusTitle, tone: isExpanded ? .accent : .soft)
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(WLPalette.inkSoft)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isExpanded)
        }
    }
}

struct WLPill: View {
    enum Style {
        case standard
        case heroGlass
    }

    enum Tone {
        case neutral
        case accent
        case soft

        var fill: AnyShapeStyle {
            switch self {
            case .neutral:
                AnyShapeStyle(Color.white.opacity(0.88))
            case .accent:
                AnyShapeStyle(
                    LinearGradient(
                        colors: [WLPalette.rose.opacity(0.18), WLPalette.lavender.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case .soft:
                AnyShapeStyle(WLPalette.surfaceMuted.opacity(0.9))
            }
        }

        var stroke: Color {
            switch self {
            case .neutral:
                WLPalette.stroke
            case .accent:
                WLPalette.rose.opacity(0.18)
            case .soft:
                WLPalette.stroke
            }
        }

        var foreground: Color {
            switch self {
            case .neutral, .soft:
                WLPalette.ink
            case .accent:
                WLPalette.rose
            }
        }
    }

    let title: String
    var tone: Tone = .neutral
    var style: Style = .standard

    var body: some View {
        switch style {
        case .standard:
            ViewThatFits(in: .horizontal) {
                standardCapsuleBody
                standardWrappedBody
            }
        case .heroGlass:
            ViewThatFits(in: .horizontal) {
                heroGlassCapsuleBody
                heroGlassWrappedBody
            }
        }
    }

    private var heroGlassTint: Color {
        switch tone {
        case .neutral, .soft:
            return Color.white.opacity(0.14)
        case .accent:
            return WLPalette.rose.opacity(0.20)
        }
    }

    private var standardCapsuleBody: some View {
        pillText(foreground: tone.foreground, lineLimit: 1, alignment: .center)
            .padding(.horizontal, WLSpacing.m)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.fill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tone.stroke)
            )
    }

    private var standardWrappedBody: some View {
        pillText(foreground: tone.foreground, lineLimit: 2, alignment: .leading)
            .padding(.horizontal, WLSpacing.s)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tone.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tone.stroke)
            )
    }

    private var heroGlassCapsuleBody: some View {
        WLAdaptiveGlassSurface(
            shape: .capsule,
            tint: heroGlassTint,
            fallbackFill: Color.white.opacity(0.12),
            fallbackStroke: Color.white.opacity(0.12)
        ) {
            pillText(foreground: .white, lineLimit: 1, alignment: .center)
                .padding(.horizontal, WLSpacing.m)
                .padding(.vertical, 10)
        }
    }

    private var heroGlassWrappedBody: some View {
        WLAdaptiveGlassSurface(
            shape: .roundedRect(14),
            tint: heroGlassTint,
            fallbackFill: Color.white.opacity(0.12),
            fallbackStroke: Color.white.opacity(0.12)
        ) {
            pillText(foreground: .white, lineLimit: 2, alignment: .leading)
                .padding(.horizontal, WLSpacing.s)
                .padding(.vertical, 10)
        }
    }

    private func pillText(
        foreground: Color,
        lineLimit: Int,
        alignment: TextAlignment
    ) -> some View {
        Text(title)
            .font(WLTypography.captionStrong)
            .foregroundStyle(foreground)
            .lineLimit(lineLimit)
            .minimumScaleFactor(lineLimit == 1 ? 0.82 : 0.90)
            .allowsTightening(true)
            .multilineTextAlignment(alignment)
    }
}

struct WLStatusBadge: View {
    enum Style {
        case standard
        case heroGlass
    }

    enum Tone {
        case accent
        case success
        case caution

        var fill: LinearGradient {
            switch self {
            case .accent:
                LinearGradient(
                    colors: [WLPalette.rose.opacity(0.18), WLPalette.lavender.opacity(0.28)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .success:
                LinearGradient(
                    colors: [WLPalette.success.opacity(0.18), Color.white.opacity(0.95)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .caution:
                LinearGradient(
                    colors: [WLPalette.caution.opacity(0.18), Color.white.opacity(0.95)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }

        var foreground: Color {
            switch self {
            case .accent:
                WLPalette.rose
            case .success:
                WLPalette.success
            case .caution:
                WLPalette.caution
            }
        }
    }

    let title: String
    var systemImage: String? = nil
    var tone: Tone = .accent
    var style: Style = .standard

    var body: some View {
        switch style {
        case .standard:
            ViewThatFits(in: .horizontal) {
                standardCapsuleBody
                standardWrappedBody
            }
        case .heroGlass:
            ViewThatFits(in: .horizontal) {
                heroGlassCapsuleBody
                heroGlassWrappedBody
            }
        }
    }

    private var standardCapsuleBody: some View {
        badgeLabel(foreground: tone.foreground, lineLimit: 1, alignment: .center)
            .padding(.horizontal, WLSpacing.s)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.fill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tone.foreground.opacity(0.10))
            )
    }

    private var standardWrappedBody: some View {
        badgeLabel(foreground: tone.foreground, lineLimit: 2, alignment: .leading)
            .padding(.horizontal, WLSpacing.s)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tone.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tone.foreground.opacity(0.10))
            )
    }

    private var heroGlassCapsuleBody: some View {
        WLAdaptiveGlassSurface(
            shape: .capsule,
            tint: tone.foreground.opacity(0.18),
            fallbackFill: Color.white.opacity(0.12),
            fallbackStroke: Color.white.opacity(0.12)
        ) {
            badgeLabel(foreground: .white, lineLimit: 1, alignment: .center)
                .padding(.horizontal, WLSpacing.s)
                .padding(.vertical, 10)
        }
    }

    private var heroGlassWrappedBody: some View {
        WLAdaptiveGlassSurface(
            shape: .roundedRect(14),
            tint: tone.foreground.opacity(0.18),
            fallbackFill: Color.white.opacity(0.12),
            fallbackStroke: Color.white.opacity(0.12)
        ) {
            badgeLabel(foreground: .white, lineLimit: 2, alignment: .leading)
                .padding(.horizontal, WLSpacing.s)
                .padding(.vertical, 10)
        }
    }

    private func badgeLabel(
        foreground: Color,
        lineLimit: Int,
        alignment: TextAlignment
    ) -> some View {
        HStack(spacing: WLSpacing.xs) {
            if let systemImage {
                WLIcon(systemName: systemImage, color: foreground, size: 13)
            }

            Text(title)
                .font(WLTypography.captionStrong)
                .lineLimit(lineLimit)
                .minimumScaleFactor(lineLimit == 1 ? 0.82 : 0.90)
                .allowsTightening(true)
                .multilineTextAlignment(alignment)
        }
        .foregroundStyle(foreground)
    }
}

struct WLLensTile: View {
    let score: LensScore
    var showSummary = true

    private var band: WLStatusBadge.Tone {
        switch score.score {
        case 82...:
            .success
        case 66...:
            .accent
        default:
            .caution
        }
    }

    private var descriptor: String {
        switch score.score {
        case 82...:
            "Strong fit"
        case 66...:
            "Solid fit"
        case 50...:
            "Mixed fit"
        default:
            "Soft caution"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            HStack(alignment: .top, spacing: WLSpacing.s) {
                HStack(spacing: WLSpacing.s) {
                    WLIcon(systemName: score.lens.icon, color: band.foreground, size: 14)

                    Text(score.lens.title)
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(WLPalette.ink)
                        .lineLimit(2)
                }

                Spacer(minLength: WLSpacing.xs)

                WLPill(title: descriptor, tone: descriptorTone)
            }

            VStack(alignment: .leading, spacing: WLSpacing.xs) {
                Text("\(score.score)")
                    .font(WLTypography.lensMetric)
                    .foregroundStyle(WLPalette.ink)
                    .contentTransition(.numericText())

                Text(scoreBandTitle)
                    .font(WLTypography.caption)
                    .foregroundStyle(band.foreground)
            }

            if showSummary {
                Text(score.summary)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .leading)
        .padding(WLSpacing.l)
        .wlCardSurface(style: score.score >= 82 ? .emphasis : .quiet)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: score.score)
    }

    private var descriptorTone: WLPill.Tone {
        switch score.score {
        case 82...:
            .accent
        case 66...:
            .soft
        default:
            .neutral
        }
    }

    private var scoreBandTitle: String {
        switch score.score {
        case 82...:
            "High support"
        case 66...:
            "Useful support"
        case 50...:
            "Mixed support"
        default:
            "Needs caution"
        }
    }
}

enum WLButtonWidth {
    case fill
    case fit
}

struct WLPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WLTypography.bodyEmphasis)
            .foregroundStyle(Color.white)
            .padding(.horizontal, WLSpacing.m)
            .padding(.vertical, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WLPalette.rose,
                                Color(red: 0.862, green: 0.436, blue: 0.700)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.14))
            )
            .shadow(color: WLElevation.heroShadow.opacity(configuration.isPressed ? 0.10 : 0.20), radius: configuration.isPressed ? 10 : 22, x: 0, y: configuration.isPressed ? 6 : 14)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.84), value: configuration.isPressed)
    }
}

struct WLSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WLTypography.bodyEmphasis)
            .foregroundStyle(WLPalette.ink)
            .padding(.horizontal, WLSpacing.m)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.78 : 0.90))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(WLPalette.strokeStrong)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.84), value: configuration.isPressed)
    }
}

struct WLUtilityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WLTypography.captionStrong)
            .foregroundStyle(WLPalette.ink)
            .padding(.horizontal, WLSpacing.s)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.74 : 0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(WLPalette.strokeStrong)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.84), value: configuration.isPressed)
    }
}

enum WLButtonChromeStyle {
    case standard
    case heroPrimary
    case heroSecondary
}

struct WLPrimaryButton: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let title: String
    var systemImage: String? = nil
    var chrome: WLButtonChromeStyle = .standard
    let action: () -> Void

    var body: some View {
        let policy = WLLiquidGlassPolicy(
            reduceTransparency: reduceTransparency,
            colorSchemeContrast: colorSchemeContrast
        )

        switch chrome {
        case .standard, .heroSecondary:
            Button(action: action) {
                label(foreground: .white)
            }
            .buttonStyle(WLPrimaryButtonStyle())
        case .heroPrimary:
            if #available(iOS 26, *), policy.isEnabled {
                Button(action: action) {
                    label(foreground: .white)
                }
                .buttonStyle(GlassProminentButtonStyle())
            } else {
                Button(action: action) {
                    label(foreground: .white)
                }
                .buttonStyle(WLPrimaryButtonStyle())
            }
        }
    }

    private func label(foreground: Color) -> some View {
        HStack(spacing: WLSpacing.s) {
            if let systemImage {
                WLIcon(systemName: systemImage, color: foreground, size: 15)
            }

            Text(title)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .multilineTextAlignment(.center)
                .allowsTightening(true)
        }
        .font(WLTypography.bodyEmphasis)
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, minHeight: 56)
    }
}

struct WLSecondaryButton: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let title: String
    var systemImage: String? = nil
    var chrome: WLButtonChromeStyle = .standard
    var width: WLButtonWidth = .fit
    let action: () -> Void

    var body: some View {
        let policy = WLLiquidGlassPolicy(
            reduceTransparency: reduceTransparency,
            colorSchemeContrast: colorSchemeContrast
        )

        switch chrome {
        case .standard, .heroPrimary:
            Button(action: action) {
                label(foreground: WLPalette.ink)
            }
            .buttonStyle(WLSecondaryButtonStyle())
        case .heroSecondary:
            if #available(iOS 26, *), policy.isEnabled {
                Button(action: action) {
                    label(foreground: .white)
                }
                .buttonStyle(GlassButtonStyle())
            } else {
                Button(action: action) {
                    label(foreground: WLPalette.ink)
                }
                .buttonStyle(WLSecondaryButtonStyle())
            }
        }
    }

    private func label(foreground: Color) -> some View {
        HStack(spacing: WLSpacing.s) {
            if let systemImage {
                WLIcon(systemName: systemImage, color: foreground, size: 15)
            }

            Text(title)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .multilineTextAlignment(.center)
                .allowsTightening(true)
        }
        .font(WLTypography.bodyEmphasis)
        .foregroundStyle(foreground)
        .frame(maxWidth: width == .fill ? .infinity : nil, minHeight: 48)
    }
}

struct WLUtilityButton: View {
    let title: String
    var systemImage: String? = nil
    var width: WLButtonWidth = .fit
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WLSpacing.xs) {
                if let systemImage {
                    WLIcon(systemName: systemImage, color: WLPalette.ink, size: 13)
                }

                Text(title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                    .allowsTightening(true)
                    .multilineTextAlignment(.center)
            }
            .font(WLTypography.captionStrong)
            .foregroundStyle(WLPalette.ink)
            .frame(maxWidth: width == .fill ? .infinity : nil, minHeight: 36)
        }
        .buttonStyle(WLUtilityButtonStyle())
    }
}

struct WLActionGroup<Content: View>: View {
    private let alignment: HorizontalAlignment
    private let content: () -> Content

    init(alignment: HorizontalAlignment = .leading, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: WLSpacing.s) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: alignment, spacing: WLSpacing.s) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WLSelectionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WLSpacing.s) {
                Text(title)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(isSelected ? WLPalette.rose : WLPalette.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.88)
                    .allowsTightening(true)

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? WLPalette.rose : WLPalette.strokeStrong)
            }
            .padding(.horizontal, WLSpacing.m)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [WLPalette.rose.opacity(0.12), WLPalette.lavender.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.94), WLPalette.canvasWarm],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                    .stroke(isSelected ? WLPalette.rose.opacity(0.18) : WLPalette.stroke)
            )
        }
        .buttonStyle(.plain)
    }
}

struct WLTabBar: View {
    @Binding var selection: AppTab
    let tabs: [AppTab]

    var body: some View {
        HStack(alignment: .bottom, spacing: WLSpacing.s) {
            ForEach(tabs, id: \.self) { tab in
                WLTabItem(
                    tab: tab,
                    isSelected: selection == tab,
                    action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selection = tab
                        }
                    }
                )
            }
        }
        .padding(.horizontal, WLSpacing.s)
        .padding(.top, WLSpacing.xs)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.62))
        )
        .shadow(color: WLElevation.shadow.opacity(0.55), radius: 18, x: 0, y: 10)
    }
}

private struct WLTabItem: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                WLIcon(
                    systemName: tab.icon,
                    color: foregroundColor,
                    size: tab.visualPriority == .primary ? 18 : 16,
                    weight: isSelected ? .bold : .semibold
                )

                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: tab.visualPriority == .primary ? 58 : 50)
            .padding(.horizontal, tab.visualPriority == .primary ? WLSpacing.s : 0)
            .background(backgroundShape)
            .offset(y: tab.visualPriority == .primary ? -4 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }

    private var foregroundColor: Color {
        switch tab.visualPriority {
        case .primary:
            return isSelected ? .white : WLPalette.rose
        case .standard:
            return isSelected ? WLPalette.rose : WLPalette.inkSoft
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch tab.visualPriority {
        case .primary:
            Capsule(style: .continuous)
                .fill(
                    isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [WLPalette.rose, Color(red: 0.862, green: 0.436, blue: 0.700)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [WLPalette.rose.opacity(0.10), WLPalette.lavender.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.18) : WLPalette.rose.opacity(0.12))
                )
                .shadow(color: WLElevation.heroShadow.opacity(isSelected ? 0.20 : 0.08), radius: isSelected ? 18 : 10, x: 0, y: isSelected ? 12 : 6)
        case .standard:
            Capsule(style: .continuous)
                .fill(isSelected ? WLPalette.rose.opacity(0.10) : Color.clear)
        }
    }
}

#Preview("Primitives") {
    WLScreen {
        WLHeroSurface {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLStatusBadge(title: "Editorial Skincare", systemImage: "sparkles")
                Text("Inside-out clarity")
                    .font(WLTypography.hero)
                    .foregroundStyle(.white)
                Text("A premium, feminine scan ritual that still feels native to iOS.")
                    .font(WLTypography.body)
                    .foregroundStyle(Color.white.opacity(0.9))
                WLPrimaryButton(title: "Open scan", systemImage: "viewfinder") {}
            }
        }

        WLSurfaceCard {
            WLSectionHeader(title: "Lens tile")
            WLLensTile(
                score: LensScore(
                    lens: .energyMood,
                    score: 86,
                    summary: "Protein-forward ingredients support a steadier, calmer energy curve."
                )
            )
        }
    }
}
