import SwiftUI

private enum OnboardingDisclosureSection {
    case sensitivities
    case skinConcerns

    static func initialExpandedSection(for draft: OnboardingDraft) -> Self? {
        if !draft.formData.sensitivities.isEmpty {
            return .sensitivities
        }

        if !draft.formData.skinConcerns.isEmpty {
            return .skinConcerns
        }

        return nil
    }
}

private struct SummaryFact: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

private struct SummaryStatus: Identifiable {
    let label: String
    let value: String
    let tone: WLPill.Tone

    var id: String { label }
}

struct OnboardingFlowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var draft: OnboardingDraft
    @State private var expandedDisclosureSection: OnboardingDisclosureSection?

    private let columns = [GridItem(.adaptive(minimum: 148), spacing: WLSpacing.s)]
    private let summaryColumns = [GridItem(.adaptive(minimum: 132), spacing: WLSpacing.s)]
    private let factColumns = [GridItem(.adaptive(minimum: 140), spacing: WLSpacing.s)]
    private let totalSteps = OnboardingStep.allCases.count
    private let maxContentWidth: CGFloat = 620

    init(draft: OnboardingDraft = OnboardingDraft()) {
        _draft = State(initialValue: draft)
        _expandedDisclosureSection = State(initialValue: OnboardingDisclosureSection.initialExpandedSection(for: draft))
    }

    private var previewProfile: UserProfile {
        draft.formData.makeProfile(createdAt: draft.createdAt)
    }

    private var previewPlan: StrategistBootstrap {
        OnboardingPlanner().build(profile: previewProfile)
    }

    private var primaryExitDestination: OnboardingExitDestination {
        model.onboardingPrimaryExitDestination
    }

    private var secondaryExitDestination: OnboardingExitDestination {
        model.onboardingSecondaryExitDestination
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(max(proxy.size.width - (WLSpacing.l * 2), 0), maxContentWidth)

            ZStack(alignment: .topLeading) {
                WLScreenBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: WLSpacing.xl) {
                        hero

                        WLSurfaceCard {
                            VStack(alignment: .leading, spacing: WLSpacing.l) {
                                stepContent
                                    .id(draft.currentStep)

                                actionFooter
                            }
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.vertical, WLSpacing.l)
                    .frame(width: proxy.size.width, alignment: .center)
                }
                // Keep the scroll view pinned to the viewport so adaptive grids
                // don't negotiate an oversized content width on first run.
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .task {
            model.startOnboardingIfNeeded()
        }
        .onChange(of: draft) { _, newValue in
            model.updateOnboardingDraft(newValue)
        }
        .onChange(of: draft.currentStep) { _, newValue in
            guard newValue == .frictions else { return }
            expandedDisclosureSection = OnboardingDisclosureSection.initialExpandedSection(for: draft)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: draft.currentStep)
    }

    private var hero: some View {
        WLHeroSurface(padding: heroPadding) {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLStatusBadge(title: "WellnessLens", systemImage: "sparkles", style: .heroGlass)

                Text(WLProductCopy.Onboarding.heroTitle)
                    .font(heroTitleFont)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(WLProductCopy.Onboarding.heroSubtitle)
                    .font(heroSubtitleFont)
                    .foregroundStyle(Color.white.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)

                OnboardingProgress(step: draft.currentStep.number, totalSteps: totalSteps)
            }
            .frame(maxWidth: heroMaxWidth, alignment: .leading)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch draft.currentStep {
        case .goals:
            stepSection(
                title: WLProductCopy.Onboarding.stepOneTitle,
                subtitle: WLProductCopy.Onboarding.stepOneSubtitle
            ) {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    selectionGroup(
                        title: WLProductCopy.Onboarding.stepOneSectionTitle,
                        values: UserGoal.allCases,
                        selection: draft.formData.goals,
                        titleFor: \.title
                    ) { goal in
                        toggle(goal, in: &draft.formData.goals)
                    }

                    optionalDetailCard(
                        title: WLProductCopy.Onboarding.stepOneContextTitle,
                        body: WLProductCopy.Onboarding.stepOneContextBody
                    )
                }
            }
        case .frictions:
            stepSection(
                title: WLProductCopy.Onboarding.stepTwoTitle,
                subtitle: WLProductCopy.Onboarding.stepTwoSubtitle
            ) {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    selectionGroup(
                        title: WLProductCopy.Onboarding.stepTwoPrimaryTitle,
                        subtitle: WLProductCopy.Onboarding.stepTwoPrimarySubtitle,
                        values: UserFriction.allCases,
                        selection: draft.formData.frictions,
                        titleFor: \.title
                    ) { friction in
                        toggle(friction, in: &draft.formData.frictions)
                    }

                    WLDisclosureCard(
                        title: WLProductCopy.Onboarding.stepTwoSensitivitiesTitle,
                        subtitle: WLProductCopy.Onboarding.stepTwoSensitivitiesSubtitle,
                        statusTitle: disclosureStatusTitle(for: draft.formData.sensitivities.count),
                        isExpanded: expandedDisclosureSection == .sensitivities,
                        action: { toggleDisclosure(.sensitivities) }
                    ) {
                        selectionGrid(
                            values: SensitivityFlag.allCases,
                            selection: draft.formData.sensitivities,
                            titleFor: \.title
                        ) { sensitivity in
                            toggle(sensitivity, in: &draft.formData.sensitivities)
                        }
                    }

                    WLDisclosureCard(
                        title: WLProductCopy.Onboarding.stepTwoSkinConcernsTitle,
                        subtitle: WLProductCopy.Onboarding.stepTwoSkinConcernsSubtitle,
                        statusTitle: disclosureStatusTitle(for: draft.formData.skinConcerns.count),
                        isExpanded: expandedDisclosureSection == .skinConcerns,
                        action: { toggleDisclosure(.skinConcerns) }
                    ) {
                        selectionGrid(
                            values: SkinConcern.allCases,
                            selection: draft.formData.skinConcerns,
                            titleFor: \.title
                        ) { concern in
                            toggle(concern, in: &draft.formData.skinConcerns)
                        }
                    }
                }
            }
        case .routine:
            stepSection(
                title: WLProductCopy.Onboarding.stepThreeTitle,
                subtitle: WLProductCopy.Onboarding.stepThreeSubtitle
            ) {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    menuPicker("Diet style", selection: $draft.formData.dietStyle, titleFor: \.title)
                    menuPicker("Eating rhythm", selection: $draft.formData.eatingRhythm, titleFor: \.title)
                    menuPicker("Supplement routine", selection: $draft.formData.supplementStyle, titleFor: \.title)
                    menuPicker("Age range", selection: $draft.formData.ageRange, titleFor: \.title)
                    menuPicker("Life stage", selection: $draft.formData.lifeStage, titleFor: \.title)

                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Restaurant rhythm")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)

                        Picker("Restaurant rhythm", selection: $draft.formData.restaurantFrequency) {
                            ForEach(RestaurantFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Toggle("Use cycle-aware framing when relevant", isOn: $draft.formData.optInCycleAware)
                        .tint(WLPalette.tint)
                }
            }
        case .priorities:
            stepSection(
                title: WLProductCopy.Onboarding.stepFourTitle,
                subtitle: WLProductCopy.Onboarding.stepFourSubtitle
            ) {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    selectionGroup(
                        title: WLProductCopy.Onboarding.stepFourSectionTitle,
                        values: DailyNutritionPriority.allCases,
                        selection: draft.formData.nutritionPriorities,
                        titleFor: \.title
                    ) { priority in
                        toggle(priority, in: &draft.formData.nutritionPriorities)
                    }

                    optionalDetailCard(
                        title: WLProductCopy.Onboarding.stepFourContextTitle,
                        body: WLProductCopy.Onboarding.stepFourContextBody
                    )
                }
            }
        case .consent:
            stepSection(
                title: WLProductCopy.Onboarding.stepFiveTitle,
                subtitle: WLProductCopy.Onboarding.stepFiveSubtitle
            ) {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    selectionGroup(
                        title: WLProductCopy.Onboarding.stepFiveGuidanceTitle,
                        values: GuidanceStyle.allCases,
                        selection: [draft.formData.guidanceStyle],
                        titleFor: \.title
                    ) { style in
                        draft.formData.guidanceStyle = style
                    }

                    Toggle("Use memory to remember what helps, what hurts, and what you already decided", isOn: $draft.formData.memoryEnabled)
                        .tint(WLPalette.tint)

                    Toggle("Permitir procesamiento con IA para análisis y respuestas personalizadas (Vertex AI / Gemini). Puedo desactivarlo en cualquier momento.", isOn: $draft.formData.aiProcessingConsent)
                        .tint(WLPalette.tint)

                    Toggle("Permitir uso de datos de ciclo, sueño, HRV, frecuencia cardíaca y temperatura para personalizar mis guías. Solo salen del dispositivo si activo el procesamiento con IA.", isOn: $draft.formData.healthDataProcessingConsent)
                        .tint(WLPalette.tint)

                    Toggle("Permitir analíticas que no incluyan mis notas privadas", isOn: $draft.formData.analyticsConsent)
                        .tint(WLPalette.tint)

                    Toggle("Activar notificaciones para el Daily Brief", isOn: $draft.formData.notificationsConsent)
                        .tint(WLPalette.tint)

                    optionalDetailCard(
                        title: WLProductCopy.Onboarding.stepFiveMemoryTitle,
                        body: WLProductCopy.Onboarding.stepFiveMemoryBody
                    )
                }
            }
        case .summary:
            summaryStep
        }
    }

    private var summaryStep: some View {
        stepSection(
            title: WLProductCopy.Onboarding.summaryTitle,
            subtitle: WLProductCopy.Onboarding.summarySubtitle
        ) {
            VStack(alignment: .leading, spacing: WLSpacing.l) {
                WLPrimaryCard {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLStatusBadge(title: WLProductCopy.Onboarding.summaryHeroBadge, systemImage: "sparkles", tone: .accent)

                        Text(previewPlan.activeGoals.first?.title ?? "Build a clearer daily rhythm")
                            .font(WLTypography.title)
                            .foregroundStyle(WLPalette.ink)

                        Text(previewPlan.activeGoals.first?.summary ?? "Use one real scan and one real body signal to establish your first pattern.")
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }

                summaryPriorityCard
                summaryRoutineCard
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: WLSpacing.l) {
                        summaryDailyPrioritiesCard
                        summaryConsentCard
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.l) {
                        summaryDailyPrioritiesCard
                        summaryConsentCard
                    }
                }

                WLSecondarySurfaceCard {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text(WLProductCopy.Onboarding.summaryLoopTitle)
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.ink)

                        ForEach(previewPlan.firstWeekPlan.steps) { planStep in
                            HStack(alignment: .top, spacing: WLSpacing.s) {
                                WLIcon(systemName: "circle.dashed", color: WLPalette.rose, size: 15)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(planStep.title)
                                        .font(WLTypography.bodyEmphasis)
                                        .foregroundStyle(WLPalette.ink)

                                    Text(planStep.detail)
                                        .font(WLTypography.caption)
                                        .foregroundStyle(WLPalette.inkSoft)
                                }
                            }
                        }
                    }
                }

                WLActionGroup {
                    WLPrimaryButton(title: primaryExitDestination.title, systemImage: exitIcon(for: primaryExitDestination)) {
                        model.completeOnboarding(using: draft, exitDestination: primaryExitDestination)
                    }

                    WLSecondaryButton(
                        title: secondaryExitDestination.title,
                        systemImage: exitIcon(for: secondaryExitDestination)
                    ) {
                        model.completeOnboarding(using: draft, exitDestination: secondaryExitDestination)
                    }
                }
            }
        }
    }

    private var summaryPriorityCard: some View {
        WLSecondarySurfaceCard(padding: WLSpacing.l) {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                summaryCardHeader(
                    title: WLProductCopy.Onboarding.summaryGoalsTitle,
                    eyebrow: WLProductCopy.Onboarding.summaryGoalsEyebrow,
                    editStep: .goals
                )

                Text(priorityProfileSummary)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                summaryPillSection(
                    title: WLProductCopy.Onboarding.stepOneSectionTitle,
                    values: draft.formData.goals.map(\.title),
                    emptyTitle: "Choose at least one goal"
                )

                summaryPillSection(
                    title: WLProductCopy.Onboarding.stepTwoPrimaryTitle,
                    values: draft.formData.frictions.map(\.title),
                    emptyTitle: "No frictions yet",
                    tone: .soft
                )

                summaryPillSection(
                    title: WLProductCopy.Onboarding.stepTwoSensitivitiesTitle,
                    values: draft.formData.sensitivities.map(\.title),
                    emptyTitle: "No sensitivities yet",
                    tone: .soft
                )

                if !draft.formData.skinConcerns.isEmpty {
                    summaryPillSection(
                        title: WLProductCopy.Onboarding.stepTwoSkinConcernsTitle,
                        values: draft.formData.skinConcerns.map(\.title),
                        tone: .soft
                    )
                }
            }
        }
    }

    private var summaryRoutineCard: some View {
        WLSecondarySurfaceCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                summaryCardHeader(
                    title: WLProductCopy.Onboarding.summaryRoutineTitle,
                    eyebrow: WLProductCopy.Onboarding.summaryRoutineEyebrow,
                    editStep: .routine
                )

                Text("This is the day-to-day context behind the first reads and the first-week plan.")
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: factColumns, spacing: WLSpacing.s) {
                    ForEach(routineFacts) { fact in
                        summaryFactTile(fact)
                    }
                }
            }
        }
    }

    private var summaryDailyPrioritiesCard: some View {
        WLSecondarySurfaceCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                summaryCardHeader(
                    title: WLProductCopy.Onboarding.summaryPrioritiesTitle,
                    eyebrow: WLProductCopy.Onboarding.summaryPrioritiesEyebrow,
                    editStep: .priorities
                )

                Text("These are the tradeoffs WellnessLens will keep surfacing first.")
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                summaryPillSection(
                    title: nil,
                    values: resolvedPriorityTitles,
                    emptyTitle: "Energy"
                )
            }
        }
    }

    private var summaryConsentCard: some View {
        WLSecondarySurfaceCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                summaryCardHeader(
                    title: WLProductCopy.Onboarding.summaryConsentTitle,
                    eyebrow: WLProductCopy.Onboarding.summaryConsentEyebrow,
                    editStep: .consent
                )

                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    Text(WLProductCopy.Onboarding.stepFiveGuidanceTitle)
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(WLPalette.inkSoft)

                    WLPill(title: draft.formData.guidanceStyle.title, tone: .accent)
                }

                LazyVGrid(columns: factColumns, spacing: WLSpacing.s) {
                    ForEach(consentStatuses) { status in
                        summaryStatusTile(status)
                    }
                }
            }
        }
    }

    private var actionFooter: some View {
        VStack(alignment: .leading, spacing: WLSpacing.s) {
            if draft.currentStep != .summary {
                if draft.currentStep.previous != nil || draft.currentStep.isSkippable {
                    HStack(spacing: WLSpacing.s) {
                        if let previousStep = draft.currentStep.previous {
                            WLUtilityButton(title: "Back", systemImage: "chevron.left") {
                                draft.currentStep = previousStep
                            }
                        }

                        if draft.currentStep.isSkippable {
                            WLUtilityButton(title: "Skip for now", systemImage: "arrow.right") {
                                guard let nextStep = draft.currentStep.next else { return }
                                draft.currentStep = nextStep
                            }
                        }
                    }
                }

                WLPrimaryButton(title: continueTitle, systemImage: "arrow.right.circle") {
                    continueFlow()
                }
                .disabled(!canContinue)
            } else if let previousStep = draft.currentStep.previous {
                WLUtilityButton(title: "Back", systemImage: "chevron.left") {
                    draft.currentStep = previousStep
                }
            }
        }
    }

    private var continueTitle: String {
        draft.currentStep.next == .summary ? "Review your setup" : "Continue"
    }

    private var canContinue: Bool {
        switch draft.currentStep {
        case .goals:
            !draft.formData.goals.isEmpty
        case .summary:
            false
        case .frictions, .routine, .priorities, .consent:
            true
        }
    }

    private func continueFlow() {
        guard let nextStep = draft.currentStep.next else { return }
        draft.currentStep = nextStep
    }

    private func stepSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: WLSpacing.l) {
            WLSectionHeader(
                title: title,
                subtitle: subtitle,
                systemImage: "sparkles"
            )
            content()
        }
    }

    private func selectionGroup<T: CaseIterable & Hashable & Identifiable>(
        title: String,
        subtitle: String? = nil,
        values: T.AllCases,
        selection: [T],
        titleFor: KeyPath<T, String>,
        action: @escaping (T) -> Void
    ) -> some View where T.AllCases: Collection, T.AllCases.Element == T {
        VStack(alignment: .leading, spacing: WLSpacing.s) {
            Text(title)
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.inkSoft)

            if let subtitle {
                Text(subtitle)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            selectionGrid(
                values: values,
                selection: selection,
                titleFor: titleFor,
                action: action
            )
        }
    }

    private func selectionGrid<T: CaseIterable & Hashable & Identifiable>(
        values: T.AllCases,
        selection: [T],
        titleFor: KeyPath<T, String>,
        action: @escaping (T) -> Void
    ) -> some View where T.AllCases: Collection, T.AllCases.Element == T {
        LazyVGrid(columns: columns, spacing: WLSpacing.s) {
            ForEach(Array(values)) { value in
                WLSelectionChip(
                    title: value[keyPath: titleFor],
                    isSelected: selection.contains(value),
                    action: { action(value) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func menuPicker<T: CaseIterable & Hashable & Identifiable>(
        _ title: String,
        selection: Binding<T>,
        titleFor: KeyPath<T, String>
    ) -> some View where T.AllCases: Collection, T.AllCases.Element == T {
        VStack(alignment: .leading, spacing: WLSpacing.xs) {
            Text(title)
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.inkSoft)

            Picker(title, selection: selection) {
                ForEach(Array(T.allCases)) { value in
                    Text(value[keyPath: titleFor]).tag(value)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func optionalDetailCard(title: String, body: String) -> some View {
        WLSecondarySurfaceCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                Text(title)
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.ink)

                Text(body)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)
            }
        }
    }

    @ViewBuilder
    private func summaryPillSection(
        title: String?,
        values: [String],
        emptyTitle: String? = nil,
        tone: WLPill.Tone = .accent
    ) -> some View {
        VStack(alignment: .leading, spacing: WLSpacing.s) {
            if let title {
                Text(title)
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.inkSoft)
            }

            LazyVGrid(columns: summaryColumns, spacing: WLSpacing.s) {
                if values.isEmpty, let emptyTitle {
                    WLPill(title: emptyTitle, tone: .soft)
                } else {
                    ForEach(values, id: \.self) { value in
                        WLPill(title: value, tone: tone)
                    }
                }
            }
        }
    }

    private func summaryCardHeader(title: String, eyebrow: String, editStep: OnboardingStep) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: WLSpacing.s) {
                summaryCardHeaderText(title: title, eyebrow: eyebrow)
                Spacer(minLength: WLSpacing.s)
                summaryEditButton(editStep: editStep)
            }

            VStack(alignment: .leading, spacing: WLSpacing.s) {
                summaryCardHeaderText(title: title, eyebrow: eyebrow)
                summaryEditButton(editStep: editStep)
            }
        }
    }

    private func summaryCardHeaderText(title: String, eyebrow: String) -> some View {
        VStack(alignment: .leading, spacing: WLSpacing.xs) {
            Text(eyebrow)
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.rose)

            Text(title)
                .font(WLTypography.section)
                .foregroundStyle(WLPalette.ink)
        }
    }

    private func summaryEditButton(editStep: OnboardingStep) -> some View {
        WLUtilityButton(title: "Edit", systemImage: "slider.horizontal.3") {
            draft.currentStep = editStep
        }
        .accessibilityLabel(summaryEditAccessibilityLabel(for: editStep))
    }

    private func summaryFactTile(_ fact: SummaryFact) -> some View {
        VStack(alignment: .leading, spacing: WLSpacing.xs) {
            Text(fact.label)
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.inkSoft)

            Text(fact.value)
                .font(WLTypography.bodyEmphasis)
                .foregroundStyle(WLPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(WLSpacing.s)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WLPalette.stroke)
        )
    }

    private func summaryStatusTile(_ status: SummaryStatus) -> some View {
        HStack(alignment: .center, spacing: WLSpacing.s) {
            Text(status.label)
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.inkSoft)

            Spacer(minLength: WLSpacing.s)

            WLPill(title: status.value, tone: status.tone)
        }
        .padding(WLSpacing.s)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WLPalette.stroke)
        )
    }

    private var usesCompactHeroLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var heroPadding: CGFloat {
        usesCompactHeroLayout ? WLSpacing.l : WLSpacing.xl
    }

    private var heroTitleFont: Font {
        usesCompactHeroLayout
            ? .system(.title2, design: .rounded, weight: .bold)
            : WLTypography.hero
    }

    private var heroSubtitleFont: Font {
        usesCompactHeroLayout ? WLTypography.caption : WLTypography.body
    }

    private var heroMaxWidth: CGFloat? {
        usesCompactHeroLayout ? 460 : nil
    }

    private var routineFacts: [SummaryFact] {
        [
            SummaryFact(label: "Diet style", value: draft.formData.dietStyle.title),
            SummaryFact(label: "Eating rhythm", value: draft.formData.eatingRhythm.title),
            SummaryFact(label: "Restaurant rhythm", value: draft.formData.restaurantFrequency.title),
            SummaryFact(label: "Supplement routine", value: draft.formData.supplementStyle.title),
            SummaryFact(label: "Life stage", value: draft.formData.lifeStage.title),
            SummaryFact(label: "Age range", value: draft.formData.ageRange.title)
        ]
    }

    private var resolvedPriorityTitles: [String] {
        draft.formData.nutritionPriorities.isEmpty ? ["Energy"] : draft.formData.nutritionPriorities.map(\.title)
    }

    private var consentStatuses: [SummaryStatus] {
        [
            SummaryStatus(
                label: "Memory",
                value: draft.formData.memoryEnabled ? "Enabled" : "Limited",
                tone: draft.formData.memoryEnabled ? .accent : .soft
            ),
            SummaryStatus(
                label: "AI processing",
                value: draft.formData.aiProcessingConsent ? "On" : "Off",
                tone: draft.formData.aiProcessingConsent ? .accent : .soft
            ),
            SummaryStatus(
                label: "Health context",
                value: draft.formData.healthDataProcessingConsent ? "On" : "Off",
                tone: draft.formData.healthDataProcessingConsent ? .accent : .soft
            ),
            SummaryStatus(
                label: "Analytics",
                value: draft.formData.analyticsConsent ? "On" : "Off",
                tone: draft.formData.analyticsConsent ? .accent : .soft
            ),
            SummaryStatus(
                label: "Notifications",
                value: draft.formData.notificationsConsent ? "On" : "Off",
                tone: draft.formData.notificationsConsent ? .accent : .soft
            )
        ]
    }

    private var priorityProfileSummary: String {
        let leadGoal = draft.formData.goals.first?.title ?? "Clearer reads"

        if let friction = draft.formData.frictions.first?.title,
           let sensitivity = draft.formData.sensitivities.first?.title {
            return "\(leadGoal) leads, while \(friction.lowercased()) and \(sensitivity.lowercased()) keep the read gentler."
        }

        if let friction = draft.formData.frictions.first?.title {
            return "\(leadGoal) leads, with extra weight on \(friction.lowercased())."
        }

        if let sensitivity = draft.formData.sensitivities.first?.title {
            return "\(leadGoal) leads, with extra caution around \(sensitivity.lowercased())."
        }

        return "\(leadGoal) sets the direction for the first reads and the first-week plan."
    }

    private func summaryEditAccessibilityLabel(for step: OnboardingStep) -> String {
        switch step {
        case .goals:
            "Edit goals and sensitivities"
        case .frictions:
            "Edit frictions and sensitivities"
        case .routine:
            "Edit routine context"
        case .priorities:
            "Edit daily priorities"
        case .consent:
            "Edit personalization and consent"
        case .summary:
            "Edit summary"
        }
    }

    private func toggleDisclosure(_ section: OnboardingDisclosureSection) {
        if expandedDisclosureSection == section {
            expandedDisclosureSection = nil
        } else {
            expandedDisclosureSection = section
        }
    }

    private func disclosureStatusTitle(for count: Int) -> String {
        count == 0 ? "Optional" : "\(count) selected"
    }

    private func exitIcon(for destination: OnboardingExitDestination) -> String {
        switch destination {
        case .scan:
            "viewfinder"
        case .checkIn:
            "heart.text.square"
        }
    }

    private func toggle<T: CaseIterable & Hashable>(_ value: T, in values: inout [T]) where T.AllCases: Collection, T.AllCases.Element == T {
        if let index = values.firstIndex(of: value) {
            values.remove(at: index)
        } else {
            values.append(value)
        }

        let orderedValues = Array(T.allCases)
        let selected = Set(values)
        values = orderedValues.filter { selected.contains($0) }
    }
}

private struct OnboardingProgress: View {
    let step: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: WLSpacing.xs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < step ? Color.white : Color.white.opacity(0.26))
                    .frame(width: index + 1 == step ? 42 : 24, height: 6)
                    .animation(.spring(response: 0.26, dampingFraction: 0.88), value: step)
            }
        }
    }
}

#Preview("Onboarding") {
    OnboardingFlowView(draft: OnboardingDraft())
        .environment(AppModel())
}
