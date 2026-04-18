import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    @State private var strategistEntryPoint: StrategistEntryPoint?
    @State private var showPantry = false
    @State private var contextExpanded = false
    @State private var sampleReadsExpanded = false

    private var payload: DailyHomePayload {
        model.dailyHomePayload
    }

    private var brief: DailyBrief {
        model.dailyBrief
    }

    private var surfaceContract: DailyHomePayloadV2 {
        model.dailyHomePayloadV2
    }

    private var latestVerdictSurface: ScanVerdictSurfaceContent? {
        model.latestVerdict.map(ScanVerdictSurfaceContent.build)
    }

    var body: some View {
        WLScreen {
            HomeDailyHero(
                payload: payload,
                primaryGoal: model.activeGoals.first,
                primaryAction: handleNextAction,
                secondaryActionTitle: heroSecondaryActionTitle,
                secondaryActionSystemImage: heroSecondaryActionSystemImage,
                secondaryAction: handleHeroSecondaryAction
            )

            if model.isUsingLocalHomeFallback {
                HomeFallbackStateCard(
                    title: "Showing the local daily fallback",
                    summary: "Home is using the deterministic local brief while the remote refresh catches up. Your goals, plan, gating, and saved memory are still applied."
                )
            }

            if let latestVerdictSurface {
                HomeLatestVerdictCard(
                    content: latestVerdictSurface,
                    openHistory: {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                            model.selectedTab = .history
                        }
                    },
                    openScan: openScan
                )
            }

            HomeSignalSection(payload: payload, saveCheckIn: openCheckIn)

            if let primaryModule = surfaceContract.primaryModule {
                moduleSection(primaryModule)
            }

            if !surfaceContract.secondaryModules.isEmpty {
                HomeMoreContextCard(
                    moduleTitles: surfaceContract.secondaryModules.map(\.title),
                    whyNow: surfaceContract.hero.whyNow,
                    deferredCount: surfaceContract.deferredModules.count,
                    isExpanded: $contextExpanded
                )
            }

            if contextExpanded {
                ForEach(surfaceContract.secondaryModules) { module in
                    moduleSection(module)
                }
            }
        }
        .navigationTitle("Today")
        .sheet(item: $strategistEntryPoint) { entryPoint in
            StrategistChatView(entryPoint: entryPoint)
        }
        .sheet(isPresented: $showPantry) {
            PantryView()
        }
    }

    private var heroSecondaryActionTitle: String {
        switch payload.nextAction.kind {
        case .askStrategist:
            "Open scan"
        default:
            "Ask strategist"
        }
    }

    private var heroSecondaryActionSystemImage: String {
        switch payload.nextAction.kind {
        case .askStrategist:
            "viewfinder"
        default:
            "message"
        }
    }

    private func handleNextAction() {
        switch payload.nextAction.kind {
        case .scanStaple, .swapProduct:
            openScan()
        case .checkInNow:
            openCheckIn()
        case .askStrategist:
            strategistEntryPoint = .home
        case .repeatProduct:
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                model.selectedTab = .history
            }
        case .tidyRoutine:
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                model.selectedTab = .profile
            }
        }
    }

    private func handleDailyBriefAction() {
        switch brief.cta.kind {
        case .scanBreakfast, .scanSnack, .mealSnapshot:
            openScan()
        case .updateFeedback:
            openCheckIn()
        case .openHistory:
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                model.selectedTab = .history
            }
        }
    }

    private func handleHeroSecondaryAction() {
        switch payload.nextAction.kind {
        case .askStrategist:
            openScan()
        default:
            strategistEntryPoint = .home
        }
    }

    private func openScan() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            model.selectedTab = .scan
        }
    }

    private func openCheckIn() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            model.selectedTab = .checkIn
        }
    }

    private func runScenario(_ scenario: DemoScenario) {
        Task {
            await model.runDemoScenario(scenario)
        }
    }

    @ViewBuilder
    private func moduleSection(_ module: HomeSurfaceModule) -> some View {
        switch module {
        case .firstWeekPlan:
            if let firstWeekPlan = model.firstWeekPlan {
                HomeFirstWeekPlanSection(firstWeekPlan: firstWeekPlan)
            }
        case .dailyBrief:
            HomeDailyBriefCard(
                brief: brief,
                primaryAction: handleDailyBriefAction
            )
        case .activeGoals:
            HomeGoalsSection(goals: model.activeGoals)
        case .recommendedSwap:
            if let recommendedSwap = payload.recommendedSwap {
                HomeRecommendedSwapCard(
                    suggestion: recommendedSwap,
                    openScan: openScan,
                    askStrategist: { strategistEntryPoint = .scan }
                )
            }
        case .openLoops:
            HomeOpenLoopsSection(
                openLoops: payload.openLoops,
                openCheckIn: openCheckIn,
                openHistory: {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        model.selectedTab = .history
                    }
                }
            )
        case .recentWins:
            HomeRecentWinsSection(recentWins: payload.recentWins)
        case .strategistNote:
            HomeStrategistNoteCard(
                note: payload.strategistNote,
                openStrategist: { strategistEntryPoint = .home }
            )
        case .routineMemory:
            HomeRoutineSection(routines: model.routines)
        case .pantry:
            HomePantrySection(
                items: Array(model.visiblePantryItems.prefix(3)),
                suggestions: model.hasAccess(to: .pantrySuggestions) ? model.pantrySuggestions : [],
                isUnlocked: model.hasAccess(to: .pantryMVP),
                openPantry: {
                    showPantry = true
                }
            )
        case .sampleReads:
            HomeSampleReadsSection(
                packs: model.demoScenarioPacks,
                isExpanded: $sampleReadsExpanded,
                runScenario: runScenario
            )
        }
    }
}

private struct HomePantrySection: View {
    let items: [PantryItem]
    let suggestions: [PantrySuggestion]
    let isUnlocked: Bool
    let openPantry: () -> Void

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Pantry",
                    subtitle: "Keep stronger defaults visible before convenience takes over.",
                    systemImage: "shippingbox"
                )

                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text(item.title)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text(item.summary)
                            .font(WLTypography.caption)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }

                let hasSuggestion = !suggestions.isEmpty

                if isUnlocked, let suggestion = suggestions.first {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Next pantry move")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.rose)

                        Text(suggestion.summary)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                } else if let supportingMessage = PantryPresentationCopy.supportingMessage(
                    isUnlocked: isUnlocked,
                    hasSuggestion: hasSuggestion
                ) {
                    Text(supportingMessage)
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)
                }

                WLUtilityButton(
                    title: isUnlocked ? "Open pantry" : "Preview pantry",
                    systemImage: isUnlocked ? "arrow.up.right.circle" : "shippingbox"
                ) {
                    openPantry()
                }
            }
        }
    }
}

private struct HomeMoreContextCard: View {
    let moduleTitles: [String]
    let whyNow: String
    let deferredCount: Int
    @Binding var isExpanded: Bool

    private var modulePreview: String {
        let preview = Array(moduleTitles.prefix(3))
        if preview.isEmpty {
            return "Keep the extra context close, but not in the way."
        }

        let joined = preview.joined(separator: ", ")
        if moduleTitles.count > 3 || deferredCount > 0 {
            return "Queued now: \(joined), and a little more only if today's first decision changes."
        }
        return "Queued now: \(joined)."
    }

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "More for today",
                    subtitle: whyNow,
                    systemImage: "square.stack.3d.up"
                )

                Text(modulePreview)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)

                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: WLSpacing.s) {
                        Text(isExpanded ? "Hide extra context" : "Show extra context")
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Spacer(minLength: 0)

                        WLIcon(
                            systemName: isExpanded ? "chevron.up" : "chevron.down",
                            color: WLPalette.rose,
                            size: 14
                        )
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct HomeDailyBriefCard: View {
    let brief: DailyBrief
    let primaryAction: () -> Void

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Daily Brief",
                    subtitle: "What matters before the next real decision.",
                    systemImage: "sunrise"
                )

                VStack(alignment: .leading, spacing: WLSpacing.xs) {
                    Text(brief.headline)
                        .font(WLTypography.title)
                        .foregroundStyle(WLPalette.ink)

                    Text(brief.riskHeadline)
                        .font(WLTypography.body)
                        .foregroundStyle(WLPalette.inkSoft)
                }

                HStack(spacing: WLSpacing.s) {
                    WLPill(title: "Priority: \(brief.nutritionPriority)", tone: .neutral)
                    WLStatusBadge(title: "Today", systemImage: "scope", tone: .accent)
                }

                Text(brief.cta.subtitle)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)

                WLPrimaryButton(
                    title: brief.cta.title,
                    systemImage: "arrow.up.right.circle"
                ) {
                    primaryAction()
                }
            }
        }
    }
}

private struct HomeDailyHero: View {
    let payload: DailyHomePayload
    let primaryGoal: ActiveGoal?
    let primaryAction: () -> Void
    let secondaryActionTitle: String
    let secondaryActionSystemImage: String
    let secondaryAction: () -> Void

    var body: some View {
        WLHeroSurface {
            VStack(alignment: .leading, spacing: WLSpacing.l) {
                ViewThatFits(in: .vertical) {
                    HStack(spacing: WLSpacing.s) {
                        heroStatusBadges
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        heroStatusBadges
                    }
                }

                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    Text(payload.todayFocus.title)
                        .font(WLTypography.hero)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(payload.todayFocus.summary)
                        .font(WLTypography.body)
                        .foregroundStyle(Color.white.opacity(0.90))
                        .fixedSize(horizontal: false, vertical: true)
                }

                WLHeroGlassGroup {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: WLSpacing.s) {
                            metricCard(title: "Body signal", value: payload.bodySignal.title)
                            metricCard(title: "Next action", value: payload.nextAction.title)
                        }

                        VStack(spacing: WLSpacing.s) {
                            metricCard(title: "Body signal", value: payload.bodySignal.title)
                            metricCard(title: "Next action", value: payload.nextAction.title)
                        }
                    }
                }

                WLActionGroup {
                    WLPrimaryButton(
                        title: payload.nextAction.cta,
                        systemImage: "arrow.up.right.circle",
                        chrome: .heroPrimary
                    ) {
                        primaryAction()
                    }

                    WLSecondaryButton(
                        title: secondaryActionTitle,
                        systemImage: secondaryActionSystemImage,
                        chrome: .heroSecondary
                    ) {
                        secondaryAction()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var heroStatusBadges: some View {
        WLStatusBadge(
            title: payload.state.title,
            systemImage: stateSymbol,
            tone: stateTone,
            style: .heroGlass
        )

        if let primaryGoal {
            WLPill(title: primaryGoal.focusMetric, tone: .neutral, style: .heroGlass)
        }
    }

    private var stateTone: WLStatusBadge.Tone {
        switch payload.state {
        case .active:
            .success
        case .drifting, .reengagement:
            .caution
        case .unonboarded, .calibrating:
            .accent
        }
    }

    private var stateSymbol: String {
        switch payload.state {
        case .active:
            "sparkles"
        case .drifting:
            "arrow.clockwise"
        case .reengagement:
            "bolt.heart"
        case .unonboarded, .calibrating:
            "scope"
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        WLAdaptiveGlassSurface(
            shape: .roundedRect(WLCorner.m),
            tint: Color.black.opacity(0.16),
            fallbackFill: Color.black.opacity(0.20),
            fallbackStroke: Color.white.opacity(0.08)
        ) {
            VStack(alignment: .leading, spacing: WLSpacing.xs) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.80))

                Text(value)
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WLSpacing.m)
            .padding(.vertical, 14)
        }
    }
}

private struct HomeFallbackStateCard: View {
    let title: String
    let summary: String

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                WLStatusBadge(title: "Fallback active", systemImage: "icloud.slash", tone: .caution)

                Text(title)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text(summary)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
            }
        }
    }
}

private struct HomeLatestVerdictCard: View {
    let content: ScanVerdictSurfaceContent
    let openHistory: () -> Void
    let openScan: () -> Void

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: WLProductCopy.Home.latestReadTitle,
                    subtitle: WLProductCopy.Home.latestReadSubtitle,
                    systemImage: "sparkles.rectangle.stack"
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: content.fitTitle,
                            systemImage: content.fit.symbol,
                            tone: content.fit.badgeTone
                        )

                        WLPill(title: content.productName, tone: .soft)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: content.fitTitle,
                            systemImage: content.fit.symbol,
                            tone: content.fit.badgeTone
                        )

                        WLPill(title: content.productName, tone: .soft)
                    }
                }

                Text(content.headline)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text(content.primaryReason)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                if let betterSwapTitle = content.betterSwapTitle,
                   let betterSwapReason = content.betterSwapReason {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Better swap")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.ink)

                        Text("\(betterSwapTitle) looks softer because \(betterSwapReason)")
                            .font(WLTypography.caption)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                } else if let followUpPrompt = content.followUpPrompt {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Track later")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.rose)

                        Text(followUpPrompt)
                            .font(WLTypography.caption)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }

                WLActionGroup {
                    WLPrimaryButton(title: "Scan again", systemImage: "viewfinder") {
                        openScan()
                    }

                    WLUtilityButton(title: "Open history", systemImage: "clock.arrow.circlepath") {
                        openHistory()
                    }
                }
            }
        }
    }
}

private struct HomeSignalSection: View {
    let payload: DailyHomePayload
    let saveCheckIn: () -> Void

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Body signal",
                    subtitle: "Use today's body signal as the lens for the next decision.",
                    systemImage: "waveform.path.ecg"
                )

                WLStatusBadge(
                    title: payload.bodySignal.title,
                    systemImage: "heart.text.square",
                    tone: tone
                )

                Text(payload.bodySignal.summary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                WLUtilityButton(title: "Update check-in", systemImage: "heart.text.square") {
                    saveCheckIn()
                }
            }
        }
    }

    private var tone: WLStatusBadge.Tone {
        switch payload.bodySignal.tone {
        case .supportive:
            .success
        case .caution:
            .caution
        case .neutral:
            .accent
        }
    }
}

private struct HomeFirstWeekPlanSection: View {
    let firstWeekPlan: FirstWeekPlan

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: firstWeekPlan.title,
                subtitle: firstWeekPlan.summary,
                systemImage: "calendar"
            )

            ForEach(firstWeekPlan.steps) { step in
                WLCompactCard {
                    HStack(alignment: .top, spacing: WLSpacing.s) {
                        WLIcon(
                            systemName: step.isComplete ? "checkmark.circle.fill" : "circle.dashed",
                            color: step.isComplete ? WLPalette.success : WLPalette.rose,
                            size: 18
                        )

                        VStack(alignment: .leading, spacing: WLSpacing.xs) {
                            Text(step.title)
                                .font(WLTypography.bodyEmphasis)
                                .foregroundStyle(WLPalette.ink)

                            Text(step.detail)
                                .font(WLTypography.body)
                                .foregroundStyle(WLPalette.inkSoft)
                        }
                    }
                }
            }
        }
    }
}

private struct HomeGoalsSection: View {
    let goals: [ActiveGoal]

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Active goals",
                subtitle: "These goals should steer Home, scans, and strategist.",
                systemImage: "target"
            )

            ForEach(goals) { goal in
                WLCompactCard {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        HStack(spacing: WLSpacing.s) {
                            WLStatusBadge(
                                title: goal.status == .active ? "Active" : goal.status.rawValue.capitalized,
                                systemImage: "sparkles",
                                tone: goal.status == .active ? .accent : .success
                            )

                            WLPill(title: goal.focusMetric, tone: .soft)
                        }

                        Text(goal.title)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text(goal.summary)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)

                        Text(goal.milestone.title)
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.rose)

                        Text(goal.milestone.detail)
                            .font(WLTypography.caption)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }
            }
        }
    }
}

private struct HomeRecommendedSwapCard: View {
    let suggestion: AlternativeSuggestion
    let openScan: () -> Void
    let askStrategist: () -> Void

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Recommended swap",
                    subtitle: "The app found a softer alternative worth keeping in view.",
                    systemImage: "arrow.triangle.2.circlepath"
                )

                Text(suggestion.productName)
                    .font(WLTypography.title)
                    .foregroundStyle(WLPalette.ink)

                Text(suggestion.whyBetter)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WLSpacing.s) {
                        ForEach(suggestion.improvedLenses, id: \.self) { lens in
                            WLPill(title: lens.title, tone: .accent)
                        }
                    }
                    .padding(.vertical, 2)
                }

                WLActionGroup {
                    WLPrimaryButton(title: "Scan another product", systemImage: "viewfinder") {
                        openScan()
                    }

                    WLUtilityButton(title: "Ask why this fits", systemImage: "message") {
                        askStrategist()
                    }
                }
            }
        }
    }
}

private struct HomeOpenLoopsSection: View {
    let openLoops: [OpenLoop]
    let openCheckIn: () -> Void
    let openHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Open loops",
                subtitle: "The fastest way to close these is a quick check-in or one cleaner retest.",
                systemImage: "ellipsis.circle"
            )

            ForEach(openLoops) { loop in
                WLCompactCard {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text(loop.title)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text(loop.summary)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }
            }

            WLActionGroup {
                WLPrimaryButton(title: "Update check-in", systemImage: "heart.text.square") {
                    openCheckIn()
                }

                WLUtilityButton(title: "Open history", systemImage: "clock.arrow.circlepath") {
                    openHistory()
                }
            }
        }
    }
}

private struct HomeRecentWinsSection: View {
    let recentWins: [RecentWin]

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Recent wins",
                subtitle: "Proof that the system is remembering what already helps.",
                systemImage: "checkmark.seal"
            )

            ForEach(recentWins) { win in
                WLCompactCard {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text(win.title)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text(win.summary)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }
            }
        }
    }
}

private struct HomeStrategistNoteCard: View {
    let note: StrategistNote
    let openStrategist: () -> Void

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: note.title,
                    subtitle: "A contextual read, not a generic app tip.",
                    systemImage: "sparkles"
                )

                Text(note.summary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.ink)

                WLUtilityButton(title: "Open strategist", systemImage: "message") {
                    openStrategist()
                }
            }
        }
    }
}

private struct HomeRoutineSection: View {
    let routines: [RoutineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Routine memory",
                subtitle: "Choices already promoted from one-off read to repeat default.",
                systemImage: "tray.full"
            )

            ForEach(routines.prefix(3)) { routine in
                WLCompactCard {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text(routine.productName)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text(routine.note)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)

                        Text(routine.cadenceSummary)
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.rose)
                    }
                }
            }
        }
    }
}

private struct HomeSampleReadsSection: View {
    let packs: [DemoScenarioPack]
    @Binding var isExpanded: Bool
    let runScenario: (DemoScenario) -> Void

    private var visiblePacks: [DemoScenarioPack] {
        isExpanded ? packs : Array(packs.prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Sample reads",
                subtitle: "Demo reads stay available, but only as a secondary learning path.",
                systemImage: "sparkles.rectangle.stack"
            )

            if visiblePacks.indices.contains(0) {
                packCard(visiblePacks[0])
            }

            if visiblePacks.indices.contains(1) {
                packCard(visiblePacks[1])
            }

            if visiblePacks.indices.contains(2) {
                packCard(visiblePacks[2])
            }

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                    isExpanded.toggle()
                }
            } label: {
                Text(isExpanded ? "Show fewer sample reads" : "Show all sample reads")
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.rose)
            }
            .buttonStyle(.plain)
        }
    }

    private func packCard(_ pack: DemoScenarioPack) -> some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                HStack {
                    Text(pack.title)
                        .font(WLTypography.bodyEmphasis)
                        .foregroundStyle(WLPalette.ink)

                    Spacer(minLength: 0)

                    WLPill(title: pack.kind.title, tone: .soft)
                }

                Text(pack.subtitle)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WLSpacing.s) {
                        ForEach(Array(pack.scenarios.enumerated()), id: \.element.id) { _, scenario in
                            Button {
                                runScenario(scenario)
                            } label: {
                                VStack(alignment: .leading, spacing: WLSpacing.xs) {
                                    Text(scenario.title)
                                        .font(WLTypography.captionStrong)
                                        .foregroundStyle(WLPalette.ink)

                                    Text(scenario.subtitle)
                                        .font(WLTypography.caption)
                                        .foregroundStyle(WLPalette.inkSoft)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(WLSpacing.m)
                                .frame(width: 240, alignment: .leading)
                                .wlCardSurface(
                                    fill: LinearGradient(
                                        colors: [Color.white.opacity(0.98), WLPalette.canvasWarm],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    shadowColor: WLElevation.shadow.opacity(0.25),
                                    radius: WLCorner.m
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
