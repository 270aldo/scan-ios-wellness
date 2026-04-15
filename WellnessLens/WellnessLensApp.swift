import SwiftUI

@main
struct WellnessLensApp: App {
    @State private var model = AppModel()

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
        .tint(Color(red: 0.84, green: 0.32, blue: 0.54))
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        TabView(selection: $model.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.icon)
            }
            .tag(AppTab.home)

            NavigationStack {
                ScanView()
            }
            .tabItem {
                Label(AppTab.scan.title, systemImage: AppTab.scan.icon)
            }
            .tag(AppTab.scan)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label(AppTab.history.title, systemImage: AppTab.history.icon)
            }
            .tag(AppTab.history)

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
        .sheet(item: $model.latestAnalysis, onDismiss: {
            model.dismissAnalysis()
        }) { analysis in
            AnalysisView(analysis: analysis)
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

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.96, blue: 0.97),
                    Color(red: 0.95, green: 0.97, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Text("WellnessLens")
                    .font(.largeTitle.bold())
                Text("From pantry to vanity, in one clear read.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                if step == 0 {
                    Text("Choose the outcomes that matter most right now.")
                        .font(.headline)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(UserGoal.allCases) { goal in
                            SelectionChip(
                                title: goal.title,
                                isSelected: selectedGoals.contains(goal)
                            ) {
                                toggle(goal, in: &selectedGoals)
                            }
                        }
                    }
                } else if step == 1 {
                    Text("Pick sensitivities we should protect by default.")
                        .font(.headline)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(SensitivityFlag.allCases) { flag in
                            SelectionChip(
                                title: flag.title,
                                isSelected: selectedSensitivities.contains(flag)
                            ) {
                                toggle(flag, in: &selectedSensitivities)
                            }
                        }
                    }
                } else {
                    Text("Add just enough context to personalize the first week.")
                        .font(.headline)
                    Picker("Diet style", selection: $dietStyle) {
                        ForEach(DietStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Life stage", selection: $lifeStage) {
                        ForEach(LifeStage.allCases) { stage in
                            Text(stage.title).tag(stage)
                        }
                    }
                    .pickerStyle(.menu)

                    LazyVGrid(columns: columns, spacing: 12) {
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

                Spacer()

                HStack {
                    if step > 0 {
                        Button("Back") {
                            step -= 1
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button(step == 2 ? "Start Scanning" : "Continue") {
                        if step < 2 {
                            step += 1
                        } else {
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
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(step == 0 && selectedGoals.isEmpty)
                }
            }
            .padding(24)
        }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

struct SelectionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.white.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }
}
