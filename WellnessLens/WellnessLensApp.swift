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
                OnboardingFlowView(draft: model.onboardingDraft ?? OnboardingDraft())
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

                        VStack(alignment: .leading, spacing: WLSpacing.s) {
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

                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: WLSpacing.s) {
                                    paywallSupportingActions
                                }

                                VStack(alignment: .leading, spacing: WLSpacing.s) {
                                    paywallSupportingActions
                                }
                            }
                        }
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

    @ViewBuilder
    private var paywallSupportingActions: some View {
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

        WLUtilityButton(title: "Restore purchases", systemImage: "arrow.clockwise") {
            Task {
                await model.restorePurchases()
                if model.hasAccess(to: context.feature) {
                    model.dismissPaywall()
                    dismiss()
                }
            }
        }
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
