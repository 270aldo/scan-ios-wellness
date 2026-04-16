import SwiftUI

struct PantrySurfacePlan {
    let badgeTitle: String
    let headline: String
    let summary: String
    let primaryActionTitle: String
    let primaryActionSystemImage: String
    let secondaryActionTitle: String
    let secondaryActionSystemImage: String

    static func build(
        isUnlocked: Bool,
        itemCount: Int,
        hasSuggestion: Bool,
        hasOpenableAnchor: Bool
    ) -> PantrySurfacePlan {
        if !isUnlocked {
            return PantrySurfacePlan(
                badgeTitle: "Pro preview",
                headline: "Keep your strongest repeat choices visible before convenience wins.",
                summary: "Pantry turns supportive reads into anchors you can actually reuse. Preview stays deterministic; save, prune, and suggestion actions unlock with Pro.",
                primaryActionTitle: "Unlock pantry",
                primaryActionSystemImage: "sparkles",
                secondaryActionTitle: "Open scan",
                secondaryActionSystemImage: "viewfinder"
            )
        }

        if itemCount == 0 {
            return PantrySurfacePlan(
                badgeTitle: "Start pantry",
                headline: "No pantry anchors yet.",
                summary: "Save the first repeat worth protecting or let a few stronger scans seed the list automatically.",
                primaryActionTitle: "Open scan",
                primaryActionSystemImage: "viewfinder",
                secondaryActionTitle: "Ask strategist",
                secondaryActionSystemImage: "message"
            )
        }

        if hasSuggestion {
            return PantrySurfacePlan(
                badgeTitle: "Next pantry move",
                headline: "Use Pantry to protect the calmer default before the softer choice wins.",
                summary: "The pantry should shorten the next decision, not store more noise. Review the anchor that best supports your current pattern.",
                primaryActionTitle: hasOpenableAnchor ? "Review strongest anchor" : "Open scan",
                primaryActionSystemImage: hasOpenableAnchor ? "arrow.up.right.circle" : "viewfinder",
                secondaryActionTitle: "Scan another choice",
                secondaryActionSystemImage: "plus.viewfinder"
            )
        }

        return PantrySurfacePlan(
            badgeTitle: "Anchors ready",
            headline: "Your better defaults are starting to look reusable.",
            summary: "Pantry matters when it keeps the next stronger option visible and easy to repeat on noisy days.",
            primaryActionTitle: hasOpenableAnchor ? "Open latest anchor" : "Open scan",
            primaryActionSystemImage: hasOpenableAnchor ? "arrow.up.right.circle" : "viewfinder",
            secondaryActionTitle: "Ask strategist",
            secondaryActionSystemImage: "message"
        )
    }
}

struct PantryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAnalysis: ScanAnalysis?
    @State private var strategistEntryPoint: StrategistEntryPoint?

    private var isUnlocked: Bool {
        model.hasAccess(to: .pantryMVP)
    }

    private var visibleItems: [PantryItem] {
        model.visiblePantryItems
    }

    private var displayedItems: [PantryItem] {
        Array(visibleItems.prefix(isUnlocked ? 8 : 2))
    }

    private var suggestion: PantrySuggestion? {
        guard model.hasAccess(to: .pantrySuggestions) else { return nil }
        return model.pantrySuggestions.first
    }

    private var supportingSuggestionItems: [PantryItem] {
        guard let suggestion else { return [] }
        return model.pantryItems(for: suggestion)
    }

    private var primaryAnchor: PantryItem? {
        supportingSuggestionItems.first ?? displayedItems.first
    }

    private var hasOpenableAnchor: Bool {
        primaryAnchor.flatMap { model.pantryAnalysis(for: $0) } != nil
    }

    private var surfacePlan: PantrySurfacePlan {
        PantrySurfacePlan.build(
            isUnlocked: isUnlocked,
            itemCount: visibleItems.count,
            hasSuggestion: suggestion != nil,
            hasOpenableAnchor: hasOpenableAnchor
        )
    }

    private var anchorCountTitle: String {
        "\(visibleItems.count) anchors"
    }

    private var routineCountTitle: String {
        "\(model.routines.count) defaults"
    }

    var body: some View {
        NavigationStack {
            WLScreen {
                hero
                nextMoveSection
                anchorsSection
            }
            .navigationTitle("Pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: dismiss.callAsFunction)
                        .font(WLTypography.captionStrong)
                }
            }
        }
        .sheet(item: $selectedAnalysis) { analysis in
            AnalysisView(analysis: analysis)
        }
        .sheet(item: $strategistEntryPoint) { entryPoint in
            StrategistChatView(entryPoint: entryPoint)
        }
    }

    private var hero: some View {
        WLHeroSurface {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: surfacePlan.badgeTitle,
                            systemImage: "shippingbox",
                            tone: isUnlocked ? .accent : .caution,
                            style: .heroGlass
                        )

                        WLPill(title: anchorCountTitle, tone: .neutral, style: .heroGlass)
                        WLPill(title: routineCountTitle, tone: .neutral, style: .heroGlass)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        HStack(spacing: WLSpacing.s) {
                            WLStatusBadge(
                                title: surfacePlan.badgeTitle,
                                systemImage: "shippingbox",
                                tone: isUnlocked ? .accent : .caution,
                                style: .heroGlass
                            )

                            WLPill(title: anchorCountTitle, tone: .neutral, style: .heroGlass)
                        }

                        WLPill(title: routineCountTitle, tone: .neutral, style: .heroGlass)
                    }
                }

                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    Text(surfacePlan.headline)
                        .font(WLTypography.hero)
                        .foregroundStyle(.white)

                    Text(surfacePlan.summary)
                        .font(WLTypography.body)
                        .foregroundStyle(Color.white.opacity(0.88))
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WLSpacing.s) {
                        WLPrimaryButton(
                            title: surfacePlan.primaryActionTitle,
                            systemImage: surfacePlan.primaryActionSystemImage,
                            chrome: .heroPrimary
                        ) {
                            handlePrimaryAction()
                        }

                        WLSecondaryButton(
                            title: surfacePlan.secondaryActionTitle,
                            systemImage: surfacePlan.secondaryActionSystemImage,
                            chrome: .heroSecondary
                        ) {
                            handleSecondaryAction()
                        }
                    }

                    VStack(spacing: WLSpacing.s) {
                        WLPrimaryButton(
                            title: surfacePlan.primaryActionTitle,
                            systemImage: surfacePlan.primaryActionSystemImage,
                            chrome: .heroPrimary
                        ) {
                            handlePrimaryAction()
                        }

                        WLSecondaryButton(
                            title: surfacePlan.secondaryActionTitle,
                            systemImage: surfacePlan.secondaryActionSystemImage,
                            chrome: .heroSecondary
                        ) {
                            handleSecondaryAction()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var nextMoveSection: some View {
        if let suggestion {
            PantrySuggestionCard(
                suggestion: suggestion,
                supportingItems: supportingSuggestionItems
            )
        } else {
            WLCompactCard {
                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    WLSectionHeader(
                        title: isUnlocked ? "Next pantry move" : "Preview mode",
                        subtitle: isUnlocked
                            ? (visibleItems.isEmpty
                                ? "The first few stronger repeats will turn Pantry into a real shortcut."
                                : "Suggestions sharpen as repeats, routines, and body signals start agreeing.")
                            : "Preview the saved anchors now. Unlock Pro when you want Pantry to become active.",
                        systemImage: isUnlocked ? "sparkles" : "lock"
                    )

                    if let supportingMessage = PantryPresentationCopy.supportingMessage(
                        isUnlocked: isUnlocked,
                        hasSuggestion: suggestion != nil
                    ) {
                        Text(supportingMessage)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }
            }
        }
    }

    private var anchorsSection: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: isUnlocked ? "Protected anchors" : "Preview anchors",
                subtitle: isUnlocked
                    ? "These are the defaults you want visible before a noisy day decides for you."
                    : "Preview shows what the deterministic engine already thinks is worth keeping close.",
                systemImage: "shippingbox"
            )

            if displayedItems.isEmpty {
                WLCompactCard {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text("Nothing is seeded yet.")
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text("Run a stronger scan, save a repeat from Analysis, or let a few stable reads build the first anchor automatically.")
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }
            } else {
                ForEach(displayedItems) { item in
                    PantryAnchorCard(
                        item: item,
                        isUnlocked: isUnlocked,
                        isInRoutine: model.pantryItemIsInRoutine(item),
                        canOpenRead: model.pantryAnalysis(for: item) != nil,
                        openRead: {
                            if let analysis = model.pantryAnalysis(for: item) {
                                selectedAnalysis = analysis
                            }
                        },
                        makeDefault: {
                            model.promotePantryItemToRoutine(item)
                        },
                        remove: {
                            model.removePantryItem(item)
                        }
                    )
                }
            }
        }
    }

    private func handlePrimaryAction() {
        if !isUnlocked {
            _ = model.requireAccess(
                to: .pantryMVP,
                surface: .pantry,
                previewLines: [
                    "Keep the better default visible before convenience takes over.",
                    "Review saved anchors, promote them to routine, and prune what no longer deserves space."
                ]
            )
            return
        }

        guard let primaryAnchor,
              let analysis = model.pantryAnalysis(for: primaryAnchor) else {
            openScan()
            return
        }

        selectedAnalysis = analysis
    }

    private func handleSecondaryAction() {
        if !isUnlocked {
            openScan()
            return
        }

        if hasOpenableAnchor {
            openScan()
        } else {
            strategistEntryPoint = .profile
        }
    }

    private func openScan() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            model.selectedTab = .scan
        }
        dismiss()
    }
}

private struct PantrySuggestionCard: View {
    let suggestion: PantrySuggestion
    let supportingItems: [PantryItem]

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Next pantry move",
                    subtitle: "Use Pantry to shorten the next good decision instead of rethinking it from zero.",
                    systemImage: "sparkles"
                )

                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    Text(suggestion.title)
                        .font(WLTypography.title)
                        .foregroundStyle(WLPalette.ink)

                    Text(suggestion.summary)
                        .font(WLTypography.body)
                        .foregroundStyle(WLPalette.inkSoft)

                    Text(suggestion.reason)
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)
                }

                if !supportingItems.isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Backed by")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.ink)

                        HStack(spacing: WLSpacing.xs) {
                            ForEach(Array(supportingItems.prefix(2))) { item in
                                WLPill(title: item.title, tone: .soft)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct PantryAnchorCard: View {
    let item: PantryItem
    let isUnlocked: Bool
    let isInRoutine: Bool
    let canOpenRead: Bool
    let openRead: () -> Void
    let makeDefault: () -> Void
    let remove: () -> Void

    private var tone: WLStatusBadge.Tone {
        switch item.sourceKind {
        case .supportiveScan, .menuScan:
            return .success
        case .routine:
            return .accent
        case .favorite, .manualSave:
            return .accent
        }
    }

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                HStack(alignment: .top, spacing: WLSpacing.s) {
                    WLStatusBadge(
                        title: item.sourceKind.title,
                        systemImage: sourceSymbol,
                        tone: tone
                    )

                    if isInRoutine {
                        WLPill(title: "In routine", tone: .accent)
                    } else if !isUnlocked {
                        WLPill(title: "Preview", tone: .soft)
                    }

                    Spacer()

                    if isUnlocked {
                        Button("Remove", action: remove)
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.rose)
                    }
                }

                VStack(alignment: .leading, spacing: WLSpacing.xs) {
                    Text(item.title)
                        .font(WLTypography.bodyEmphasis)
                        .foregroundStyle(WLPalette.ink)

                    Text(item.summary)
                        .font(WLTypography.body)
                        .foregroundStyle(WLPalette.inkSoft)
                }

                if isUnlocked {
                    HStack(spacing: WLSpacing.s) {
                        if canOpenRead {
                            PantryInlineActionButton(
                                title: "Open read",
                                systemImage: "arrow.up.right.circle",
                                action: openRead
                            )
                        }

                        if !isInRoutine {
                            PantryInlineActionButton(
                                title: "Make default",
                                systemImage: "checkmark.circle",
                                action: makeDefault
                            )
                        }
                    }
                }
            }
        }
    }

    private var sourceSymbol: String {
        switch item.sourceKind {
        case .supportiveScan:
            return "checkmark.circle"
        case .favorite:
            return "star"
        case .routine:
            return "repeat"
        case .menuScan:
            return "menucard"
        case .manualSave:
            return "tray.and.arrow.down"
        }
    }
}

private struct PantryInlineActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WLSpacing.xs) {
                WLIcon(systemName: systemImage, color: WLPalette.ink, size: 12)
                Text(title)
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.ink)
            }
            .padding(.horizontal, WLSpacing.m)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.9))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(WLPalette.strokeStrong)
            )
        }
        .buttonStyle(.plain)
    }
}
