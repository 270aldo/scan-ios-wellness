import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model

    @State private var showProfileEditor = false
    @State private var strategistEntryPoint: StrategistEntryPoint?
    @State private var showPantry = false

    var body: some View {
        WLScreen {
            strategistIdentityCard
            goalsCard
            memoryCard
            subscriptionCard
            if model.services.featureFlags.pantryMVP {
                pantryCard
            }
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
        .sheet(isPresented: $showPantry) {
            PantryView()
        }
    }

    private var strategistIdentityCard: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: WLSpacing.s) {
                        WLSectionHeader(
                            title: "Your strategist profile",
                            subtitle: "The context behind Home, scans, memory, and recommendations.",
                            systemImage: "person.text.rectangle"
                        )

                        Spacer(minLength: WLSpacing.s)

                        WLSecondaryButton(title: "Edit") {
                            showProfileEditor = true
                        }
                        .frame(maxWidth: 96)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLSectionHeader(
                            title: "Your strategist profile",
                            subtitle: "The context behind Home, scans, memory, and recommendations.",
                            systemImage: "person.text.rectangle"
                        )

                        WLSecondaryButton(title: "Edit") {
                            showProfileEditor = true
                        }
                        .frame(maxWidth: 148)
                    }
                }

                profileRow(label: "Guidance style", value: model.userProfile.guidanceStyle.title)
                profileRow(label: "Age range", value: model.userProfile.ageRange.title)
                profileRow(label: "Eating rhythm", value: model.userProfile.eatingRhythm.title)
                profileRow(label: "Restaurant rhythm", value: model.userProfile.restaurantFrequency.title)
                profileRow(label: "Supplement routine", value: model.userProfile.supplementStyle.title)
                profileRow(label: "Diet style", value: model.userContext.dietStyle.title)
                profileRow(label: "Life stage", value: model.userContext.lifeStage.title)
                profileRow(label: "Memory", value: model.userProfile.memoryEnabled ? "Enabled" : "Limited")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WLSpacing.s) {
                        WLPrimaryButton(title: "Open strategist", systemImage: "message") {
                            strategistEntryPoint = .profile
                        }

                        WLSecondaryButton(title: "Back to Home", systemImage: "house") {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                                model.selectedTab = .home
                            }
                        }
                    }

                    VStack(spacing: WLSpacing.s) {
                        WLPrimaryButton(title: "Open strategist", systemImage: "message") {
                            strategistEntryPoint = .profile
                        }

                        WLSecondaryButton(title: "Back to Home", systemImage: "house") {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                                model.selectedTab = .home
                            }
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
                    subtitle: "These goals and frictions change the whole product.",
                    systemImage: "target"
                )

                profileRow(label: "Goals", value: model.userContext.goals.map(\.title).joined(separator: ", "))
                profileRow(label: "Daily priorities", value: model.userProfile.nutritionPriorities.map(\.title).joined(separator: ", "))
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
                    subtitle: "The app should feel more personal because it remembers the right things.",
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

                Text("Premium unlocks history-based pattern reads, weekly narrative guidance, menu scanning, and pantry actions without replacing the deterministic fallback.")
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                VStack(alignment: .leading, spacing: WLSpacing.xs) {
                    Text("Unlocked now")
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(WLPalette.ink)

                    Text(
                        model.activeEntitlements.isEmpty
                            ? "Core Fase 1 flows only."
                            : model.activeEntitlements.map(\.title).joined(separator: ", ")
                    )
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
                }

                if !model.subscriptionStatus.upgradeTargets.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: WLSpacing.s) {
                            subscriptionUpgradeButtons
                        }

                        VStack(spacing: WLSpacing.s) {
                            subscriptionUpgradeButtons
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

    @ViewBuilder
    private var subscriptionUpgradeButtons: some View {
        ForEach(model.subscriptionStatus.upgradeTargets, id: \.self) { target in
            if target == .pro {
                WLPrimaryButton(title: "Unlock Pro") {
                    Task {
                        await model.purchase(.pro)
                    }
                }
            } else {
                WLSecondaryButton(title: "Unlock Plus") {
                    Task {
                        await model.purchase(.plus)
                    }
                }
            }
        }
    }

    private var pantryCard: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Pantry",
                    subtitle: "A minimal saved-default system seeded from scans, favorites, and routines.",
                    systemImage: "shippingbox"
                )

                if model.visiblePantryItems.isEmpty {
                    Text("Run a few stronger scans or save one repeat choice. Pantry will seed itself from what already looks reusable.")
                        .font(WLTypography.body)
                        .foregroundStyle(WLPalette.inkSoft)
                } else {
                    ForEach(Array(model.visiblePantryItems.prefix(2))) { item in
                        VStack(alignment: .leading, spacing: WLSpacing.xs) {
                            Text(item.title)
                                .font(WLTypography.bodyEmphasis)
                                .foregroundStyle(WLPalette.ink)

                            Text(item.summary)
                                .font(WLTypography.caption)
                                .foregroundStyle(WLPalette.inkSoft)

                            Text(item.sourceKind.title)
                                .font(WLTypography.captionStrong)
                                .foregroundStyle(WLPalette.rose)
                        }
                    }
                }

                let hasSuggestion = model.hasAccess(to: .pantrySuggestions) && !model.pantrySuggestions.isEmpty

                if hasSuggestion, let suggestion = model.pantrySuggestions.first {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Suggestion")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.rose)

                        Text(suggestion.title)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text(suggestion.summary)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                } else if let supportingMessage = PantryPresentationCopy.supportingMessage(
                    isUnlocked: model.hasAccess(to: .pantryMVP),
                    hasSuggestion: hasSuggestion
                ) {
                    Text(supportingMessage)
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)
                }

                if model.hasAccess(to: .pantryMVP) {
                    WLSecondaryButton(title: "Open pantry", systemImage: "shippingbox") {
                        showPantry = true
                    }
                } else {
                    WLSecondaryButton(title: "Preview pantry", systemImage: "shippingbox") {
                        showPantry = true
                    }
                }
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
    @State private var selectedPriorities: Set<DailyNutritionPriority>
    @State private var dietStyle: DietStyle
    @State private var lifeStage: LifeStage
    @State private var guidanceStyle: GuidanceStyle
    @State private var eatingRhythm: EatingRhythm
    @State private var supplementStyle: SupplementRoutineStyle
    @State private var ageRange: AgeRange
    @State private var restaurantFrequency: RestaurantFrequency
    @State private var memoryEnabled: Bool
    @State private var optInCycleAware: Bool
    @State private var aiProcessingConsent: Bool
    @State private var analyticsConsent: Bool
    @State private var notificationsConsent: Bool

    private let columns = [GridItem(.adaptive(minimum: 148), spacing: WLSpacing.s)]
    private let createdAt: Date

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        self.onSave = onSave
        self.createdAt = profile.createdAt
        _selectedGoals = State(initialValue: Set(profile.userContext.goals))
        _selectedFrictions = State(initialValue: Set(profile.frictions))
        _selectedSensitivities = State(initialValue: Set(profile.userContext.sensitivities))
        _selectedSkinConcerns = State(initialValue: Set(profile.userContext.skinConcerns))
        _selectedPriorities = State(initialValue: Set(profile.nutritionPriorities))
        _dietStyle = State(initialValue: profile.userContext.dietStyle)
        _lifeStage = State(initialValue: profile.userContext.lifeStage)
        _guidanceStyle = State(initialValue: profile.guidanceStyle)
        _eatingRhythm = State(initialValue: profile.eatingRhythm)
        _supplementStyle = State(initialValue: profile.supplementStyle)
        _ageRange = State(initialValue: profile.ageRange)
        _restaurantFrequency = State(initialValue: profile.restaurantFrequency)
        _memoryEnabled = State(initialValue: profile.memoryEnabled)
        _optInCycleAware = State(initialValue: profile.userContext.optInCycleAware)
        _aiProcessingConsent = State(initialValue: profile.consentFlags.aiProcessing)
        _analyticsConsent = State(initialValue: profile.consentFlags.analytics)
        _notificationsConsent = State(initialValue: profile.consentFlags.notifications)
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

                        Picker("Age range", selection: $ageRange) {
                            ForEach(AgeRange.allCases) { range in
                                Text(range.title).tag(range)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Restaurant rhythm", selection: $restaurantFrequency) {
                            ForEach(RestaurantFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)

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

                        Toggle("Allow AI processing", isOn: $aiProcessingConsent)
                            .tint(WLPalette.tint)

                        Toggle("Allow analytics", isOn: $analyticsConsent)
                            .tint(WLPalette.tint)

                        Toggle("Allow notifications", isOn: $notificationsConsent)
                            .tint(WLPalette.tint)
                    }
                }

                editorSection(
                    title: "Daily priorities",
                    subtitle: "These should sharpen the Daily Brief and the visible assistant voice."
                ) {
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
                goals: orderedSelections(selectedGoals, using: UserGoal.allCases),
                sensitivities: orderedSelections(selectedSensitivities, using: SensitivityFlag.allCases),
                dietStyle: dietStyle,
                skinConcerns: orderedSelections(selectedSkinConcerns, using: SkinConcern.allCases),
                lifeStage: lifeStage,
                optInCycleAware: optInCycleAware
            ),
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

    private func orderedSelections<T>(_ selection: Set<T>, using orderedValues: T.AllCases) -> [T]
    where T: CaseIterable & Hashable, T.AllCases: Collection, T.AllCases.Element == T {
        orderedValues.filter { selection.contains($0) }
    }
}

#Preview("Profile") {
    NavigationStack {
        ProfileView()
            .environment(AppModel())
    }
}
