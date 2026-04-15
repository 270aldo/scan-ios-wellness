import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var showContextEditor = false

    var body: some View {
        WLScreen {
            contextCard
            subscriptionCard
            howItWorksCard
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showContextEditor) {
            ProfileContextEditor(
                context: model.userContext,
                onSave: { model.updateUserContext($0) }
            )
        }
    }

    private var contextCard: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                HStack(alignment: .top) {
                    WLSectionHeader(
                        title: WLProductCopy.Profile.yourLensTitle,
                        subtitle: WLProductCopy.Profile.yourLensSubtitle,
                        systemImage: "line.3.horizontal.decrease.circle"
                    )

                    Spacer()

                    WLSecondaryButton(title: "Edit") {
                        showContextEditor = true
                    }
                    .frame(maxWidth: 96)
                }

                profileRow(label: "Goals", value: model.userContext.goals.map(\.title).joined(separator: ", "))
                profileRow(label: "Sensitivities", value: model.userContext.sensitivities.map(\.title).joined(separator: ", "))
                profileRow(label: "Diet style", value: model.userContext.dietStyle.title)
                profileRow(label: "Skin concerns", value: model.userContext.skinConcerns.map(\.title).joined(separator: ", "))
                profileRow(label: "Life stage", value: model.userContext.lifeStage.title)
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

                Text("Unlock richer product reads, more refined framing, and a more premium ongoing ritual as pricing becomes available.")
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

    private var howItWorksCard: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: WLProductCopy.Profile.howItWorksTitle,
                    subtitle: WLProductCopy.Profile.howItWorksSubtitle,
                    systemImage: "sparkles"
                )

                profileRow(
                    label: "What shapes a read",
                    value: "Your goals, sensitivities, life context, product type, and available label detail all influence the framing."
                )

                profileRow(
                    label: "What becomes smarter over time",
                    value: "Saved reads and check-ins help signals become more coherent and more personal."
                )

                profileRow(
                    label: "How capture works today",
                    value: model.services.configuration.useDemoData
                        ? "You can explore guided sample reads alongside live barcode, OCR, and manual fallback paths."
                        : "Barcode, label OCR, and manual text all feed the same personal read flow."
                )

                if model.services.configuration.isFirebaseEnabled || model.services.configuration.isStoreKitEnabled {
                    profileRow(
                        label: "Connected services",
                        value: [
                            model.services.configuration.isFirebaseEnabled ? "Firebase" : nil,
                            model.services.configuration.isStoreKitEnabled ? "StoreKit" : nil
                        ]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                    )
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
        }
    }
}

private struct ProfileContextEditor: View {
    let onSave: (UserContext) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedGoals: Set<UserGoal>
    @State private var selectedSensitivities: Set<SensitivityFlag>
    @State private var selectedSkinConcerns: Set<SkinConcern>
    @State private var dietStyle: DietStyle
    @State private var lifeStage: LifeStage
    @State private var optInCycleAware: Bool

    private let columns = [GridItem(.adaptive(minimum: 148), spacing: WLSpacing.s)]

    init(context: UserContext, onSave: @escaping (UserContext) -> Void) {
        self.onSave = onSave
        _selectedGoals = State(initialValue: Set(context.goals))
        _selectedSensitivities = State(initialValue: Set(context.sensitivities))
        _selectedSkinConcerns = State(initialValue: Set(context.skinConcerns))
        _dietStyle = State(initialValue: context.dietStyle)
        _lifeStage = State(initialValue: context.lifeStage)
        _optInCycleAware = State(initialValue: context.optInCycleAware)
    }

    var body: some View {
        NavigationStack {
            WLScreen {
                editorSection(
                    title: "Goals",
                    subtitle: "The outcomes WellnessLens should favor first when it builds a read."
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
                    title: "Sensitivities",
                    subtitle: "The places where you want a softer or more cautious read by default."
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
                    title: "Skin concerns",
                    subtitle: "Optional vanity context that helps topical reads feel more personal."
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

                editorSection(
                    title: "Context",
                    subtitle: "A little framing that makes each read feel more tailored without becoming clinical."
                ) {
                    VStack(alignment: .leading, spacing: WLSpacing.l) {
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

                        Toggle("Include cycle-aware framing when available", isOn: $optInCycleAware)
                            .tint(WLPalette.tint)
                    }
                }
            }
            .navigationTitle("Edit your lens")
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
                        onSave(
                            UserContext(
                                goals: Array(selectedGoals),
                                sensitivities: Array(selectedSensitivities),
                                dietStyle: dietStyle,
                                skinConcerns: Array(selectedSkinConcerns),
                                lifeStage: lifeStage,
                                optInCycleAware: optInCycleAware
                            )
                        )
                        dismiss()
                    }
                    .font(WLTypography.captionStrong)
                    .disabled(selectedGoals.isEmpty)
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
