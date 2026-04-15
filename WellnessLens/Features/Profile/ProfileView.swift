import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var showContextEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                subscriptionCard
                contextCard
                integrationCard
            }
            .padding(20)
        }
        .navigationTitle("Profile")
        .background(Color(red: 0.98, green: 0.97, blue: 0.99))
        .sheet(isPresented: $showContextEditor) {
            ProfileContextEditor(
                context: model.userContext,
                onSave: { model.updateUserContext($0) }
            )
        }
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription")
                .font(.headline)
            Text("Current plan: \(model.subscriptionStatus.title)")
                .font(.title3.bold())
            Text("Demo paywall state is live. Swap the demo controller for StoreKit 2 products when real pricing is ready.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Unlock Plus") {
                    Task {
                        await model.purchase(.plus)
                    }
                }
                .buttonStyle(.bordered)

                Button("Unlock Pro") {
                    Task {
                        await model.purchase(.pro)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Restore purchases") {
                Task {
                    await model.restorePurchases()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personal context")
                    .font(.headline)
                Spacer()
                Button("Edit") {
                    showContextEditor = true
                }
                .buttonStyle(.bordered)
            }
            profileRow(label: "Goals", value: model.userContext.goals.map(\.title).joined(separator: ", "))
            profileRow(label: "Sensitivities", value: model.userContext.sensitivities.map(\.title).joined(separator: ", "))
            profileRow(label: "Diet style", value: model.userContext.dietStyle.title)
            profileRow(label: "Skin concerns", value: model.userContext.skinConcerns.map(\.title).joined(separator: ", "))
            profileRow(label: "Life stage", value: model.userContext.lifeStage.title)
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var integrationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Production seams")
                .font(.headline)
            Text("This scaffold is ready to graduate to Firebase Auth, Firestore, Functions, Storage, Remote Config, and App Check. Gemini stays behind the parsing boundary instead of owning the score.")
                .foregroundStyle(.secondary)
            profileRow(
                label: "Backend mode",
                value: model.services.configuration.useDemoData ? "Demo resolver active" : (model.services.configuration.backendBaseURL?.absoluteString ?? "Missing backend URL")
            )
            profileRow(
                label: "Firebase",
                value: model.services.configuration.isFirebaseEnabled ? "Enabled" : "Disabled"
            )
            profileRow(
                label: "StoreKit",
                value: model.services.configuration.isStoreKitEnabled ? "Enabled" : "Demo subscription controller"
            )
            Label("App Intents wired for scan, history, and insight entry points", systemImage: "sparkles")
            Label("Local OCR fallback already runs through Vision", systemImage: "text.viewfinder")
            Label("History and check-ins already persist locally", systemImage: "internaldrive")
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func profileRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "Not set" : value)
                .font(.subheadline)
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

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    editorSection(title: "Goals") {
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
                    }

                    editorSection(title: "Sensitivities") {
                        LazyVGrid(columns: columns, spacing: 12) {
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

                    editorSection(title: "Skin concerns") {
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

                    editorSection(title: "Context") {
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
                    }
                }
                .padding(20)
            }
            .navigationTitle("Edit context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
                    .disabled(selectedGoals.isEmpty)
                }
            }
            .background(Color(red: 0.98, green: 0.97, blue: 0.99))
        }
    }

    private func editorSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}
