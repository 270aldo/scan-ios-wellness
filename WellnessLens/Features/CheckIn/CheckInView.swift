import SwiftUI

private enum CheckInMoment: String, CaseIterable, Identifiable {
    case morning
    case evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning:
            "Morning"
        case .evening:
            "Evening"
        }
    }

    var subtitle: String {
        switch self {
        case .morning:
            "Set the lens for the day before your next product decision."
        case .evening:
            "Close the loop on how the day actually felt."
        }
    }
}

struct CheckInView: View {
    @Environment(AppModel.self) private var model

    @State private var moment: CheckInMoment = .morning
    @State private var energy = 3
    @State private var skin = 3
    @State private var bloatingRelief = 3
    @State private var cravingControl = 3
    @State private var mood = 3
    @State private var note = ""
    @State private var showSavedState = false
    @State private var strategistEntryPoint: StrategistEntryPoint?

    private var shouldShowSkinMetric: Bool {
        model.userContext.goals.contains(.clearSkin) || !model.userContext.skinConcerns.isEmpty
    }

    var body: some View {
        WLScreen {
            hero

            metricGrid

            if shouldShowSkinMetric {
                CheckInMetricCard(
                    title: "Skin",
                    selection: $skin,
                    leftLabel: "Reactive",
                    rightLabel: "Calm",
                    states: ["Reactive", "Tender", "Neutral", "Comfortable", "Calm"]
                )
            }

            noteCard

            if !model.dailyHomePayload.openLoops.isEmpty {
                CheckInOpenLoopCard(openLoop: model.dailyHomePayload.openLoops[0])
            }

            if !model.weeklyInsights.isEmpty {
                CheckInInsightsCard(insight: model.weeklyInsights[0])
            }
        }
        .navigationTitle(WLProductCopy.CheckIn.title)
        .sheet(item: $strategistEntryPoint) { entryPoint in
            StrategistChatView(entryPoint: entryPoint)
        }
    }

    private var hero: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                HStack(spacing: WLSpacing.s) {
                    WLStatusBadge(title: "Daily check-in", systemImage: "heart", tone: .accent)

                    if showSavedState {
                        WLStatusBadge(title: "Saved", systemImage: "checkmark.circle", tone: .success)
                    }
                }

                Text(model.dailyHomePayload.bodySignal.title)
                    .font(WLTypography.title)
                    .foregroundStyle(WLPalette.ink)

                Text(model.dailyHomePayload.bodySignal.summary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                Picker("Moment", selection: $moment) {
                    ForEach(CheckInMoment.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Text(moment.subtitle)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
            }
        }
    }

    private var metricGrid: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Core signals",
                subtitle: "Keep it short. The goal is signal quality, not journaling homework.",
                systemImage: "waveform.path.ecg"
            )

            CheckInMetricCard(
                title: "Energy",
                selection: $energy,
                leftLabel: "Drained",
                rightLabel: "Steady",
                states: ["Drained", "Low", "Even", "Good", "Steady"]
            )

            CheckInMetricCard(
                title: "Digestion",
                selection: $bloatingRelief,
                leftLabel: "Heavy",
                rightLabel: "Calm",
                states: ["Heavy", "Off", "Mixed", "Lighter", "Calm"]
            )

            CheckInMetricCard(
                title: "Cravings",
                selection: $cravingControl,
                leftLabel: "Loud",
                rightLabel: "Quiet",
                states: ["Loud", "Distracting", "Mixed", "Manageable", "Quiet"]
            )

            CheckInMetricCard(
                title: "Mood",
                selection: $mood,
                leftLabel: "Flat",
                rightLabel: "Lifted",
                states: ["Flat", "Low", "Even", "Good", "Lifted"]
            )
        }
    }

    private var noteCard: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Optional note",
                    subtitle: "Only add context if there is something you want the strategist to remember later.",
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
                        Text(moment == .morning ? "Anything you want today’s scans to take seriously?" : "What felt off, easier, or repeatable today?")
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }

                HStack(spacing: WLSpacing.s) {
                    WLSecondaryButton(title: "Ask strategist", systemImage: "message") {
                        strategistEntryPoint = .checkIn
                    }

                    WLPrimaryButton(title: "Save check-in", systemImage: "checkmark") {
                        saveCheckIn()
                    }
                }
            }
        }
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

private struct CheckInOpenLoopCard: View {
    let openLoop: OpenLoop

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                WLSectionHeader(
                    title: "Open loop to keep in mind",
                    subtitle: "Check-ins are strongest when they connect to an actual decision the app is tracking.",
                    systemImage: "ellipsis.circle"
                )

                Text(openLoop.title)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text(openLoop.summary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)
            }
        }
    }
}

private struct CheckInInsightsCard: View {
    let insight: WeeklyInsight

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                WLSectionHeader(
                    title: insight.title,
                    subtitle: "The weekly layer should become sharper as scans and check-ins repeat.",
                    systemImage: "sparkles"
                )

                Text(insight.summary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                Text(insight.callToAction)
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.rose)
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
