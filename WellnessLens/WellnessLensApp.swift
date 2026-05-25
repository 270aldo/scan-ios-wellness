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
    @State private var plans: [SubscriptionPlan] = []

    private var targetPlan: SubscriptionPlan? {
        plans.first(where: { $0.tier == context.targetTier })
            ?? plans.first
    }

    private var secondaryPlan: SubscriptionPlan? {
        guard context.targetTier == .plus else { return nil }
        return plans.first(where: { $0.tier == .pro })
    }

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
                            Text("What unlocks")
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

                        if let plan = targetPlan {
                            planDisclosureCard(plan)
                        }

                        VStack(alignment: .leading, spacing: WLSpacing.s) {
                            WLPrimaryButton(
                                title: primaryButtonTitle,
                                systemImage: "arrow.up.right.circle"
                            ) {
                                Task {
                                    await model.purchase(from: context)
                                    if model.activePaywall == nil {
                                        dismiss()
                                    }
                                }
                            }
                            .accessibilityHint("Opens Apple's purchase confirmation. You can cancel before being charged.")

                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: WLSpacing.s) {
                                    paywallSupportingActions
                                }

                                VStack(alignment: .leading, spacing: WLSpacing.s) {
                                    paywallSupportingActions
                                }
                            }
                        }

                        legalFooter
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
            .task {
                plans = await model.services.subscription.availablePlans()
            }
        }
    }

    private var primaryButtonTitle: String {
        let base = context.targetTier == .pro ? "Unlock Pro" : "Unlock Plus"
        if let plan = targetPlan, !plan.displayPrice.isEmpty, !plan.isDemo {
            return "\(base) · \(plan.displayPrice) \(plan.displayPeriod)"
                .trimmingCharacters(in: .whitespaces)
        }
        return base
    }

    @ViewBuilder
    private func planDisclosureCard(_ plan: SubscriptionPlan) -> some View {
        VStack(alignment: .leading, spacing: WLSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(plan.tier == .pro ? "Pro" : "Plus")
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.ink)
                Spacer()
                if plan.isDemo {
                    Text("Local testing")
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)
                } else if !plan.displayPrice.isEmpty {
                    Text("\(plan.displayPrice) \(plan.displayPeriod)")
                        .font(WLTypography.bodyEmphasis)
                        .foregroundStyle(WLPalette.ink)
                }
            }

            if let offer = plan.introductoryOffer {
                Text(offer)
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.success)
            }

            Text(plan.renewalDisclosure)
                .font(WLTypography.caption)
                .foregroundStyle(WLPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if let secondary = secondaryPlan, !secondary.displayPrice.isEmpty, !secondary.isDemo {
                Text("Pro available at \(secondary.displayPrice) \(secondary.displayPeriod).")
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
            }
        }
    }

    @ViewBuilder
    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: WLSpacing.xs) {
            Text("Subscriptions auto-renew until cancelled in Settings > Apple ID > Subscriptions at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Any unused portion of a free trial is forfeited when you subscribe.")
                .font(WLTypography.caption)
                .foregroundStyle(WLPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: WLSpacing.m) {
                    legalLinks
                }
                VStack(alignment: .leading, spacing: WLSpacing.xs) {
                    legalLinks
                }
            }
        }
    }

    @ViewBuilder
    private var legalLinks: some View {
        if let terms = model.services.configuration.termsOfUseURL {
            Link("Terms of Use (EULA)", destination: terms)
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.tint)
        }
        if let privacy = model.services.configuration.privacyPolicyURL {
            Link("Privacy Policy", destination: privacy)
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.tint)
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
