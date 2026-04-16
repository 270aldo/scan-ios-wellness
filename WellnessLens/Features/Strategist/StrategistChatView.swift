import SwiftUI

private struct StrategistSurfacePlan {
    let badgeTitle: String
    let headline: String
    let summary: String
    let composerSeedTitle: String
    let composerSeedPrompt: String
    let composerPlaceholder: String
}

private struct StrategistContextCardData: Identifiable {
    let id = UUID()
    let badgeTitle: String
    let badgeSymbol: String
    let badgeTone: WLStatusBadge.Tone
    let title: String
    let summary: String
}

struct StrategistChatView: View {
    let entryPoint: StrategistEntryPoint
    var linkedAnalysis: ScanAnalysis? = nil

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""

    private var thread: ConversationThread {
        model.conversationThread(for: entryPoint)
    }

    private var linkedScanEvent: ScanEvent? {
        linkedAnalysis.flatMap { model.scanEvent(for: $0) }
    }

    private var latestPattern: PatternInsight? {
        if let linkedAnalysis {
            return model.leadingPatternInsight(for: linkedAnalysis)
        }
        return model.patternInsights.first
    }

    private var latestCheckIn: CheckInEvent? {
        model.checkInEvents.first
    }

    private var starterPrompts: [String] {
        model.strategistStarterPrompts(for: entryPoint, linkedAnalysis: linkedAnalysis)
    }

    private var contextCards: [StrategistContextCardData] {
        var cards = [StrategistContextCardData]()

        if let linkedAnalysis {
            cards.append(
                StrategistContextCardData(
                    badgeTitle: linkedVerdictTitle,
                    badgeSymbol: "viewfinder",
                    badgeTone: linkedVerdictTone,
                    title: linkedReadTitle(for: linkedAnalysis),
                    summary: linkedScanEvent?.analysis.whyToday.first ?? linkedAnalysis.overallSummary
                )
            )
        }

        if let weeklyNarrative = model.weeklyNarrative {
            cards.append(
                StrategistContextCardData(
                    badgeTitle: "Weekly layer",
                    badgeSymbol: "sparkles",
                    badgeTone: .accent,
                    title: weeklyNarrative.headline,
                    summary: weeklyNarrative.patternSummary
                )
            )
        }

        if let latestPattern {
            cards.append(
                StrategistContextCardData(
                    badgeTitle: latestPattern.signal.title,
                    badgeSymbol: "waveform.path.ecg.rectangle",
                    badgeTone: .accent,
                    title: latestPattern.title,
                    summary: latestPattern.summary
                )
            )
        }

        if let latestCheckIn {
            cards.append(
                StrategistContextCardData(
                    badgeTitle: "Latest body signal",
                    badgeSymbol: "heart.text.square",
                    badgeTone: .caution,
                    title: latestCheckIn.readHelpful == false ? "Recent read still feels off" : "Recent body signal",
                    summary: "Energy \(latestCheckIn.energy)/5 • Mood \(latestCheckIn.mood)/5 • Digestion \(latestCheckIn.bloating)/5 • Satiety \(latestCheckIn.satiety)/5"
                )
            )
        }

        return Array(cards.prefix(3))
    }

    private var presentation: StrategistSurfacePlan {
        if let linkedAnalysis {
            return StrategistSurfacePlan(
                badgeTitle: "Linked read",
                headline: "Turn this read into a real decision.",
                summary: "Ask whether \(linkedReadTitle(for: linkedAnalysis)) should stay, swap, or wait once today’s signal and weekly memory are taken into account.",
                composerSeedTitle: "Use linked read",
                composerSeedPrompt: "What is the single best next step for \(linkedAnalysis.resolvedProduct.name)?",
                composerPlaceholder: "Ask whether this should stay, swap, avoid, or get one more real-world repeat."
            )
        }

        if let weeklyNarrative = model.weeklyNarrative {
            return StrategistSurfacePlan(
                badgeTitle: "Weekly layer",
                headline: weeklyNarrative.headline,
                summary: weeklyNarrative.patternSummary,
                composerSeedTitle: "Use weekly focus",
                composerSeedPrompt: "What decision best protects \(weeklyNarrative.headline.lowercased()) today?",
                composerPlaceholder: "Ask what to protect, reduce, or test next based on the weekly layer."
            )
        }

        if let latestPattern {
            return StrategistSurfacePlan(
                badgeTitle: "Pattern signal",
                headline: latestPattern.title,
                summary: latestPattern.summary,
                composerSeedTitle: "Use latest pattern",
                composerSeedPrompt: "How should I use the \(latestPattern.signal.title.lowercased()) pattern in my next decision?",
                composerPlaceholder: "Ask what matters most now, what to avoid, or which choice deserves a calmer repeat."
            )
        }

        return StrategistSurfacePlan(
            badgeTitle: "Shared strategist",
            headline: "Ask for the next decision, not more noise.",
            summary: "This thread carries context across Home, Scan, Check-in, and Profile so the recommendation stays cumulative instead of resetting by surface.",
            composerSeedTitle: "Use today’s focus",
            composerSeedPrompt: "What’s the one decision that matters most today?",
            composerPlaceholder: "Ask for one action, one reason, or one swap recommendation."
        )
    }

    var body: some View {
        NavigationStack {
            WLScreen {
                hero

                if !contextCards.isEmpty {
                    contextSection
                }

                conversationSection

                if !starterPrompts.isEmpty {
                    promptSection
                }

                composer
            }
            .navigationTitle(entryPoint.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: dismiss.callAsFunction)
                        .font(WLTypography.captionStrong)
                }
            }
        }
    }

    private var hero: some View {
        WLHeroSurface {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: presentation.badgeTitle,
                            systemImage: "sparkles",
                            tone: .accent,
                            style: .heroGlass
                        )

                        WLPill(title: "Shared thread", tone: .neutral, style: .heroGlass)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: presentation.badgeTitle,
                            systemImage: "sparkles",
                            tone: .accent,
                            style: .heroGlass
                        )

                        WLPill(title: "Shared thread", tone: .neutral, style: .heroGlass)
                    }
                }

                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    Text(presentation.headline)
                        .font(WLTypography.hero)
                        .foregroundStyle(.white)

                    Text(presentation.summary)
                        .font(WLTypography.body)
                        .foregroundStyle(Color.white.opacity(0.88))
                }
            }
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "What strategist is using right now",
                subtitle: "Ground the answer in live context, not just the surface that opened chat.",
                systemImage: "brain.head.profile"
            )

            ForEach(contextCards) { card in
                StrategistContextCard(card: card)
            }
        }
    }

    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Conversation",
                subtitle: "One shared strategist thread across Home, Scan, Check-in, and Profile.",
                systemImage: "message"
            )

            ForEach(thread.messages) { message in
                StrategistMessageBubble(message: message)
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Suggested prompts",
                subtitle: "Tuned to the current read, weekly layer, and latest body signal.",
                systemImage: "sparkles"
            )

            ForEach(starterPrompts, id: \.self) { prompt in
                Button {
                    draft = prompt
                } label: {
                    HStack(spacing: WLSpacing.s) {
                        Text(prompt)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.ink)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        WLIcon(systemName: "arrow.up.left", color: WLPalette.rose, size: 14)
                    }
                    .padding(WLSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .wlCardSurface(
                        fill: LinearGradient(
                            colors: [Color.white.opacity(0.98), WLPalette.surfaceMuted],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        shadowColor: WLElevation.shadow.opacity(0.30),
                        radius: WLCorner.m
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var composer: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Ask something specific",
                    subtitle: "Ask for one action, one reason, or one swap.",
                    systemImage: "text.bubble"
                )

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $draft)
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

                    if draft.isEmpty {
                        Text(presentation.composerPlaceholder)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WLSpacing.s) {
                        WLSecondaryButton(title: presentation.composerSeedTitle) {
                            draft = presentation.composerSeedPrompt
                        }

                        WLPrimaryButton(title: "Send", systemImage: "arrow.up.circle.fill") {
                            sendMessage()
                        }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    VStack(spacing: WLSpacing.s) {
                        WLPrimaryButton(title: "Send", systemImage: "arrow.up.circle.fill") {
                            sendMessage()
                        }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        WLSecondaryButton(title: presentation.composerSeedTitle) {
                            draft = presentation.composerSeedPrompt
                        }
                    }
                }
            }
        }
    }

    private var linkedVerdictTitle: String {
        switch linkedScanEvent?.analysis.verdict {
        case .good:
            return "Strong fit"
        case .adjust:
            return "Adjustable fit"
        case .avoid:
            return "Lower-fit"
        case .needsMoreInfo:
            return "Needs more input"
        case nil:
            return "Current read"
        }
    }

    private var linkedVerdictTone: WLStatusBadge.Tone {
        switch linkedScanEvent?.analysis.verdict {
        case .good:
            return .success
        case .adjust, .needsMoreInfo:
            return .accent
        case .avoid:
            return .caution
        case nil:
            return .accent
        }
    }

    private func linkedReadTitle(for analysis: ScanAnalysis) -> String {
        switch analysis.source {
        case .mealPhoto:
            return "Meal Snapshot"
        case .menuPhoto:
            return "Menu Scanner"
        default:
            return analysis.resolvedProduct.name
        }
    }

    private func sendMessage() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.sendStrategistMessage(trimmed, entryPoint: entryPoint, linkedAnalysis: linkedAnalysis)
        draft = ""
    }
}

private struct StrategistContextCard: View {
    let card: StrategistContextCardData

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                WLStatusBadge(
                    title: card.badgeTitle,
                    systemImage: card.badgeSymbol,
                    tone: card.badgeTone
                )

                Text(card.title)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text(card.summary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)
            }
        }
    }
}

private struct StrategistMessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack {
            if message.speaker == .strategist {
                bubble(horizontal: .leading, frameAlignment: .leading, fill: strategistFill, foreground: WLPalette.ink)
                Spacer(minLength: 32)
            } else {
                Spacer(minLength: 32)
                bubble(horizontal: .trailing, frameAlignment: .trailing, fill: userFill, foreground: .white)
            }
        }
    }

    private var strategistFill: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.98), WLPalette.surfaceMuted],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var userFill: LinearGradient {
        LinearGradient(
            colors: [WLPalette.rose, Color(red: 0.862, green: 0.436, blue: 0.700)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func bubble(
        horizontal: HorizontalAlignment,
        frameAlignment: Alignment,
        fill: LinearGradient,
        foreground: Color
    ) -> some View {
        VStack(alignment: horizontal, spacing: WLSpacing.xs) {
            Text(message.speaker == .strategist ? "Strategist" : "You")
                .font(WLTypography.captionStrong)
                .foregroundStyle(message.speaker == .strategist ? WLPalette.rose : Color.white.opacity(0.88))

            Text(message.text)
                .font(WLTypography.body)
                .foregroundStyle(foreground)
                .multilineTextAlignment(horizontal == .leading ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(WLSpacing.m)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .background(
            RoundedRectangle(cornerRadius: WLCorner.l, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WLCorner.l, style: .continuous)
                .stroke(message.speaker == .strategist ? WLPalette.stroke : Color.white.opacity(0.16))
        )
    }
}
