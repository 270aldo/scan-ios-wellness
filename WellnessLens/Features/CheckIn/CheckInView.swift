import SwiftUI

struct CheckInView: View {
    @Environment(AppModel.self) private var model

    @State private var energy = 3
    @State private var skin = 3
    @State private var bloatingRelief = 3
    @State private var cravingControl = 3
    @State private var mood = 3
    @State private var note = ""
    @State private var showSavedState = false

    var body: some View {
        WLScreen {
            WLPrimaryCard {
                VStack(alignment: .leading, spacing: WLSpacing.m) {
                    WLStatusBadge(title: "Daily check-in", systemImage: "heart", tone: .accent)

                    Text(WLProductCopy.CheckIn.heroTitle)
                        .font(WLTypography.title)
                        .foregroundStyle(WLPalette.ink)

                    Text(WLProductCopy.CheckIn.heroSubtitle)
                        .font(WLTypography.body)
                        .foregroundStyle(WLPalette.inkSoft)

                    if showSavedState {
                        WLStatusBadge(title: "Check-in saved", systemImage: "checkmark.circle", tone: .success)
                    }
                }
            }

            CheckInMetricCard(
                title: "Energy",
                selection: $energy,
                leftLabel: "Drained",
                rightLabel: "Steady",
                states: ["Drained", "Low", "Even", "Good", "Steady"]
            )

            CheckInMetricCard(
                title: "Skin",
                selection: $skin,
                leftLabel: "Irritated",
                rightLabel: "Clear",
                states: ["Irritated", "Reactive", "Neutral", "Comfortable", "Clear"]
            )

            CheckInMetricCard(
                title: "Bloating relief",
                selection: $bloatingRelief,
                leftLabel: "Uncomfortable",
                rightLabel: "Calm",
                states: ["Uncomfortable", "Heavy", "Mixed", "Lighter", "Calm"]
            )

            CheckInMetricCard(
                title: "Craving control",
                selection: $cravingControl,
                leftLabel: "Constant",
                rightLabel: "Stable",
                states: ["Constant", "Distracting", "Mixed", "Manageable", "Stable"]
            )

            CheckInMetricCard(
                title: "Mood",
                selection: $mood,
                leftLabel: "Flat",
                rightLabel: "Lifted",
                states: ["Flat", "Low", "Even", "Good", "Lifted"]
            )

            WLCompactCard {
                VStack(alignment: .leading, spacing: WLSpacing.m) {
                    WLSectionHeader(
                        title: "Optional note",
                        subtitle: "Anything contextual you want your future reads to remember about today.",
                        systemImage: "square.and.pencil"
                    )

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $note)
                            .frame(minHeight: 120)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                    .fill(WLPalette.surfaceMuted)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                    .stroke(WLPalette.stroke)
                            )

                        if note.isEmpty {
                            Text("How did today feel?")
                                .font(WLTypography.body)
                                .foregroundStyle(WLPalette.inkSoft)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 24)
                                .allowsHitTesting(false)
                        }
                    }

                    WLPrimaryButton(title: "Save check-in", systemImage: "checkmark") {
                        saveCheckIn()
                    }
                }
            }

            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Signals this week",
                    subtitle: "These read more clearly as your product reads and check-ins start repeating.",
                    systemImage: "waveform.path.ecg"
                )

                ForEach(model.weeklyInsights) { insight in
                    WLCompactCard {
                        VStack(alignment: .leading, spacing: WLSpacing.s) {
                            Text(insight.title)
                                .font(WLTypography.bodyEmphasis)
                                .foregroundStyle(WLPalette.ink)

                            Text(insight.summary)
                                .font(WLTypography.body)
                                .foregroundStyle(WLPalette.inkSoft)
                        }
                    }
                }
            }
        }
        .navigationTitle(WLProductCopy.CheckIn.title)
    }

    private func saveCheckIn() {
        model.addCheckIn(
            energy: energy,
            skin: skin,
            bloatingRelief: bloatingRelief,
            cravingControl: cravingControl,
            mood: mood,
            note: note
        )

        note = ""
        showSavedState = true

        Task {
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    showSavedState = false
                }
            }
        }
    }
}

private struct CheckInMetricCard: View {
    let title: String
    @Binding var selection: Int
    let leftLabel: String
    let rightLabel: String
    let states: [String]

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                HStack(alignment: .center) {
                    Text(title)
                        .font(WLTypography.bodyEmphasis)
                        .foregroundStyle(WLPalette.ink)

                    Spacer()

                    Text(states[selection - 1])
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(WLPalette.rose)
                }

                HStack(spacing: WLSpacing.s) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                                selection = value
                            }
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(selection == value ? Color.white : WLPalette.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            selection == value
                                                ? AnyShapeStyle(
                                                    LinearGradient(
                                                        colors: [WLPalette.rose, Color(red: 0.862, green: 0.436, blue: 0.700)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                : AnyShapeStyle(Color.white.opacity(0.9))
                                        )
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(selection == value ? Color.white.opacity(0.12) : WLPalette.strokeStrong)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text(leftLabel)
                    Spacer()
                    Text(rightLabel)
                }
                .font(WLTypography.caption)
                .foregroundStyle(WLPalette.inkSoft)
            }
        }
    }
}

#Preview("Check-In") {
    NavigationStack {
        CheckInView()
            .environment(AppModel())
    }
}
