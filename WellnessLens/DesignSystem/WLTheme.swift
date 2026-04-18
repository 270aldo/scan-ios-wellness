import SwiftUI

enum WLPalette {
    static let tint = Color("AccentColor")
    static let canvas = Color(red: 0.996, green: 0.985, blue: 0.992)
    static let canvasWarm = Color(red: 0.991, green: 0.975, blue: 0.979)
    static let surface = Color.white.opacity(0.94)
    static let surfaceElevated = Color.white.opacity(0.985)
    static let surfaceMuted = Color(red: 0.973, green: 0.963, blue: 0.979)
    static let ink = Color(red: 0.135, green: 0.104, blue: 0.173)
    static let inkSoft = Color(red: 0.453, green: 0.415, blue: 0.490)
    static let stroke = Color.black.opacity(0.055)
    static let strokeStrong = Color.black.opacity(0.095)
    static let blush = Color(red: 0.985, green: 0.824, blue: 0.882)
    static let lavender = Color(red: 0.854, green: 0.814, blue: 0.985)
    static let rose = Color(red: 0.922, green: 0.454, blue: 0.653)
    static let lilac = Color(red: 0.640, green: 0.566, blue: 0.946)
    static let success = Color(red: 0.281, green: 0.656, blue: 0.485)
    static let caution = Color(red: 0.808, green: 0.506, blue: 0.262)
}

enum WLSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum WLCorner {
    static let pill: CGFloat = 18
    static let m: CGFloat = 20
    static let secondary: CGFloat = 24
    static let l: CGFloat = 28
    static let xl: CGFloat = 34
}

enum WLGradient {
    static let hero = LinearGradient(
        colors: [
            WLPalette.rose,
            Color(red: 0.791, green: 0.493, blue: 0.925),
            WLPalette.lilac
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let shellGlow = LinearGradient(
        colors: [
            WLPalette.canvasWarm,
            WLPalette.canvas,
            Color.white
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let blushSurface = LinearGradient(
        colors: [
            Color.white.opacity(0.98),
            WLPalette.canvasWarm
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

enum WLTypography {
    static let hero = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title2, design: .rounded, weight: .bold)
    static let section = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.system(.body, design: .rounded)
    static let bodyEmphasis = Font.system(.body, design: .rounded, weight: .medium)
    static let caption = Font.system(.footnote, design: .rounded)
    static let captionStrong = Font.system(.footnote, design: .rounded, weight: .semibold)
    static let metric = Font.system(size: 34, weight: .bold, design: .rounded)
    static let lensMetric = Font.system(size: 32, weight: .bold, design: .rounded)
}

struct WLLiquidGlassPolicy {
    let isEnabled: Bool

    init(
        reduceTransparency: Bool,
        colorSchemeContrast: ColorSchemeContrast
    ) {
        if #available(iOS 26, *) {
            isEnabled = !reduceTransparency && colorSchemeContrast != .increased
        } else {
            isEnabled = false
        }
    }
}

enum WLElevation {
    static let shadow = Color(red: 0.498, green: 0.328, blue: 0.492).opacity(0.12)
    static let heroShadow = Color(red: 0.524, green: 0.338, blue: 0.594).opacity(0.24)
}

enum WLProductCopy {
    static let promise = "A calmer read on what you eat, apply, and repeat."

    enum Tabs {
        static let home = "Home"
        static let history = "History"
        static let scan = "Scan"
        static let checkIn = "Check-In"
        static let profile = "Profile"
    }

    enum Home {
        static let latestReadTitle = "Latest read"
        static let latestReadSubtitle = "Your clearest read right now, framed so you know what matters first."
        static let weeklySignalsTitle = "Weekly signals"
        static let weeklySignalsSubtitle = "The patterns your recent reads and check-ins are starting to reinforce."
        static let prioritiesTitle = "Current priorities"
        static let prioritiesSubtitle = "The goals WellnessLens should keep favoring when it frames a product read."
        static let sampleReadsTitle = "Sample reads"
        static let sampleReadsSubtitle = "A few guided examples that show how a read will feel before you scan more often."
        static let emptyTitle = "A personal read, from pantry to vanity."
        static let emptySubtitle = "WellnessLens turns everyday product choices into clear, personal wellness reads."
    }

    enum Scan {
        static let title = "Scan"
        static let heroTitle = "Bring a product in. WellnessLens will make it legible."
        static let heroSubtitle = "Start with the cleanest input you have. The app will turn that capture into a calm, personal read."
        static let primaryTitle = "Primary path"
        static let primarySubtitle = "Use the camera or a sharp label photo when you want the clearest read fastest."
        static let otherWaysTitle = "Other ways to scan"
        static let otherWaysSubtitle = "Fallbacks for when the product is not nearby, the barcode does not resolve, or the label needs manual help."
        static let sampleReadsTitle = "Sample reads"
        static let sampleReadsSubtitle = "Examples that show how WellnessLens interprets food, supplements, and skincare."
    }

    enum ProductRead {
        static let title = "Product read"
        static let lensReadTitle = "Lens read"
        static let lensReadSubtitle = "A directional view across the five WellnessLens lenses."
        static let reasonsTitle = "Why it landed here"
        static let reasonsSubtitle = "The ingredients, tags, and context that shaped the read most."
        static let watchoutsTitle = "Watchouts"
        static let watchoutsSubtitle = "Keep these in mind before making this a repeat purchase."
        static let swapsTitle = "Softer swaps"
        static let swapsSubtitle = "Nearby alternatives that look stronger in your priority lenses."
    }

    enum History {
        static let title = "Your scan memory"
        static let emptyTitle = "No reads yet"
        static let emptySubtitle = "Your memory starts building with the first product you scan, so signals can become smarter over time."
        static let compareReadySubtitle = "Two reads selected. Compare them when you want to see the tradeoff clearly."
        static let defaultSubtitle = "Reopen past reads, save favorites, and compare the choices that are shaping your routine."
    }

    enum CheckIn {
        static let title = "Check-In"
        static let heroTitle = "Capture how today felt in under a minute."
        static let heroSubtitle = "A quick reflection makes each future read more personal and helps signals become more honest."
    }

    enum Profile {
        static let yourLensTitle = "Your lens"
        static let yourLensSubtitle = "This is the context WellnessLens uses to decide what to favor, soften, and watch more closely."
        static let goalsSubtitle = "Goals, frictions, and sensitivities should stay consistent everywhere the app speaks."
        static let membershipTitle = "Membership"
        static let howItWorksTitle = "How WellnessLens works"
        static let howItWorksSubtitle = "A simple explanation of what shapes your reads and why the guidance feels personal."
    }

    enum Onboarding {
        static let heroTitle = "WellnessLens learns how to read for you."
        static let heroSubtitle = "A short calibration so your first product read already feels clear, personal, and calm."
        static let stepOneTitle = "What should WellnessLens optimize first?"
        static let stepOneSubtitle = "Choose the outcomes that should shape your first reads. Goals are the only required signal here."
        static let stepOneSectionTitle = "Goals"
        static let stepOneContextTitle = "What happens next"
        static let stepOneContextBody = "WellnessLens uses your goals to build `ActiveGoal`, seed the first-week plan, and tune Home before the first scan lands."

        static let stepTwoTitle = "Where should WellnessLens be gentler?"
        static let stepTwoSubtitle = "Shape the first read around the friction that matters most. You can tighten the rest later from Profile."
        static let stepTwoPrimaryTitle = "Current frictions"
        static let stepTwoPrimarySubtitle = "Choose the real-life problems that should stay visible in recommendations."
        static let stepTwoSensitivitiesTitle = "Sensitivities"
        static let stepTwoSensitivitiesSubtitle = "Bias the app toward caution when these are in play."
        static let stepTwoSkinConcernsTitle = "Skin concerns"
        static let stepTwoSkinConcernsSubtitle = "Optional, but useful when nutrition, supplement, and topical reads begin to overlap."

        static let stepThreeTitle = "How does your routine actually work?"
        static let stepThreeSubtitle = "Keep it realistic. This step tunes your daily rhythm without turning setup into a long form."
        static let stepFourTitle = "What should matter most day to day?"
        static let stepFourSubtitle = "Daily priorities sharpen the Daily Brief and help the app choose which tradeoff to explain first."
        static let stepFourSectionTitle = "Daily priorities"
        static let stepFourContextTitle = "Default if skipped"
        static let stepFourContextBody = "WellnessLens keeps `Energy` as the fallback anchor so the product never lands on an empty priority state."

        static let stepFiveTitle = "How should the product personalize?"
        static let stepFiveSubtitle = "Consent and tone are part of the experience. Keep what helps and skip the rest of the noise."
        static let stepFiveGuidanceTitle = "Guidance style"
        static let stepFiveMemoryTitle = "What memory means here"
        static let stepFiveMemoryBody = "It stores goals, routines, product decisions, body-signal notes, and strategist takeaways so Home feels more contextual over time."

        static let summaryTitle = "You’re calibrated enough to start from a real point of view."
        static let summarySubtitle = "Review the setup, edit anything quickly, and land on the first useful action instead of a dead end."
        static let summaryHeroBadge = "Primary focus"
        static let summaryGoalsTitle = "Goals and sensitivities"
        static let summaryGoalsEyebrow = "Priority profile"
        static let summaryRoutineTitle = "Routine context"
        static let summaryRoutineEyebrow = "Daily shape"
        static let summaryPrioritiesTitle = "Daily priorities"
        static let summaryPrioritiesEyebrow = "Always favor"
        static let summaryConsentTitle = "Personalization and consent"
        static let summaryConsentEyebrow = "Guardrails"
        static let summaryLoopTitle = "Your first-week loop"
    }

    enum ProfileEditor {
        static let goalsTitle = "Goals"
        static let goalsSubtitle = "The outcomes Home and the strategist should favor first."
        static let frictionsTitle = "Current frictions"
        static let frictionsSubtitle = "The friction that should stay visible in recommendations and follow-ups."
        static let sensitivitiesTitle = "Sensitivities"
        static let sensitivitiesSubtitle = "Bias the app toward caution when these are in play."
        static let routineTitle = "Routine and guidance"
        static let routineSubtitle = "Tune how the strategist should reason about your day-to-day reality."
        static let prioritiesTitle = "Daily priorities"
        static let prioritiesSubtitle = "These should sharpen the Daily Brief and the assistant voice."
        static let skinConcernsTitle = "Skin concerns"
        static let skinConcernsSubtitle = "Optional, but useful when nutrition-first decisions extend into topical choices."
    }
}

struct WLScreenBackground: View {
    var body: some View {
        ZStack {
            WLGradient.shellGlow.ignoresSafeArea()

            Image("HeroPearl")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.42)
                .blendMode(.softLight)
                .accessibilityHidden(true)

            Image("SoftNoise")
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()
                .opacity(0.10)
                .blendMode(.softLight)
                .accessibilityHidden(true)
        }
    }
}

struct WLScreen<Content: View>: View {
    private let content: Content
    private let alignment: HorizontalAlignment

    init(alignment: HorizontalAlignment = .leading, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: alignment, spacing: WLSpacing.xl) {
                content
            }
            .padding(.horizontal, WLSpacing.l)
            .padding(.vertical, WLSpacing.l)
        }
        .background(WLScreenBackground())
    }
}

struct WLCardModifier: ViewModifier {
    let fill: AnyShapeStyle
    let stroke: Color
    let shadowColor: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(stroke)
            )
            .shadow(color: shadowColor, radius: 20, x: 0, y: 12)
    }
}

extension View {
    func wlCardSurface(
        fill: some ShapeStyle = WLGradient.blushSurface,
        stroke: Color = WLPalette.stroke,
        shadowColor: Color = WLElevation.shadow,
        radius: CGFloat = WLCorner.l
    ) -> some View {
        modifier(
            WLCardModifier(
                fill: AnyShapeStyle(fill),
                stroke: stroke,
                shadowColor: shadowColor,
                radius: radius
            )
        )
    }
}
