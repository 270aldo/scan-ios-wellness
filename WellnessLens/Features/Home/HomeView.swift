import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    @State private var strategistEntryPoint: StrategistEntryPoint?
    @State private var sampleReadsExpanded = false

    private var payload: DailyHomePayload {
        model.dailyHomePayload
    }

    var body: some View {
        WLScreen {
            HomeDailyHero(
                payload: payload,
                primaryGoal: model.activeGoals.first,
                primaryAction: handleNextAction,
                openStrategist: { strategistEntryPoint = .home }
            )

            HomeSignalSection(payload: payload, saveCheckIn: openCheckIn)

            if payload.state == .calibrating, let firstWeekPlan = model.firstWeekPlan {
                HomeFirstWeekPlanSection(firstWeekPlan: firstWeekPlan)
            }

            if !model.activeGoals.isEmpty {
                HomeGoalsSection(goals: model.activeGoals)
            }

            if let recommendedSwap = payload.recommendedSwap {
                HomeRecommendedSwapCard(
                    suggestion: recommendedSwap,
                    openScan: openScan,
                    askStrategist: { strategistEntryPoint = .scan }
                )
            }

            if !payload.openLoops.isEmpty {
                HomeOpenLoopsSection(openLoops: payload.openLoops)
            }

            if !payload.recentWins.isEmpty {
                HomeRecentWinsSection(recentWins: payload.recentWins)
            }

            HomeStrategistNoteCard(
                note: payload.strategistNote,
                openStrategist: { strategistEntryPoint = .home }
            )

            if !model.routines.isEmpty {
                HomeRoutineSection(routines: model.routines)
            }

            HomeSampleReadsSection(
                packs: model.demoScenarioPacks,
                isExpanded: $sampleReadsExpanded,
                runScenario: runScenario
            )
        }
        .navigationTitle("Today")
        .sheet(item: $strategistEntryPoint) { entryPoint in
            StrategistChatView(entryPoint: entryPoint)
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
}

private struct HomeDailyHero: View {
    let payload: DailyHomePayload
    let primaryGoal: ActiveGoal?
    let primaryAction: () -> Void
    let openStrategist: () -> Void

    var body: some View {
        WLHeroSurface {
            VStack(alignment: .leading, spacing: WLSpacing.l) {
                HStack(spacing: WLSpacing.s) {
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
                    HStack(spacing: WLSpacing.s) {
                        metricCard(title: "Body signal", value: payload.bodySignal.title)
                        metricCard(title: "Next action", value: payload.nextAction.title)
                    }
                }

                WLHeroGlassGroup {
                    HStack(spacing: WLSpacing.s) {
                        WLPrimaryButton(
                            title: payload.nextAction.cta,
                            systemImage: "arrow.up.right.circle",
                            chrome: .standard
                        ) {
                            primaryAction()
                        }

                        WLSecondaryButton(
                            title: "Ask strategist",
                            systemImage: "message"
                        ) {
                            openStrategist()
                        }
                    }
                }
            }
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

private struct HomeSignalSection: View {
    let payload: DailyHomePayload
    let saveCheckIn: () -> Void

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Body signal",
                    subtitle: "A product recommendation should adapt to how the week is actually feeling.",
                    systemImage: "waveform.path.ecg"
                )

                HStack(alignment: .top, spacing: WLSpacing.s) {
                    WLStatusBadge(
                        title: payload.bodySignal.title,
                        systemImage: "heart.text.square",
                        tone: tone
                    )

                    Spacer(minLength: 0)

                    WLSecondaryButton(title: "Update check-in") {
                        saveCheckIn()
                    }
                    .frame(maxWidth: 148)
                }

                Text(payload.bodySignal.summary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)
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
                subtitle: "These are the outcomes currently steering Home, scan recommendations, and strategist advice.",
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

                HStack(spacing: WLSpacing.s) {
                    WLPrimaryButton(title: "Scan another product", systemImage: "viewfinder") {
                        openScan()
                    }

                    WLSecondaryButton(title: "Ask why this fits", systemImage: "message") {
                        askStrategist()
                    }
                }
            }
        }
    }
}

private struct HomeOpenLoopsSection: View {
    let openLoops: [OpenLoop]

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Open loops",
                subtitle: "These are the decisions or experiments still shaping your week.",
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
                    subtitle: "A contextual read that should feel more intimate than a generic app tip.",
                    systemImage: "sparkles"
                )

                Text(note.summary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.ink)

                WLPrimaryButton(title: "Continue with strategist", systemImage: "message") {
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
                subtitle: "Products already promoted from one-off reads into repeatable decisions.",
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
                subtitle: "Demo content stays available, but only as a secondary way to learn the product language.",
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
