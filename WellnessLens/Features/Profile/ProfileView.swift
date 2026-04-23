import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model

    @State private var showProfileEditor = false
    @State private var strategistEntryPoint: StrategistEntryPoint?
    @State private var showPantry = false
    @State private var showBackendAdmin = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false

    var body: some View {
        WLScreen {
            strategistIdentityCard
            goalsCard
            memoryCard
            if model.hasBackendDebugSurface {
                backendCard
            }
            subscriptionCard
            if model.featureFlags.pantryMVP {
                pantryCard
            }
            privacyAndAccountCard
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
        .sheet(isPresented: $showBackendAdmin) {
            BackendAdminView()
        }
        .confirmationDialog(
            "Delete your account and all stored data?",
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                performAccountDeletion()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your profile, scans, check-ins, memory items, favorites, routines and HealthKit write-back history from this device and from the WellnessLens backend. You will be returned to onboarding with a fresh installation.")
        }
    }

    private func performAccountDeletion() {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        Task {
            await model.deleteAccount()
            isDeletingAccount = false
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

                        WLUtilityButton(title: "Edit", systemImage: "slider.horizontal.3") {
                            showProfileEditor = true
                        }
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLSectionHeader(
                            title: "Your strategist profile",
                            subtitle: "The context behind Home, scans, memory, and recommendations.",
                            systemImage: "person.text.rectangle"
                        )

                        WLUtilityButton(title: "Edit", systemImage: "slider.horizontal.3") {
                            showProfileEditor = true
                        }
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

                WLActionGroup {
                    WLPrimaryButton(title: "Open strategist", systemImage: "message") {
                        strategistEntryPoint = .profile
                    }

                    WLUtilityButton(title: "Back to Home", systemImage: "house") {
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
                    subtitle: WLProductCopy.Profile.goalsSubtitle,
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

    private var privacyAndAccountCard: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Privacy and account",
                    subtitle: "Control what WellnessLens remembers about you.",
                    systemImage: "lock.shield"
                )

                Text("Deleting your account permanently removes your profile, scans, check-ins, memory items, favorites, routines, and any data that was synced to the backend. This cannot be undone.")
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                WLActionGroup {
                    Button(role: .destructive) {
                        showDeleteAccountConfirmation = true
                    } label: {
                        HStack(spacing: WLSpacing.xs) {
                            if isDeletingAccount {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(isDeletingAccount ? "Deleting…" : "Delete my account")
                        }
                        .font(WLTypography.bodyEmphasis)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, WLSpacing.s)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isDeletingAccount)
                    .accessibilityHint("Permanently deletes your WellnessLens account and all stored data.")
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

                Text("Premium unlocks history-based pattern reads, weekly narrative guidance, menu scanning, and pantry actions while keeping core on-device guidance available.")
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                VStack(alignment: .leading, spacing: WLSpacing.xs) {
                    Text("Unlocked now")
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(WLPalette.ink)

                    Text(
                        model.activeEntitlements.isEmpty
                            ? "Core flows only."
                            : model.activeEntitlements.map(\.title).joined(separator: ", ")
                    )
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
                }

                if !model.subscriptionStatus.upgradeTargets.isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        if let primaryTarget = subscriptionPrimaryTarget {
                            subscriptionPrimaryButton(for: primaryTarget)
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: WLSpacing.s) {
                                subscriptionSupportingButtons
                            }

                            VStack(alignment: .leading, spacing: WLSpacing.s) {
                                subscriptionSupportingButtons
                            }
                        }
                    }
                }
            }
        }
    }

    private var backendCard: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Backend and sync",
                    subtitle: "See whether Home, scans, and sync are live, falling back, or waiting to retry.",
                    systemImage: "server.rack"
                )

                if let homeStatus = model.backendStatuses[.home] {
                    backendRow(label: "Home", status: homeStatus)
                }

                if let insightsStatus = model.backendStatuses[.insights] {
                    backendRow(label: "Weekly insights", status: insightsStatus)
                }

                if let scanStatus = model.backendStatuses[.structuredScan] {
                    backendRow(label: "Structured scan", status: scanStatus)
                }

                WLUtilityButton(title: "Open backend admin", systemImage: "ladybug") {
                    showBackendAdmin = true
                }
            }
        }
    }

    private var subscriptionPrimaryTarget: SubscriptionStatus? {
        if model.subscriptionStatus.upgradeTargets.contains(.pro) {
            return .pro
        }

        return model.subscriptionStatus.upgradeTargets.first
    }

    @ViewBuilder
    private func subscriptionPrimaryButton(for target: SubscriptionStatus) -> some View {
        // Purchases always go through the paywall sheet so the usuaria sees
        // price, duration, auto-renewal terms, and legal links before Apple's
        // confirmation prompt (App Store Review Guideline 3.1.2(c)).
        if target == .pro {
            WLPrimaryButton(title: "See Pro options", systemImage: "sparkles") {
                model.presentUpgradePaywall(targetTier: .pro)
            }
        } else {
            WLPrimaryButton(title: "See Plus options", systemImage: "arrow.up.right.circle") {
                model.presentUpgradePaywall(targetTier: .plus)
            }
        }
    }

    @ViewBuilder
    private var subscriptionSupportingButtons: some View {
        if model.subscriptionStatus.upgradeTargets.contains(.plus) && subscriptionPrimaryTarget != .plus {
            WLSecondaryButton(title: "See Plus options", systemImage: "arrow.up.right.circle") {
                model.presentUpgradePaywall(targetTier: .plus)
            }
        }

        WLUtilityButton(title: "Restore purchases", systemImage: "arrow.clockwise") {
            Task {
                await model.restorePurchases()
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
                    WLUtilityButton(title: "Open pantry", systemImage: "shippingbox") {
                        showPantry = true
                    }
                } else {
                    WLUtilityButton(title: "See pantry", systemImage: "shippingbox") {
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

    private func backendRow(label: String, status: BackendSurfaceStatus) -> some View {
        VStack(alignment: .leading, spacing: WLSpacing.xs) {
            HStack(spacing: WLSpacing.s) {
                Text(label)
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.inkSoft)

                WLStatusBadge(
                    title: status.state.title,
                    systemImage: backendStatusSystemImage(status.state),
                    tone: backendStatusTone(status.state)
                )
            }

            Text(status.detail)
                .font(WLTypography.caption)
                .foregroundStyle(WLPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func backendStatusTone(_ state: BackendSurfaceState) -> WLStatusBadge.Tone {
        switch state {
        case .live:
            .success
        case .fallback, .retryableError:
            .caution
        case .unavailable, .idle, .syncPending:
            .accent
        }
    }

    private func backendStatusSystemImage(_ state: BackendSurfaceState) -> String {
        switch state {
        case .unavailable:
            "icloud.slash"
        case .idle:
            "pause.circle"
        case .syncPending:
            "arrow.trianglehead.2.clockwise"
        case .live:
            "checkmark.circle"
        case .fallback:
            "arrow.uturn.backward.circle"
        case .retryableError:
            "exclamationmark.triangle"
        }
    }
}

private struct ProfileStrategistEditor: View {
    let onSave: (UserProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var formData: StrategistProfileFormData

    private let columns = [GridItem(.adaptive(minimum: 148), spacing: WLSpacing.s)]
    private let createdAt: Date

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        self.onSave = onSave
        self.createdAt = profile.createdAt
        _formData = State(initialValue: StrategistProfileFormData(profile: profile))
    }

    var body: some View {
        NavigationStack {
            WLScreen {
                editorSection(
                    title: WLProductCopy.ProfileEditor.goalsTitle,
                    subtitle: WLProductCopy.ProfileEditor.goalsSubtitle
                ) {
                    selectionGrid(
                        title: "Goals",
                        values: UserGoal.allCases,
                        selection: formData.goals,
                        titleFor: \.title
                    ) { goal in
                        toggle(goal, in: &formData.goals)
                    }
                }

                editorSection(
                    title: WLProductCopy.ProfileEditor.frictionsTitle,
                    subtitle: WLProductCopy.ProfileEditor.frictionsSubtitle
                ) {
                    selectionGrid(
                        title: "Frictions",
                        values: UserFriction.allCases,
                        selection: formData.frictions,
                        titleFor: \.title
                    ) { friction in
                        toggle(friction, in: &formData.frictions)
                    }
                }

                editorSection(
                    title: WLProductCopy.ProfileEditor.sensitivitiesTitle,
                    subtitle: WLProductCopy.ProfileEditor.sensitivitiesSubtitle
                ) {
                    selectionGrid(
                        title: "Sensitivities",
                        values: SensitivityFlag.allCases,
                        selection: formData.sensitivities,
                        titleFor: \.title
                    ) { sensitivity in
                        toggle(sensitivity, in: &formData.sensitivities)
                    }
                }

                editorSection(
                    title: WLProductCopy.ProfileEditor.routineTitle,
                    subtitle: WLProductCopy.ProfileEditor.routineSubtitle
                ) {
                    VStack(alignment: .leading, spacing: WLSpacing.l) {
                        menuPicker("Guidance style", selection: $formData.guidanceStyle, titleFor: \.title)
                        menuPicker("Eating rhythm", selection: $formData.eatingRhythm, titleFor: \.title)
                        menuPicker("Supplement routine", selection: $formData.supplementStyle, titleFor: \.title)
                        menuPicker("Diet style", selection: $formData.dietStyle, titleFor: \.title)
                        menuPicker("Age range", selection: $formData.ageRange, titleFor: \.title)

                        VStack(alignment: .leading, spacing: WLSpacing.xs) {
                            Text("Restaurant rhythm")
                                .font(WLTypography.captionStrong)
                                .foregroundStyle(WLPalette.inkSoft)

                            Picker("Restaurant rhythm", selection: $formData.restaurantFrequency) {
                                ForEach(RestaurantFrequency.allCases) { frequency in
                                    Text(frequency.title).tag(frequency)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        menuPicker("Life stage", selection: $formData.lifeStage, titleFor: \.title)

                        Toggle("Use memory to personalize future guidance", isOn: $formData.memoryEnabled)
                            .tint(WLPalette.tint)

                        Toggle("Use cycle-aware framing when relevant", isOn: $formData.optInCycleAware)
                            .tint(WLPalette.tint)

                        Toggle("Allow AI processing", isOn: $formData.aiProcessingConsent)
                            .tint(WLPalette.tint)

                        Toggle("Allow health data processing for cycle, recovery, and sleep context", isOn: $formData.healthDataProcessingConsent)
                            .tint(WLPalette.tint)

                        Toggle("Allow analytics", isOn: $formData.analyticsConsent)
                            .tint(WLPalette.tint)

                        Toggle("Allow notifications", isOn: $formData.notificationsConsent)
                            .tint(WLPalette.tint)
                    }
                }

                editorSection(
                    title: WLProductCopy.ProfileEditor.prioritiesTitle,
                    subtitle: WLProductCopy.ProfileEditor.prioritiesSubtitle
                ) {
                    selectionGrid(
                        title: "Daily priorities",
                        values: DailyNutritionPriority.allCases,
                        selection: formData.nutritionPriorities,
                        titleFor: \.title
                    ) { priority in
                        toggle(priority, in: &formData.nutritionPriorities)
                    }
                }

                editorSection(
                    title: WLProductCopy.ProfileEditor.skinConcernsTitle,
                    subtitle: WLProductCopy.ProfileEditor.skinConcernsSubtitle
                ) {
                    selectionGrid(
                        title: "Skin concerns",
                        values: SkinConcern.allCases,
                        selection: formData.skinConcerns,
                        titleFor: \.title
                    ) { concern in
                        toggle(concern, in: &formData.skinConcerns)
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
                        onSave(formData.makeProfile(createdAt: createdAt))
                        dismiss()
                    }
                    .font(WLTypography.captionStrong)
                    .disabled(formData.goals.isEmpty)
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

    private func selectionGrid<T: CaseIterable & Hashable & Identifiable>(
        title: String,
        values: T.AllCases,
        selection: [T],
        titleFor: KeyPath<T, String>,
        action: @escaping (T) -> Void
    ) -> some View where T.AllCases: Collection, T.AllCases.Element == T {
        VStack(alignment: .leading, spacing: WLSpacing.s) {
            Text(title)
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.inkSoft)

            LazyVGrid(columns: columns, spacing: WLSpacing.s) {
                ForEach(Array(values)) { value in
                    WLSelectionChip(
                        title: value[keyPath: titleFor],
                        isSelected: selection.contains(value)
                    ) {
                        action(value)
                    }
                }
            }
        }
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

    private func toggle<T: CaseIterable & Hashable>(_ value: T, in values: inout [T])
    where T.AllCases: Collection, T.AllCases.Element == T {
        if let index = values.firstIndex(of: value) {
            values.remove(at: index)
        } else {
            values.append(value)
        }

        let selected = Set(values)
        values = Array(T.allCases).filter { selected.contains($0) }
    }
}

#Preview("Profile") {
    NavigationStack {
        ProfileView()
            .environment(AppModel())
    }
}
