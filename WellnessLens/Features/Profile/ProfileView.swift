import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model

    @State private var showProfileEditor = false
    @State private var strategistEntryPoint: StrategistEntryPoint?

    var body: some View {
        WLScreen {
            strategistIdentityCard
            goalsCard
            memoryCard
            subscriptionCard
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showProfileEditor) {
            ProfileStrategistEditor(
                profile: model.userProfile,
                onSave: { model.updateUserProfile($0) }
            )
        }
        .sheet(item: $strategistEntryPoint) { entryPoint in
            StrategistChatView(entryPoint: entryPoint)
        }
    }

    private var strategistIdentityCard: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                HStack(alignment: .top) {
                    WLSectionHeader(
                        title: "Your strategist profile",
                        subtitle: "This is the operating context behind Home, scans, memory, and recommendations.",
                        systemImage: "person.text.rectangle"
                    )

                    Spacer()

                    WLSecondaryButton(title: "Edit") {
                        showProfileEditor = true
                    }
                    .frame(maxWidth: 96)
                }

                profileRow(label: "Guidance style", value: model.userProfile.guidanceStyle.title)
                profileRow(label: "Eating rhythm", value: model.userProfile.eatingRhythm.title)
                profileRow(label: "Supplement routine", value: model.userProfile.supplementStyle.title)
                profileRow(label: "Diet style", value: model.userContext.dietStyle.title)
                profileRow(label: "Life stage", value: model.userContext.lifeStage.title)
                profileRow(label: "Memory", value: model.userProfile.memoryEnabled ? "Enabled" : "Limited")

                HStack(spacing: WLSpacing.s) {
                    WLSecondaryButton(title: "Open strategist", systemImage: "message") {
                        strategistEntryPoint = .profile
                    }

                    WLPrimaryButton(title: "Go to Home", systemImage: "house") {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                            model.selectedTab = .home
                        }
                    }
                }
            }
        }
    }

    private var goalsCard: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "What you’re optimizing",
                    subtitle: "These goals and frictions should be explicit, because they change the whole product.",
                    systemImage: "target"
                )

                profileRow(label: "Goals", value: model.userContext.goals.map(\.title).joined(separator: ", "))
                profileRow(label: "Frictions", value: model.userProfile.frictions.map(\.title).joined(separator: ", "))
                profileRow(label: "Sensitivities", value: model.userContext.sensitivities.map(\.title).joined(separator: ", "))
                profileRow(label: "Skin concerns", value: model.userContext.skinConcerns.map(\.title).joined(separator: ", "))
            }
        }
    }

    private var memoryCard: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Memory and routine",
                    subtitle: "The app should feel more intimate because it keeps the right kind of memory, not because it chats more.",
                    systemImage: "brain.head.profile"
                )

                profileRow(label: "Memory items", value: "\(model.memoryItems.count)")
                profileRow(label: "Routine items", value: "\(model.routines.count)")
                profileRow(label: "Open experiments", value: "\(model.experiments.filter { $0.status == .active }.count)")
                profileRow(label: "Strategist threads", value: "\(model.conversationThreads.count)")

                if let latestMemory = model.memoryItems.first {
                    profileRow(label: "Latest memory", value: "\(latestMemory.title) — \(latestMemory.summary)")
                }
            }
        }
    }

    private var subscriptionCard: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLStatusBadge(title: WLProductCopy.Profile.membershipTitle, systemImage: "sparkles", tone: .accent)

                Text(model.subscriptionStatus == .free ? "Currently on Free" : "Currently on \(model.subscriptionStatus.title)")
                    .font(WLTypography.title)
                    .foregroundStyle(WLPalette.ink)

                Text("Premium should unlock deeper strategist context, richer memory, and more refined daily coaching surfaces over time.")
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                HStack(spacing: WLSpacing.s) {
                    WLSecondaryButton(title: "Unlock Plus") {
                        Task {
                            await model.purchase(.plus)
                        }
                    }

                    WLPrimaryButton(title: "Unlock Pro") {
                        Task {
                            await model.purchase(.pro)
                        }
                    }
                }

                Button("Restore purchases") {
                    Task {
                        await model.restorePurchases()
                    }
                }
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.rose)
            }
        }
    }

    private func profileRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: WLSpacing.xs) {
            Text(label)
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.inkSoft)

            Text(value.isEmpty ? "Not set" : value)
                .font(WLTypography.body)
                .foregroundStyle(WLPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ProfileStrategistEditor: View {
    let onSave: (UserProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedGoals: Set<UserGoal>
    @State private var selectedFrictions: Set<UserFriction>
    @State private var selectedSensitivities: Set<SensitivityFlag>
    @State private var selectedSkinConcerns: Set<SkinConcern>
    @State private var dietStyle: DietStyle
    @State private var lifeStage: LifeStage
    @State private var guidanceStyle: GuidanceStyle
    @State private var eatingRhythm: EatingRhythm
    @State private var supplementStyle: SupplementRoutineStyle
    @State private var memoryEnabled: Bool
    @State private var optInCycleAware: Bool

    private let columns = [GridItem(.adaptive(minimum: 148), spacing: WLSpacing.s)]
    private let createdAt: Date

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        self.onSave = onSave
        self.createdAt = profile.createdAt
        _selectedGoals = State(initialValue: Set(profile.userContext.goals))
        _selectedFrictions = State(initialValue: Set(profile.frictions))
        _selectedSensitivities = State(initialValue: Set(profile.userContext.sensitivities))
        _selectedSkinConcerns = State(initialValue: Set(profile.userContext.skinConcerns))
        _dietStyle = State(initialValue: profile.userContext.dietStyle)
        _lifeStage = State(initialValue: profile.userContext.lifeStage)
        _guidanceStyle = State(initialValue: profile.guidanceStyle)
        _eatingRhythm = State(initialValue: profile.eatingRhythm)
        _supplementStyle = State(initialValue: profile.supplementStyle)
        _memoryEnabled = State(initialValue: profile.memoryEnabled)
        _optInCycleAware = State(initialValue: profile.userContext.optInCycleAware)
    }

    var body: some View {
        NavigationStack {
            WLScreen {
                editorSection(
                    title: "Goals",
                    subtitle: "The outcomes Home and strategist should favor first."
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

                editorSection(
                    title: "Frictions",
                    subtitle: "The real-life problems that should keep showing up in recommendations."
                ) {
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

                editorSection(
                    title: "Sensitivities",
                    subtitle: "Bias the app toward caution when these are in play."
                ) {
                    LazyVGrid(columns: columns, spacing: WLSpacing.s) {
                        ForEach(SensitivityFlag.allCases) { sensitivity in
                            SelectionChip(
                                title: sensitivity.title,
                                isSelected: selectedSensitivities.contains(sensitivity)
                            ) {
                                toggle(sensitivity, in: &selectedSensitivities)
                            }
                        }
                    }
                }

                editorSection(
                    title: "Profile shape",
                    subtitle: "Tune how the strategist should reason about your day-to-day reality."
                ) {
                    VStack(alignment: .leading, spacing: WLSpacing.l) {
                        Picker("Guidance style", selection: $guidanceStyle) {
                            ForEach(GuidanceStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Eating rhythm", selection: $eatingRhythm) {
                            ForEach(EatingRhythm.allCases) { rhythm in
                                Text(rhythm.title).tag(rhythm)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Supplement routine", selection: $supplementStyle) {
                            ForEach(SupplementRoutineStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.menu)

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

                        Toggle("Use memory to personalize guidance", isOn: $memoryEnabled)
                            .tint(WLPalette.tint)

                        Toggle("Allow cycle-aware framing", isOn: $optInCycleAware)
                            .tint(WLPalette.tint)
                    }
                }

                editorSection(
                    title: "Skin concerns",
                    subtitle: "Optional, but useful when the nutrition-first system extends into topical decisions."
                ) {
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
            .navigationTitle("Edit strategist profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(WLTypography.captionStrong)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(makeProfile())
                        dismiss()
                    }
                    .font(WLTypography.captionStrong)
                    .disabled(selectedGoals.isEmpty || selectedFrictions.isEmpty)
                }
            }
        }
    }

    private func editorSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.l) {
                WLSectionHeader(title: title, subtitle: subtitle)
                content()
            }
        }
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            userContext: UserContext(
                goals: Array(selectedGoals),
                sensitivities: Array(selectedSensitivities),
                dietStyle: dietStyle,
                skinConcerns: Array(selectedSkinConcerns),
                lifeStage: lifeStage,
                optInCycleAware: optInCycleAware
            ),
            frictions: Array(selectedFrictions),
            guidanceStyle: guidanceStyle,
            eatingRhythm: eatingRhythm,
            supplementStyle: supplementStyle,
            memoryEnabled: memoryEnabled,
            createdAt: createdAt
        )
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

#Preview("Profile") {
    NavigationStack {
        ProfileView()
            .environment(AppModel())
    }
}
