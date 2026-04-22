import SwiftUI

private enum StrategistScrollAnchor {
    static let bottom = "strategist.transcript.bottom"
}

private struct StrategistSurfacePlan {
    let badgeTitle: String
    let headline: String
    let summary: String
    let composerSeedTitle: String
    let composerSeedPrompt: String
    let composerPlaceholder: String
}

private struct StrategistContextPillData: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tone: WLStatusBadge.Tone
}

private enum StrategistVoiceDockStatus {
    case future
    case thinking
    case ready(voiceTags: [CoachVoiceTag], hasSpokenVersion: Bool)

    var title: String {
        switch self {
        case .future:
            return "Voice dock ready"
        case .thinking:
            return "Strategist is thinking"
        case let .ready(voiceTags, hasSpokenVersion):
            if hasSpokenVersion {
                return voiceTags.isEmpty ? "Playback shell ready" : "Playback shell • \(Self.voiceTagsTitle(voiceTags))"
            }
            return voiceTags.isEmpty ? "Voice-ready shell" : "Voice-ready • \(Self.voiceTagsTitle(voiceTags))"
        }
    }

    var subtitle: String {
        switch self {
        case .future:
            return "Mic, transcript, and playback stay visible so voice-first mode can land cleanly later."
        case .thinking:
            return "The next reply is still in flight. The dock is already reserving room for transcript and speech."
        case let .ready(_, hasSpokenVersion):
            return hasSpokenVersion
                ? "This reply already carries voice metadata, so the future player can sit on top of the real contract."
                : "The contract already carries voice tags and directives, even before audio playback is turned on."
        }
    }

    var accentColor: Color {
        switch self {
        case .future:
            return WLPalette.inkSoft
        case .thinking:
            return WLPalette.rose
        case .ready:
            return WLPalette.lilac
        }
    }

    var caption: String {
        switch self {
        case .future:
            return "Listening shell"
        case .thinking:
            return "Thinking"
        case .ready:
            return "Speaking shell"
        }
    }

    private static func voiceTagsTitle(_ voiceTags: [CoachVoiceTag]) -> String {
        voiceTags.prefix(2).map { $0.rawValue.capitalized }.joined(separator: " • ")
    }
}

struct StrategistChatView: View {
    let entryPoint: StrategistEntryPoint
    var linkedAnalysis: ScanAnalysis? = nil

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @FocusState private var isComposerFocused: Bool

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

    private var introPrompts: [String] {
        Array(starterPrompts.prefix(3))
    }

    private var showsIntroState: Bool {
        !thread.messages.contains(where: { $0.speaker == .user })
    }

    private var pendingReplyCount: Int {
        thread.messages.reduce(into: 0) { count, message in
            if message.speaker == .user, model.isAwaitingStrategistReply(to: message.id) {
                count += 1
            }
        }
    }

    private var lastStrategistPayload: ConversationMessageCoachPayload? {
        thread.messages.last(where: { $0.speaker == .strategist })?.coachPayload
    }

    private var bubbleMaxWidth: CGFloat {
        312
    }

    private var voiceDockStatus: StrategistVoiceDockStatus {
        if pendingReplyCount > 0 {
            return .thinking
        }

        if let payload = lastStrategistPayload, payload.hasVoiceMetadata {
            return .ready(
                voiceTags: payload.voiceTags,
                hasSpokenVersion: payload.spokenVersion != nil
            )
        }

        return .future
    }

    private var openingMessage: ConversationMessage? {
        thread.messages.first(where: { $0.speaker == .strategist })
    }

    private var contextPills: [StrategistContextPillData] {
        var pills = [StrategistContextPillData]()

        if linkedAnalysis != nil {
            pills.append(
                StrategistContextPillData(
                    title: linkedVerdictTitle,
                    systemImage: "viewfinder",
                    tone: linkedVerdictTone
                )
            )
        }

        if model.weeklyNarrative != nil {
            pills.append(
                StrategistContextPillData(
                    title: "Weekly layer",
                    systemImage: "sparkles",
                    tone: .accent
                )
            )
        }

        if let latestPattern {
            pills.append(
                StrategistContextPillData(
                    title: latestPattern.signal.title,
                    systemImage: "waveform.path.ecg.rectangle",
                    tone: .accent
                )
            )
        }

        if latestCheckIn != nil {
            pills.append(
                StrategistContextPillData(
                    title: "Body signal",
                    systemImage: "heart.text.square",
                    tone: .caution
                )
            )
        }

        return Array(pills.prefix(3))
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
            summary: "This thread carries context across Home, Scan, Check-In, and Profile so the recommendation stays cumulative instead of resetting by surface.",
            composerSeedTitle: "Use today’s focus",
            composerSeedPrompt: "What’s the one decision that matters most today?",
            composerPlaceholder: "Ask for one action, one reason, or one swap recommendation."
        )
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollViewReader { scrollView in
                    ZStack {
                        WLScreenBackground()

                        transcriptSection
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                    .clipped()
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        StrategistComposerDock(
                            draft: $draft,
                            isFocused: $isComposerFocused,
                            voiceStatus: voiceDockStatus,
                            placeholder: presentation.composerPlaceholder,
                            seedTitle: presentation.composerSeedTitle,
                            seedPrompt: presentation.composerSeedPrompt,
                            sendMessage: sendMessage,
                            seedPromptAction: seedPrompt
                        )
                        .frame(width: max(proxy.size.width - (WLSpacing.l * 2), 0), alignment: .leading)
                        .padding(.horizontal, WLSpacing.l)
                        .padding(.top, WLSpacing.s)
                        .padding(.bottom, WLSpacing.s)
                        .background(composerBackground)
                    }
                    .navigationTitle("Strategist")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done", action: dismiss.callAsFunction)
                                .font(WLTypography.captionStrong)
                        }
                    }
                    .onAppear {
                        scrollTranscript(using: scrollView, animated: false)
                    }
                    .onChange(of: thread.messages.count) { _, _ in
                        scrollTranscript(using: scrollView)
                    }
                    .onChange(of: pendingReplyCount) { _, _ in
                        scrollTranscript(using: scrollView)
                    }
                }
            }
        }
    }

    private var transcriptSection: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                    if showsIntroState {
                        StrategistHeroCard(
                            plan: presentation,
                            contextPills: contextPills
                        )

                        StrategistOpeningCard(message: openingMessage?.text ?? presentation.summary)

                        if !introPrompts.isEmpty {
                            StrategistQuickStartCard(
                                prompts: introPrompts,
                                sendPrompt: sendPromptImmediately
                            )
                        }
                    } else {
                        StrategistThreadHeaderCard(
                            plan: presentation,
                            contextPills: contextPills
                        )

                        ForEach(thread.messages) { message in
                            StrategistMessageRow(
                                message: message,
                                maxBubbleWidth: bubbleMaxWidth,
                                supportedTab: model.supportedStrategistTab(for:),
                                performSuggestedAction: handleSuggestedAction
                            )

                            if message.speaker == .user,
                               model.isAwaitingStrategistReply(to: message.id) {
                                StrategistThinkingRow(maxBubbleWidth: bubbleMaxWidth)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(StrategistScrollAnchor.bottom)
                }
                .frame(width: max(proxy.size.width - (WLSpacing.l * 2), 0), alignment: .leading)
                .padding(.horizontal, WLSpacing.l)
                .padding(.top, WLSpacing.l)
                .padding(.bottom, WLSpacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var composerBackground: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.0), Color.white.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 18)

            Rectangle()
                .fill(WLPalette.canvasWarm.opacity(0.94))
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WLPalette.stroke.opacity(0.8))
                .frame(height: 1)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func scrollTranscript(using scrollView: ScrollViewProxy, animated: Bool = true) {
        DispatchQueue.main.async {
            let action = {
                scrollView.scrollTo(StrategistScrollAnchor.bottom, anchor: .bottomLeading)
            }

            if animated {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    action()
                }
            } else {
                action()
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
            return "Meal snapshot"
        case .menuPhoto:
            return "Menu scan"
        default:
            return analysis.resolvedProduct.name
        }
    }

    private func seedPrompt() {
        draft = presentation.composerSeedPrompt
        isComposerFocused = true
    }

    private func sendPromptImmediately(_ prompt: String) {
        model.sendStrategistPrompt(prompt, entryPoint: entryPoint, linkedAnalysis: linkedAnalysis)
        draft = ""
    }

    private func sendMessage() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.sendStrategistMessage(trimmed, entryPoint: entryPoint, linkedAnalysis: linkedAnalysis)
        draft = ""
    }

    private func handleSuggestedAction(_ action: CoachSuggestedAction) {
        guard let tab = model.supportedStrategistTab(for: action) else { return }
        model.selectedTab = tab
        dismiss()
    }
}

private struct StrategistHeroCard: View {
    let plan: StrategistSurfacePlan
    let contextPills: [StrategistContextPillData]

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            StrategistBadgeStrip(
                primaryTitle: plan.badgeTitle,
                primarySystemImage: "sparkles",
                primaryTone: .accent,
                supportingPillTitle: "Shared thread",
                contextPills: contextPills
            )

            Text(plan.headline)
                .font(WLTypography.hero)
                .foregroundStyle(WLPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(plan.summary)
                .font(WLTypography.body)
                .foregroundStyle(WLPalette.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(WLSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wlCardSurface(
            fill: LinearGradient(
                colors: [Color.white.opacity(0.96), WLPalette.canvasWarm.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            shadowColor: WLElevation.heroShadow.opacity(0.18),
            radius: WLCorner.xl
        )
    }
}

private struct StrategistOpeningCard: View {
    let message: String

    var body: some View {
        WLSecondarySurfaceCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                HStack(spacing: WLSpacing.xs) {
                    WLIcon(systemName: "quote.bubble", color: WLPalette.rose, size: 13)
                    Text("Opening read")
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(WLPalette.rose)
                }

                Text(message)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct StrategistQuickStartCard: View {
    let prompts: [String]
    let sendPrompt: (String) -> Void

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Quick starts",
                    subtitle: "Start with one concrete decision so the strategist can answer instead of speculate.",
                    systemImage: "bolt"
                )

                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button(action: { sendPrompt(prompt) }) {
                            HStack(alignment: .top, spacing: WLSpacing.s) {
                                Text(prompt)
                                    .font(WLTypography.bodyEmphasis)
                                    .foregroundStyle(WLPalette.ink)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: WLSpacing.s)

                                WLIcon(systemName: "arrow.up.left", color: WLPalette.rose, size: 13)
                                    .padding(.top, 2)
                            }
                            .padding(WLSpacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.98), WLPalette.surfaceMuted],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                    .stroke(WLPalette.stroke)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct StrategistThreadHeaderCard: View {
    let plan: StrategistSurfacePlan
    let contextPills: [StrategistContextPillData]

    var body: some View {
        WLSecondarySurfaceCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                StrategistBadgeStrip(
                    primaryTitle: plan.badgeTitle,
                    primarySystemImage: "brain.head.profile",
                    primaryTone: .accent,
                    contextPills: contextPills
                )

                Text(plan.headline)
                    .font(WLTypography.title)
                    .foregroundStyle(WLPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(plan.summary)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct StrategistBadgeStrip: View {
    let primaryTitle: String
    let primarySystemImage: String
    let primaryTone: WLStatusBadge.Tone
    var supportingPillTitle: String? = nil
    let contextPills: [StrategistContextPillData]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WLSpacing.s) {
                WLStatusBadge(
                    title: primaryTitle,
                    systemImage: primarySystemImage,
                    tone: primaryTone
                )

                if let supportingPillTitle {
                    WLPill(title: supportingPillTitle, tone: .soft)
                }

                ForEach(contextPills) { pill in
                    WLStatusBadge(
                        title: pill.title,
                        systemImage: pill.systemImage,
                        tone: pill.tone
                    )
                }
            }
            .padding(.vertical, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .scrollIndicators(.hidden)
    }
}

private struct StrategistMessageRow: View {
    let message: ConversationMessage
    let maxBubbleWidth: CGFloat
    let supportedTab: (CoachSuggestedAction) -> AppTab?
    let performSuggestedAction: (CoachSuggestedAction) -> Void

    private var isStrategist: Bool {
        message.speaker == .strategist
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: WLSpacing.s) {
            if isStrategist {
                bubble
                Spacer(minLength: 44)
            } else {
                Spacer(minLength: 44)
                bubble
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var bubble: some View {
        VStack(alignment: isStrategist ? .leading : .trailing, spacing: WLSpacing.s) {
            topMetaRow

            if let referencedVerdictSummary = message.coachPayload?.referencedVerdictSummary,
               !referencedVerdictSummary.isEmpty,
               isStrategist {
                Text(referencedVerdictSummary)
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.inkSoft)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(message.text)
                .font(WLTypography.body)
                .foregroundStyle(isStrategist ? WLPalette.ink : .white)
                .multilineTextAlignment(isStrategist ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)

            if let followUpQuestion = message.coachPayload?.followUpQuestion,
               !followUpQuestion.isEmpty,
               isStrategist {
                Text(followUpQuestion)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.rose)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let referencedPatterns = message.coachPayload?.referencedPatterns,
               !referencedPatterns.isEmpty,
               isStrategist {
                Text(referencedPatterns.joined(separator: " • "))
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let coachPayload = message.coachPayload,
               !coachPayload.suggestedActions.isEmpty,
               isStrategist {
                VStack(alignment: .leading, spacing: WLSpacing.xs) {
                    ForEach(Array(coachPayload.suggestedActions.enumerated()), id: \.offset) { _, action in
                        StrategistSuggestedActionRow(
                            action: action,
                            isSupported: supportedTab(action) != nil,
                            performSuggestedAction: performSuggestedAction
                        )
                    }
                }
            }

            if let coachPayload = message.coachPayload,
               coachPayload.hasSafetyNotice,
               isStrategist {
                VStack(alignment: .leading, spacing: WLSpacing.xs) {
                    HStack(spacing: WLSpacing.xs) {
                        WLIcon(systemName: "shield.lefthalf.filled", color: WLPalette.caution, size: 12)
                        Text("Safety note")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.caution)
                    }

                    Text(coachPayload.disclaimer)
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(WLSpacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WLPalette.caution.opacity(0.14))
                )
            }
        }
        .padding(WLSpacing.m)
        .frame(maxWidth: maxBubbleWidth, alignment: isStrategist ? .leading : .trailing)
        .background(
            RoundedRectangle(cornerRadius: WLCorner.l, style: .continuous)
                .fill(isStrategist ? strategistFill : userFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WLCorner.l, style: .continuous)
                .stroke(isStrategist ? WLPalette.stroke : Color.white.opacity(0.18))
        )
        .shadow(
            color: isStrategist ? WLElevation.shadow.opacity(0.12) : WLElevation.heroShadow.opacity(0.16),
            radius: 14,
            x: 0,
            y: 8
        )
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

    private var topMetaRow: some View {
        HStack(spacing: WLSpacing.xs) {
            Text(isStrategist ? "Strategist" : "You")
                .font(WLTypography.captionStrong)
                .foregroundStyle(isStrategist ? WLPalette.rose : Color.white.opacity(0.88))

            if let coachPayload = message.coachPayload, isStrategist {
                StrategistEvidencePill(evidenceTier: coachPayload.evidenceTier)

                if coachPayload.hasVoiceMetadata {
                    WLPill(title: "Voice-ready", tone: .soft)
                }
            }
        }
    }
}

private struct StrategistEvidencePill: View {
    let evidenceTier: CoachEvidenceTier

    private var title: String {
        switch evidenceTier {
        case .high:
            return "High signal"
        case .emerging:
            return "Emerging signal"
        case .personalPattern:
            return "Pattern-based"
        }
    }

    var body: some View {
        WLPill(title: title, tone: .soft)
    }
}

private struct StrategistSuggestedActionRow: View {
    let action: CoachSuggestedAction
    let isSupported: Bool
    let performSuggestedAction: (CoachSuggestedAction) -> Void

    var body: some View {
        Group {
            if isSupported {
                Button(action: { performSuggestedAction(action) }) {
                    rowContent(accentColor: WLPalette.rose, trailingSymbol: "arrow.right")
                }
                .buttonStyle(.plain)
            } else {
                rowContent(accentColor: WLPalette.inkSoft, trailingSymbol: nil)
            }
        }
    }

    private func rowContent(
        accentColor: Color,
        trailingSymbol: String?
    ) -> some View {
        HStack(spacing: WLSpacing.s) {
            WLIcon(systemName: iconName, color: accentColor, size: 12)

            Text(action.label)
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let trailingSymbol {
                WLIcon(systemName: trailingSymbol, color: accentColor, size: 11)
            }
        }
        .padding(.horizontal, WLSpacing.s)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(isSupported ? 0.18 : 0.08))
        )
    }

    private var iconName: String {
        switch action.type {
        case .scan:
            return "viewfinder"
        case .checkIn:
            return "heart.text.square"
        case .viewVerdict:
            return "doc.text.magnifyingglass"
        case .consultProfessional:
            return "cross.case"
        case .none:
            return "ellipsis.circle"
        }
    }
}

private struct StrategistThinkingRow: View {
    let maxBubbleWidth: CGFloat

    var body: some View {
        HStack(alignment: .bottom, spacing: WLSpacing.s) {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                HStack(spacing: WLSpacing.xs) {
                    Text("Strategist")
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(WLPalette.rose)

                    WLPill(title: "Thinking", tone: .soft)
                }

                HStack(spacing: WLSpacing.s) {
                    StrategistTypingDots()
                    Text("Working through the next move with the current signal.")
                        .font(WLTypography.body)
                        .foregroundStyle(WLPalette.inkSoft)
                }
            }
            .padding(WLSpacing.m)
            .frame(maxWidth: maxBubbleWidth, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: WLCorner.l, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.98), WLPalette.surfaceMuted],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: WLCorner.l, style: .continuous)
                    .stroke(WLPalette.stroke)
            )

            Spacer(minLength: 44)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StrategistTypingDots: View {
    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(WLPalette.rose)
                        .frame(width: 8, height: 8)
                        .opacity(opacity(for: index, phase: phase))
                        .scaleEffect(scale(for: index, phase: phase))
                }
            }
        }
    }

    private func opacity(for index: Int, phase: TimeInterval) -> Double {
        let shifted = phase * 3.0 - Double(index) * 0.3
        return 0.35 + ((sin(shifted) + 1) * 0.325)
    }

    private func scale(for index: Int, phase: TimeInterval) -> CGFloat {
        let shifted = phase * 3.0 - Double(index) * 0.3
        return 0.86 + CGFloat((sin(shifted) + 1) * 0.10)
    }
}

private struct StrategistComposerDock: View {
    @Binding var draft: String
    var isFocused: FocusState<Bool>.Binding

    let voiceStatus: StrategistVoiceDockStatus
    let placeholder: String
    let seedTitle: String
    let seedPrompt: String
    let sendMessage: () -> Void
    let seedPromptAction: () -> Void

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.s) {
            StrategistVoiceDock(status: voiceStatus)

            VStack(alignment: .leading, spacing: WLSpacing.s) {
                HStack(alignment: .bottom, spacing: WLSpacing.s) {
                    TextField(placeholder, text: $draft, axis: .vertical)
                        .focused(isFocused)
                        .font(WLTypography.body)
                        .foregroundStyle(WLPalette.ink)
                        .lineLimit(1...4)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.send)
                        .onSubmit(sendMessage)
                        .padding(.horizontal, WLSpacing.m)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                .stroke(isFocused.wrappedValue ? WLPalette.rose.opacity(0.22) : WLPalette.strokeStrong)
                        )

                    Button(action: sendMessage) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: trimmedDraft.isEmpty
                                        ? [WLPalette.lavender.opacity(0.6), WLPalette.surfaceMuted]
                                        : [WLPalette.rose, Color(red: 0.862, green: 0.436, blue: 0.700)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(trimmedDraft.isEmpty ? 0.2 : 0.16))
                            )
                            .overlay(
                                WLIcon(
                                    systemName: "arrow.up",
                                    color: trimmedDraft.isEmpty ? WLPalette.inkSoft : .white,
                                    size: 17
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedDraft.isEmpty)
                    .accessibilityLabel("Send message")
                }

                VStack(alignment: .leading, spacing: WLSpacing.xs) {
                    WLUtilityButton(title: seedTitle, systemImage: "sparkles") {
                        seedPromptAction()
                    }

                    Text(seedPrompt)
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(WLSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: WLCorner.xl, style: .continuous)
                    .fill(Color.white.opacity(0.84))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WLCorner.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.68))
            )
            .shadow(color: WLElevation.heroShadow.opacity(0.16), radius: 22, x: 0, y: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StrategistVoiceDock: View {
    let status: StrategistVoiceDockStatus

    var body: some View {
        HStack(spacing: WLSpacing.m) {
            HStack(spacing: WLSpacing.s) {
                voiceCircle(systemName: "mic.fill")
                voiceCircle(systemName: "play.fill")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(status.caption)
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(status.accentColor)

                Text(status.title)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text(status.subtitle)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(WLSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: WLCorner.l, style: .continuous)
                .fill(Color.white.opacity(0.80))
        )
        .overlay(
            RoundedRectangle(cornerRadius: WLCorner.l, style: .continuous)
                .stroke(status.accentColor.opacity(0.14))
        )
    }

    private func voiceCircle(systemName: String) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.98), status.accentColor.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 42, height: 42)
            .overlay(
                Circle()
                    .stroke(status.accentColor.opacity(0.16))
            )
            .overlay(
                WLIcon(systemName: systemName, color: status.accentColor, size: 14)
            )
    }
}
