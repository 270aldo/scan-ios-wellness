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

struct OnboardingFlowView: View {
    @Environment(AppModel.self) private var model

    @State private var step = 0
    @State private var selectedGoals = Set<UserGoal>([.clearSkin, .steadyEnergy])
    @State private var selectedSensitivities = Set<SensitivityFlag>([.fragranceSensitive])
    @State private var selectedSkinConcerns = Set<SkinConcern>([.dryness])
    @State private var dietStyle: DietStyle = .flexitarian
    @State private var lifeStage: LifeStage = .everyDay

    private let columns = [GridItem(.adaptive(minimum: 148), spacing: WLSpacing.s)]

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

                            OnboardingProgress(step: step)
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

                                WLPrimaryButton(title: step == 2 ? "Start your first scan" : "Continue") {
                                    advance()
                                }
                                .disabled(step == 0 && selectedGoals.isEmpty)
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
                title: WLProductCopy.Onboarding.stepOneTitle,
                subtitle: WLProductCopy.Onboarding.stepOneSubtitle
            ) {
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
        case 1:
            onboardingSection(
                title: WLProductCopy.Onboarding.stepTwoTitle,
                subtitle: WLProductCopy.Onboarding.stepTwoSubtitle
            ) {
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
            }
        default:
            onboardingSection(
                title: WLProductCopy.Onboarding.stepThreeTitle,
                subtitle: WLProductCopy.Onboarding.stepThreeSubtitle
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

    private func advance() {
        if step < 2 {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) {
                step += 1
            }
            return
        }

        let context = UserContext(
            goals: Array(selectedGoals),
            sensitivities: Array(selectedSensitivities),
            dietStyle: dietStyle,
            skinConcerns: Array(selectedSkinConcerns),
            lifeStage: lifeStage,
            optInCycleAware: false
        )
        model.completeOnboarding(with: context)
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

private struct OnboardingProgress: View {
    let step: Int

    var body: some View {
        HStack(spacing: WLSpacing.xs) {
            ForEach(0..<3, id: \.self) { index in
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
