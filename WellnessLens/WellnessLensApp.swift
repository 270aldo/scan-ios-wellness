import SwiftUI
import UIKit

@main
struct WellnessLensApp: App {
    @State private var model = AppModel()

    @MainActor
    init() {
        AppearanceConfigurator.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { url in
                    model.handleIncomingURL(url)
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .task {
            await model.bootstrap()
            model.consumeIntentRouteIfNeeded()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                model.consumeIntentRouteIfNeeded()
            }
        }
        .preferredColorScheme(.light)
        .fontDesign(.rounded)
        .tint(WLPalette.tint)
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    private let orderedTabs: [AppTab] = [.home, .history, .scan, .checkIn, .profile]

    var body: some View {
        @Bindable var model = model

        shellContent(selectedTab: $model.selectedTab)
            .sheet(item: $model.latestAnalysis, onDismiss: {
                model.dismissAnalysis()
            }) { analysis in
                AnalysisView(analysis: analysis)
            }
            .sheet(item: $model.activePaywall) { context in
                PhaseTwoPaywallSheet(context: context)
            }
    }

    @ViewBuilder
    private func shellContent(selectedTab: Binding<AppTab>) -> some View {
        if #available(iOS 26, *) {
            tabContent(selectedTab: selectedTab)
        } else {
            tabContent(selectedTab: selectedTab)
                .toolbar(.hidden, for: .tabBar)
                .safeAreaInset(edge: .bottom) {
                    WLTabBar(selection: selectedTab, tabs: orderedTabs)
                        .padding(.horizontal, WLSpacing.l)
                        .padding(.top, WLSpacing.xs)
                        .background(Color.clear)
                }
        }
    }

    private func tabContent(selectedTab: Binding<AppTab>) -> some View {
        TabView(selection: selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.icon)
            }
            .tag(AppTab.home)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label(AppTab.history.title, systemImage: AppTab.history.icon)
            }
            .tag(AppTab.history)

            NavigationStack {
                ScanView()
            }
            .tabItem {
                Label(AppTab.scan.title, systemImage: AppTab.scan.icon)
            }
            .tag(AppTab.scan)

            NavigationStack {
                CheckInView()
            }
            .tabItem {
                Label(AppTab.checkIn.title, systemImage: AppTab.checkIn.icon)
            }
            .tag(AppTab.checkIn)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label(AppTab.profile.title, systemImage: AppTab.profile.icon)
            }
            .tag(AppTab.profile)
        }
    }
}

private struct PhaseTwoPaywallSheet: View {
    let context: PaywallContext

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WLScreen {
                WLPrimaryCard {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLStatusBadge(title: context.title, systemImage: "sparkles", tone: .accent)

                        Text(context.feature.title)
                            .font(WLTypography.title)
                            .foregroundStyle(WLPalette.ink)

                        Text(context.message)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)

                        VStack(alignment: .leading, spacing: WLSpacing.xs) {
                            Text("Preview")
                                .font(WLTypography.captionStrong)
                                .foregroundStyle(WLPalette.ink)

                            ForEach(context.previewLines, id: \.self) { line in
                                Text("• \(line)")
                                    .font(WLTypography.body)
                                    .foregroundStyle(WLPalette.inkSoft)
                            }
                        }

                        if !model.activeEntitlements.isEmpty {
                            VStack(alignment: .leading, spacing: WLSpacing.xs) {
                                Text("Already unlocked")
                                    .font(WLTypography.captionStrong)
                                    .foregroundStyle(WLPalette.ink)

                                Text(model.activeEntitlements.map(\.title).joined(separator: ", "))
                                    .font(WLTypography.caption)
                                    .foregroundStyle(WLPalette.inkSoft)
                            }
                        }

                        VStack(spacing: WLSpacing.s) {
                            WLPrimaryButton(
                                title: context.targetTier == .pro ? "Unlock Pro" : "Unlock Plus",
                                systemImage: "arrow.up.right.circle"
                            ) {
                                Task {
                                    await model.purchase(from: context)
                                    if model.activePaywall == nil {
                                        dismiss()
                                    }
                                }
                            }

                            if context.targetTier == .plus {
                                WLSecondaryButton(title: "Unlock Pro", systemImage: "sparkles.rectangle.stack") {
                                    Task {
                                        await model.purchase(.pro)
                                        if model.hasAccess(to: context.feature) {
                                            model.dismissPaywall()
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }

                        Button("Restore purchases") {
                            Task {
                                await model.restorePurchases()
                                if model.hasAccess(to: context.feature) {
                                    model.dismissPaywall()
                                    dismiss()
                                }
                            }
                        }
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(WLPalette.rose)
                    }
                }
            }
            .navigationTitle("Premium")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        model.dismissPaywall()
                        dismiss()
                    }
                    .font(WLTypography.captionStrong)
                }
            }
        }
    }
}

struct OnboardingFlowView: View {
    @Environment(AppModel.self) private var model

    @State private var step = 0
    @State private var selectedGoals = Set<UserGoal>()
    @State private var selectedFrictions = Set<UserFriction>()
    @State private var selectedSensitivities = Set<SensitivityFlag>()
    @State private var selectedSkinConcerns = Set<SkinConcern>()
    @State private var selectedPriorities = Set<DailyNutritionPriority>([.energy, .digestion, .skin])
    @State private var dietStyle: DietStyle = .flexitarian
    @State private var lifeStage: LifeStage = .everyDay
    @State private var eatingRhythm: EatingRhythm = .flexible
    @State private var supplementStyle: SupplementRoutineStyle = .simple
    @State private var guidanceStyle: GuidanceStyle = .calmAndDirect
    @State private var ageRange: AgeRange = .thirties
    @State private var restaurantFrequency: RestaurantFrequency = .balanced
    @State private var memoryEnabled = true
    @State private var optInCycleAware = false
    @State private var aiProcessingConsent = true
    @State private var analyticsConsent = false
    @State private var notificationsConsent = false

    private let columns = [GridItem(.adaptive(minimum: 148), spacing: WLSpacing.s)]
    private let totalSteps = 5

    var body: some View {
        ZStack {
            WLScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: WLSpacing.xl) {
                    WLHeroSurface {
                        VStack(alignment: .leading, spacing: WLSpacing.m) {
                            WLStatusBadge(title: "WellnessLens", systemImage: "sparkles")

                            Text(WLProductCopy.Onboarding.heroTitle)
                                .font(WLTypography.hero)
                                .foregroundStyle(.white)

                            Text(WLProductCopy.Onboarding.heroSubtitle)
                                .font(WLTypography.body)
                                .foregroundStyle(Color.white.opacity(0.90))

                            OnboardingProgress(step: step, totalSteps: totalSteps)
                        }
                    }

                    WLSurfaceCard {
                        VStack(alignment: .leading, spacing: WLSpacing.l) {
                            stepContent

                            HStack(spacing: WLSpacing.s) {
                                if step > 0 {
                                    WLSecondaryButton(title: "Back") {
                                        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                                            step -= 1
                                        }
                                    }
                                }

                                WLPrimaryButton(title: step == totalSteps - 1 ? "Start your strategist" : "Continue") {
                                    advance()
                                }
                                .disabled(!canAdvance)
                            }
                        }
                    }
                }
                .padding(.horizontal, WLSpacing.l)
                .padding(.vertical, WLSpacing.l)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            onboardingSection(
                title: "What should WellnessLens optimize first?",
                subtitle: "Choose the outcomes and frictions that should shape your daily decisions, not just your scans."
            ) {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text("Goals")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)

                        LazyVGrid(columns: columns, spacing: WLSpacing.s) {
                            ForEach(UserGoal.allCases) { goal in
                                SelectionChip(
                                    title: goal.title,
                                    isSelected: selectedGoals.contains(goal)
                                ) {
                                    toggle(goal, in: &selectedGoals)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text("Current friction")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)

                        LazyVGrid(columns: columns, spacing: WLSpacing.s) {
                            ForEach(UserFriction.allCases) { friction in
                                SelectionChip(
                                    title: friction.title,
                                    isSelected: selectedFrictions.contains(friction)
                                ) {
                                    toggle(friction, in: &selectedFrictions)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Age range")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)

                        Picker("Age range", selection: $ageRange) {
                            ForEach(AgeRange.allCases) { range in
                                Text(range.title).tag(range)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        case 1:
            onboardingSection(
                title: "How does your routine actually work?",
                subtitle: "This lets Home and the strategist adapt to real-life rhythm instead of idealized behavior."
            ) {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Diet style")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)
                        Picker("Diet style", selection: $dietStyle) {
                            ForEach(DietStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Eating rhythm")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)
                        Picker("Eating rhythm", selection: $eatingRhythm) {
                            ForEach(EatingRhythm.allCases) { rhythm in
                                Text(rhythm.title).tag(rhythm)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Supplement routine")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)
                        Picker("Supplement routine", selection: $supplementStyle) {
                            ForEach(SupplementRoutineStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                        Toggle("Use cycle-aware framing when relevant", isOn: $optInCycleAware)
                        .tint(WLPalette.tint)

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text("Restaurant vs home")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)

                        Picker("Restaurant frequency", selection: $restaurantFrequency) {
                            ForEach(RestaurantFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text("Daily priorities")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)

                        LazyVGrid(columns: columns, spacing: WLSpacing.s) {
                            ForEach(DailyNutritionPriority.allCases) { priority in
                                SelectionChip(
                                    title: priority.title,
                                    isSelected: selectedPriorities.contains(priority)
                                ) {
                                    toggle(priority, in: &selectedPriorities)
                                }
                            }
                        }
                    }
                }
            }
        case 2:
            onboardingSection(
                title: "What should the app be more careful with?",
                subtitle: "These are the sensitivities and body contexts that should bias decisions toward caution."
            ) {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    LazyVGrid(columns: columns, spacing: WLSpacing.s) {
                        ForEach(SensitivityFlag.allCases) { flag in
                            SelectionChip(
                                title: flag.title,
                                isSelected: selectedSensitivities.contains(flag)
                            ) {
                                toggle(flag, in: &selectedSensitivities)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Life stage")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)
                        Picker("Life stage", selection: $lifeStage) {
                            ForEach(LifeStage.allCases) { stage in
                                Text(stage.title).tag(stage)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text("Skin concerns")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)

                        LazyVGrid(columns: columns, spacing: WLSpacing.s) {
                            ForEach(SkinConcern.allCases) { concern in
                                SelectionChip(
                                    title: concern.title,
                                    isSelected: selectedSkinConcerns.contains(concern)
                                ) {
                                    toggle(concern, in: &selectedSkinConcerns)
                                }
                            }
                        }
                    }
                }
            }
        case 3:
            onboardingSection(
                title: "How should your strategist show up?",
                subtitle: "Tone and memory are part of the product, not an afterthought."
            ) {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    LazyVGrid(columns: columns, spacing: WLSpacing.s) {
                        ForEach(GuidanceStyle.allCases) { style in
                            SelectionChip(
                                title: style.title,
                                isSelected: guidanceStyle == style
                            ) {
                                guidanceStyle = style
                            }
                        }
                    }

                    Toggle("Let WellnessLens remember what helps, what hurts, and what you already decided", isOn: $memoryEnabled)
                        .tint(WLPalette.tint)

                    Toggle("Allow AI processing for structured analysis", isOn: $aiProcessingConsent)
                        .tint(WLPalette.tint)

                    Toggle("Allow product analytics that do not include private notes", isOn: $analyticsConsent)
                        .tint(WLPalette.tint)

                    Toggle("Enable Daily Brief notifications later", isOn: $notificationsConsent)
                        .tint(WLPalette.tint)

                    WLCompactCard {
                        VStack(alignment: .leading, spacing: WLSpacing.s) {
                            Text("What memory means here")
                                .font(WLTypography.captionStrong)
                                .foregroundStyle(WLPalette.ink)

                            Text("It stores goals, routines, product decisions, body-signal notes, and strategist takeaways so Home becomes more personal every day.")
                                .font(WLTypography.body)
                                .foregroundStyle(WLPalette.inkSoft)
                        }
                    }
                }
            }
        default:
            let previewProfile = builtProfile()
            let previewPlan = OnboardingPlanner().build(profile: previewProfile)

            onboardingSection(
                title: "Your strategist is about to start with a real point of view.",
                subtitle: "This setup should change what Home, scan actions, and memory prioritize from day one."
            ) {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    WLPrimaryCard {
                        VStack(alignment: .leading, spacing: WLSpacing.m) {
                            WLStatusBadge(title: "Primary focus", systemImage: "sparkles", tone: .accent)

                            Text(previewPlan.activeGoals.first?.title ?? "Build a clearer daily rhythm")
                                .font(WLTypography.title)
                                .foregroundStyle(WLPalette.ink)

                            Text(previewPlan.activeGoals.first?.summary ?? "Use one real scan and one real body signal to establish your first pattern.")
                                .font(WLTypography.body)
                                .foregroundStyle(WLPalette.inkSoft)
                        }
                    }

                    WLCompactCard {
                        VStack(alignment: .leading, spacing: WLSpacing.s) {
                            Text("Your first-week loop")
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

                    WLCompactCard {
                        VStack(alignment: .leading, spacing: WLSpacing.s) {
                            Text("First mission")
                                .font(WLTypography.captionStrong)
                                .foregroundStyle(WLPalette.ink)

                            Text("Scan or snapshot something real today so the assistant starts from an actual decision, not a generic profile.")
                                .font(WLTypography.body)
                                .foregroundStyle(WLPalette.inkSoft)
                        }
                    }
                }
            }
        }
    }

    private func onboardingSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: WLSpacing.l) {
            WLSectionHeader(title: title, subtitle: subtitle)
            content()
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 0:
            !selectedGoals.isEmpty && !selectedFrictions.isEmpty
        default:
            true
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) {
                step += 1
            }
            return
        }

        model.completeOnboarding(with: builtProfile())
    }

    private func builtProfile() -> UserProfile {
        let context = UserContext(
            goals: orderedSelections(selectedGoals, using: UserGoal.allCases),
            sensitivities: orderedSelections(selectedSensitivities, using: SensitivityFlag.allCases),
            dietStyle: dietStyle,
            skinConcerns: orderedSelections(selectedSkinConcerns, using: SkinConcern.allCases),
            lifeStage: lifeStage,
            optInCycleAware: optInCycleAware
        )

        return UserProfile(
            userContext: context,
            frictions: orderedSelections(selectedFrictions, using: UserFriction.allCases),
            guidanceStyle: guidanceStyle,
            eatingRhythm: eatingRhythm,
            supplementStyle: supplementStyle,
            memoryEnabled: memoryEnabled,
            ageRange: ageRange,
            restaurantFrequency: restaurantFrequency,
            nutritionPriorities: orderedSelections(
                selectedPriorities.isEmpty ? [.energy] : selectedPriorities,
                using: DailyNutritionPriority.allCases
            ),
            consentFlags: ConsentFlags(
                aiProcessing: aiProcessingConsent,
                analytics: analyticsConsent,
                notifications: notificationsConsent,
                healthDataProcessing: true
            ),
            createdAt: .now
        )
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    private func orderedSelections<T>(_ selection: Set<T>, using orderedValues: T.AllCases) -> [T]
    where T: CaseIterable & Hashable, T.AllCases: Collection, T.AllCases.Element == T {
        orderedValues.filter { selection.contains($0) }
    }
}

private struct OnboardingProgress: View {
    let step: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: WLSpacing.xs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index <= step ? Color.white : Color.white.opacity(0.26))
                    .frame(width: index == step ? 42 : 24, height: 6)
                    .animation(.spring(response: 0.26, dampingFraction: 0.88), value: step)
            }
        }
    }
}

struct SelectionChip: View {
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

private enum AppearanceConfigurator {
    @MainActor
    static func configure() {
        if #available(iOS 26, *) {
            return
        }

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(WLPalette.ink)
        ]
        navigationAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(WLPalette.ink)
        ]

        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        tabAppearance.backgroundColor = UIColor.white.withAlphaComponent(0.78)
        tabAppearance.shadowColor = UIColor.black.withAlphaComponent(0.05)

        let normal = tabAppearance.stackedLayoutAppearance.normal
        normal.iconColor = UIColor(WLPalette.inkSoft)
        normal.titleTextAttributes = [.foregroundColor: UIColor(WLPalette.inkSoft)]

        let selected = tabAppearance.stackedLayoutAppearance.selected
        selected.iconColor = UIColor(WLPalette.tint)
        selected.titleTextAttributes = [.foregroundColor: UIColor(WLPalette.tint)]

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
