import SwiftUI

struct StrategistChatView: View {
    let entryPoint: StrategistEntryPoint
    var linkedAnalysis: ScanAnalysis? = nil

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""

    private var thread: ConversationThread {
        model.conversationThread(for: entryPoint)
    }

    private var relevantMemory: [MemoryItem] {
        Array(model.memoryItems.prefix(3))
    }

    var body: some View {
        NavigationStack {
            WLScreen {
                hero

                if !relevantMemory.isEmpty {
                    memoryStrip
                }

                VStack(alignment: .leading, spacing: WLSpacing.m) {
                    WLSectionHeader(
                        title: "Conversation",
                        subtitle: "Grounded in your active goals, recent signals, and saved decisions.",
                        systemImage: "message"
                    )

                    ForEach(thread.messages) { message in
                        StrategistMessageBubble(message: message)
                    }
                }

                if !model.strategistStarterPrompts(for: entryPoint).isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLSectionHeader(
                            title: "Suggested prompts",
                            subtitle: "Use these when you want a sharper recommendation instead of a blank chat box.",
                            systemImage: "sparkles"
                        )

                        ForEach(model.strategistStarterPrompts(for: entryPoint), id: \.self) { prompt in
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
            VStack(alignment: .leading, spacing: WLSpacing.l) {
                HStack(spacing: WLSpacing.s) {
                    WLStatusBadge(
                        title: "Trusted strategist",
                        systemImage: "sparkles",
                        tone: .accent,
                        style: .heroGlass
                    )

                    WLPill(title: model.dailyHomePayload.state.title, tone: .neutral, style: .heroGlass)
                }

                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    Text("Ask for a recommendation that uses your real context.")
                        .font(WLTypography.hero)
                        .foregroundStyle(.white)

                    Text(heroSubtitle)
                        .font(WLTypography.body)
                        .foregroundStyle(Color.white.opacity(0.88))
                }
            }
        }
    }

    private var heroSubtitle: String {
        if let linkedAnalysis {
            return "This thread can reference \(linkedAnalysis.resolvedProduct.name), your current goals, and what the app already remembers."
        }
        return "The strategist should interpret what matters now, not restate your last scan."
    }

    private var memoryStrip: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "What I’m remembering",
                subtitle: "Signals and decisions already shaping the recommendation.",
                systemImage: "brain.head.profile"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WLSpacing.s) {
                    ForEach(relevantMemory) { item in
                        WLCompactCard {
                            VStack(alignment: .leading, spacing: WLSpacing.xs) {
                                Text(item.title)
                                    .font(WLTypography.captionStrong)
                                    .foregroundStyle(WLPalette.ink)

                                Text(item.summary)
                                    .font(WLTypography.caption)
                                    .foregroundStyle(WLPalette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(width: 220, alignment: .leading)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var composer: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Ask something specific",
                    subtitle: "The tighter the question, the more useful the recommendation.",
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
                        Text("Should this stay in my routine, what matters most today, or what should I avoid next?")
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }

                HStack(spacing: WLSpacing.s) {
                    WLSecondaryButton(title: "Use strategist note") {
                        draft = model.dailyHomePayload.strategistNote.summary
                    }

                    WLPrimaryButton(title: "Send", systemImage: "arrow.up.circle.fill") {
                        sendMessage()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func sendMessage() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.sendStrategistMessage(trimmed, entryPoint: entryPoint, linkedAnalysis: linkedAnalysis)
        draft = ""
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
