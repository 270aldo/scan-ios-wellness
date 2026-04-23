import SwiftUI

enum HistoryPrimaryActionKind: Equatable {
    case compareSelected
    case openLatestRead
    case startScan
}

struct HistoryPresentationPlan: Equatable {
    let badgeTitle: String
    let headline: String
    let summary: String
    let helperText: String
    let primaryAction: HistoryPrimaryActionKind
    let primaryActionTitle: String

    static func build(
        readCount: Int,
        decisionCount: Int,
        signalCount: Int,
        anchorCount: Int,
        selectedCount: Int,
        latestReadSummary: String?,
        latestDecisionNote: String?,
        latestPatternTitle: String?,
        latestWeeklyHeadline: String?
    ) -> HistoryPresentationPlan {
        if selectedCount == 2 {
            return HistoryPresentationPlan(
                badgeTitle: "Compare ready",
                headline: "Compare the two reads you selected",
                summary: "A side-by-side view is the fastest way to turn uncertainty into a cleaner repeat or avoid decision.",
                helperText: "Open compare now while both reads are still fresh.",
                primaryAction: .compareSelected,
                primaryActionTitle: "Compare selected reads"
            )
        }

        if let latestWeeklyHeadline {
            return HistoryPresentationPlan(
                badgeTitle: "Weekly layer",
                headline: latestWeeklyHeadline,
                summary: latestDecisionNote ?? "History is starting to synthesize your scans and body signals into a stronger weekly point of view.",
                helperText: "Use the memory cards below as evidence, not just archive.",
                primaryAction: readCount > 0 ? .openLatestRead : .startScan,
                primaryActionTitle: readCount > 0 ? "Open latest read" : "Scan something real"
            )
        }

        if let latestPatternTitle {
            return HistoryPresentationPlan(
                badgeTitle: "Pattern signal",
                headline: latestPatternTitle,
                summary: latestDecisionNote ?? "The product is starting to notice repeat behavior instead of treating every scan like an isolated event.",
                helperText: "Keep feeding it explicit keep, avoid, and swap calls.",
                primaryAction: readCount > 0 ? .openLatestRead : .startScan,
                primaryActionTitle: readCount > 0 ? "Open latest read" : "Scan something real"
            )
        }

        if decisionCount > 0 {
            return HistoryPresentationPlan(
                badgeTitle: "Decision memory",
                headline: "Your history is turning into repeatable decisions",
                summary: latestDecisionNote ?? "The strongest signal here is what you deliberately kept, avoided, or swapped.",
                helperText: readCount >= 2 ? "Select two archived reads below whenever you want a direct compare." : "Keep turning scans into explicit decisions so the memory gets sharper.",
                primaryAction: readCount > 0 ? .openLatestRead : .startScan,
                primaryActionTitle: readCount > 0 ? "Open latest read" : "Scan something real"
            )
        }

        if readCount > 0 || signalCount > 0 || anchorCount > 0 {
            return HistoryPresentationPlan(
                badgeTitle: "Signal building",
                headline: "You already have useful signal here",
                summary: latestReadSummary ?? "The next job is turning more reads into clear keep, avoid, or swap decisions.",
                helperText: readCount >= 2 ? "Select two archived reads below whenever you want a direct compare." : "One more deliberate decision will make this screen feel much sharper.",
                primaryAction: readCount > 0 ? .openLatestRead : .startScan,
                primaryActionTitle: readCount > 0 ? "Open latest read" : "Scan something real"
            )
        }

        return HistoryPresentationPlan(
            badgeTitle: "Start memory",
            headline: "No real memory yet",
            summary: "History becomes useful once scans, body signals, and decisions start agreeing with each other.",
            helperText: "Start with one real scan, then log how it actually felt.",
            primaryAction: .startScan,
            primaryActionTitle: "Scan something real"
        )
    }
}

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedRecordIDs = Set<UUID>()

    private var readCount: Int {
        max(model.scanEvents.count, model.history.count)
    }

    private var decisionCount: Int {
        model.scanDecisions.count
    }

    private var signalCount: Int {
        model.checkInEvents.count
    }

    private var anchorCount: Int {
        model.favoriteItems.count + model.routines.count
    }

    private var latestRecord: ScanRecord? {
        model.history.first
    }

    private var latestDecision: ScanDecision? {
        model.scanDecisions.first
    }

    private var latestCheckIn: CheckInEvent? {
        model.checkInEvents.first
    }

    private var latestPattern: PatternInsight? {
        model.patternInsights.first
    }

    private var recentTimelineEntries: [HistoryTimelineEntry] {
        Array(model.historyTimelineEntries.prefix(8))
    }

    private var presentation: HistoryPresentationPlan {
        HistoryPresentationPlan.build(
            readCount: readCount,
            decisionCount: decisionCount,
            signalCount: signalCount,
            anchorCount: anchorCount,
            selectedCount: selectedRecordIDs.count,
            latestReadSummary: latestRecord?.analysis.overallSummary,
            latestDecisionNote: latestDecision?.note,
            latestPatternTitle: latestPattern?.title,
            latestWeeklyHeadline: model.weeklyNarrative?.headline
        )
    }

    var body: some View {
        @Bindable var model = model

        WLScreen {
            HistoryOverviewCard(
                presentation: presentation,
                readCount: readCount,
                decisionCount: decisionCount,
                signalCount: signalCount,
                anchorCount: anchorCount,
                selectedCount: selectedRecordIDs.count,
                primaryAction: handlePrimaryAction
            )

            if model.isUsingLocalInsightsFallback {
                HistoryFallbackStateCard()
            }

            if model.featureFlags.weeklyInsightV2, let weeklyNarrative = model.weeklyNarrative {
                HistoryWeeklyNarrativeCard(
                    narrative: weeklyNarrative,
                    isUnlocked: model.hasAccess(to: .weeklyInsightV2),
                    unlock: {
                        _ = model.requireAccess(
                            to: .weeklyInsightV2,
                            surface: .weeklyNarrative,
                            previewLines: [
                                weeklyNarrative.headline,
                                weeklyNarrative.patternSummary
                            ]
                        )
                    }
                )
            } else if !model.weeklyInsights.isEmpty {
                HistoryWeeklyFallbackCard(insight: model.weeklyInsights[0])
            }

            if model.featureFlags.patternAgent, let latestPattern {
                HistoryPatternCard(
                    insight: latestPattern,
                    isUnlocked: model.hasAccess(to: .patternAgent),
                    unlock: {
                        _ = model.requireAccess(
                            to: .patternAgent,
                            surface: .patternDetail,
                            previewLines: [latestPattern.title, latestPattern.summary]
                        )
                    }
                )
            }

            if latestDecision != nil || latestCheckIn != nil || latestRecord != nil {
                HistoryLatestSignalsSection(
                    latestDecision: latestDecision,
                    latestCheckIn: latestCheckIn,
                    latestRecord: latestRecord,
                    openLatestRead: openLatestRead
                )
            }

            if !model.favoriteItems.isEmpty {
                RepeatAnchorsSection(favorites: model.favoriteItems)
            }

            if recentTimelineEntries.isEmpty {
                WLSurfaceCard {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLStatusBadge(title: "No real memory yet", systemImage: "sparkles", tone: .accent)

                        Text("Bootstrap notes and starter coaching stay out of History. This screen should only fill up when the product learns from real scans, body signals, and decisions.")
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }
            } else {
                HistoryTimelineSection(entries: recentTimelineEntries, totalCount: model.historyTimelineEntries.count)
            }

            if !model.history.isEmpty {
                HistoryScansSection(
                    records: model.history,
                    selectedRecordIDs: $selectedRecordIDs,
                    openRead: { model.latestAnalysis = $0.analysis },
                    toggleFavorite: { model.toggleFavorite(for: $0.id) }
                )
            }
        }
        .navigationTitle("History")
        .sheet(item: $model.activeComparison, onDismiss: {
            model.dismissComparison()
        }) { comparison in
            ComparisonView(comparison: comparison)
        }
    }

    private func handlePrimaryAction() {
        switch presentation.primaryAction {
        case .compareSelected:
            compareSelected()
        case .openLatestRead:
            openLatestRead()
        case .startScan:
            model.selectedTab = .scan
        }
    }

    private func openLatestRead() {
        guard let latestRecord else { return }
        model.latestAnalysis = latestRecord.analysis
    }

    private func compareSelected() {
        let selectedRecords = model.history.filter { selectedRecordIDs.contains($0.id) }
        model.compare(selectedRecords)
    }
}

private struct HistoryOverviewCard: View {
    let presentation: HistoryPresentationPlan
    let readCount: Int
    let decisionCount: Int
    let signalCount: Int
    let anchorCount: Int
    let selectedCount: Int
    let primaryAction: () -> Void

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Working memory",
                    subtitle: "Reuse good calls, avoid noisy repeats, and see what the product is learning.",
                    systemImage: "clock.arrow.circlepath"
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: presentation.badgeTitle,
                            systemImage: "brain.head.profile",
                            tone: .accent
                        )

                        if selectedCount == 2 {
                            WLPill(title: "2 selected", tone: .soft)
                        }
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: presentation.badgeTitle,
                            systemImage: "brain.head.profile",
                            tone: .accent
                        )

                        if selectedCount == 2 {
                            WLPill(title: "2 selected", tone: .soft)
                        }
                    }
                }

                Text(presentation.headline)
                    .font(WLTypography.title)
                    .foregroundStyle(WLPalette.ink)

                Text(presentation.summary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120), spacing: WLSpacing.s)],
                    alignment: .leading,
                    spacing: WLSpacing.s
                ) {
                    HistoryMetricCard(title: "Decisions", value: "\(decisionCount)", systemImage: "checkmark.circle")
                    HistoryMetricCard(title: "Signals", value: "\(signalCount)", systemImage: "heart.text.square")
                    HistoryMetricCard(title: "Anchors", value: "\(anchorCount)", systemImage: "star")
                    HistoryMetricCard(title: "Reads", value: "\(readCount)", systemImage: "square.stack")
                }

                WLPrimaryButton(title: presentation.primaryActionTitle, systemImage: primaryActionSymbol) {
                    primaryAction()
                }

                Text(presentation.helperText)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
            }
        }
    }

    private var primaryActionSymbol: String {
        switch presentation.primaryAction {
        case .compareSelected:
            return "square.split.2x1"
        case .openLatestRead:
            return "chart.bar"
        case .startScan:
            return "viewfinder"
        }
    }
}

private struct RepeatAnchorsSection: View {
    let favorites: [FavoriteItem]

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Repeat anchors",
                subtitle: "Favorites are the fastest path back to choices worth repeating.",
                systemImage: "star.fill"
            )

            ForEach(Array(favorites.prefix(3))) { favorite in
                WLCompactCard {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text(favorite.title)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text(favorite.summary)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)

                        Text(favorite.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(WLTypography.caption)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }
            }
        }
    }
}

private struct HistoryMetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.xs) {
            WLIcon(systemName: systemImage, color: WLPalette.rose, size: 14)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(WLPalette.ink)

            Text(title)
                .font(WLTypography.caption)
                .foregroundStyle(WLPalette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WLSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.98), WLPalette.canvasWarm],
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
}

private struct HistoryLatestSignalsSection: View {
    let latestDecision: ScanDecision?
    let latestCheckIn: CheckInEvent?
    let latestRecord: ScanRecord?
    let openLatestRead: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "What changed recently",
                subtitle: "Read the latest decision, body signal, and read together.",
                systemImage: "sparkles"
            )

            if let latestDecision {
                HistorySignalCard(
                    badgeTitle: latestDecision.kind.title,
                    badgeSymbol: "checkmark.circle",
                    badgeTone: .success,
                    title: latestDecision.productName,
                    summary: latestDecision.note,
                    timestamp: latestDecision.createdAt,
                    actionTitle: nil,
                    action: nil
                )
            }

            if let latestCheckIn {
                HistorySignalCard(
                    badgeTitle: "Body signal",
                    badgeSymbol: "heart.text.square",
                    badgeTone: .caution,
                    title: checkInHeadline(for: latestCheckIn),
                    summary: checkInSummary(for: latestCheckIn),
                    timestamp: latestCheckIn.timestamp,
                    actionTitle: nil,
                    action: nil
                )
            }

            if let latestRecord {
                HistorySignalCard(
                    badgeTitle: latestRecord.analysis.source.title,
                    badgeSymbol: "viewfinder",
                    badgeTone: .accent,
                    title: historyReadTitle(for: latestRecord.analysis),
                    summary: latestRecord.analysis.overallSummary,
                    timestamp: latestRecord.createdAt,
                    actionTitle: "Open latest read",
                    action: openLatestRead
                )
            }
        }
    }

    private func checkInHeadline(for checkIn: CheckInEvent) -> String {
        if checkIn.readHelpful == true {
            return "Recent read felt helpful"
        }
        if checkIn.readHelpful == false {
            return "Recent read still feels off"
        }
        return "Body signal logged"
    }

    private func checkInSummary(for checkIn: CheckInEvent) -> String {
        "Energy \(checkIn.energy)/5 • Mood \(checkIn.mood)/5 • Digestion \(checkIn.bloating)/5 • Satiety \(checkIn.satiety)/5"
    }

    private func historyReadTitle(for analysis: ScanAnalysis) -> String {
        switch analysis.source {
        case .mealPhoto:
            return "Meal Snapshot"
        case .menuPhoto:
            return "Menu Scanner"
        default:
            return analysis.resolvedProduct.name
        }
    }
}

private struct HistorySignalCard: View {
    let badgeTitle: String
    let badgeSymbol: String
    let badgeTone: WLStatusBadge.Tone
    let title: String
    let summary: String
    let timestamp: Date
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: badgeTitle,
                            systemImage: badgeSymbol,
                            tone: badgeTone
                        )

                        Spacer(minLength: WLSpacing.s)

                        Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(WLTypography.caption)
                            .foregroundStyle(WLPalette.inkSoft)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        WLStatusBadge(
                            title: badgeTitle,
                            systemImage: badgeSymbol,
                            tone: badgeTone
                        )

                        Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(WLTypography.caption)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }

                Text(title)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text(summary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                if let actionTitle, let action {
                    WLUtilityButton(title: actionTitle, systemImage: "arrow.right") {
                        action()
                    }
                }
            }
        }
    }
}

private struct HistoryWeeklyFallbackCard: View {
    let insight: WeeklyInsight

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                WLSectionHeader(
                    title: insight.title,
                    subtitle: "Lightweight weekly guidance is available now; the deeper structured narrative arrives with more data.",
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

private struct HistoryWeeklyNarrativeCard: View {
    let narrative: WeeklyInsightNarrative
    let isUnlocked: Bool
    let unlock: () -> Void

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                WLSectionHeader(
                    title: "Weekly narrative",
                    subtitle: "Where History stops being archive and starts being a protect/reduce point of view.",
                    systemImage: "sparkles"
                )

                Text(narrative.headline)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text(narrative.patternSummary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                if isUnlocked {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Protect")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.ink)
                        Text(narrative.whatToProtect)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)

                        Text("Reduce")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.ink)
                            .padding(.top, WLSpacing.xs)
                        Text(narrative.whatToReduce)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)

                        Text("Next experiment")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.rose)
                            .padding(.top, WLSpacing.xs)
                        Text(narrative.nextExperiment)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }

                    WLPill(
                        title: "Confidence \(Int((narrative.confidence * 100).rounded()))",
                        tone: .soft
                    )
                } else {
                    Text("The weekly narrative is ready, and the protect/reduce layer unlocks with Plus.")
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)

                    WLUtilityButton(title: "Unlock weekly narrative", systemImage: "sparkles") {
                        unlock()
                    }
                }
            }
        }
    }
}

private struct HistoryPatternCard: View {
    let insight: PatternInsight
    let isUnlocked: Bool
    let unlock: () -> Void

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                WLSectionHeader(
                    title: "Pattern signal",
                    subtitle: "Patterns should show up here as memory, not hide behind the raw log.",
                    systemImage: "waveform.path.ecg.rectangle"
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: insight.signal.title,
                            systemImage: "sparkles",
                            tone: .accent
                        )
                        WLPill(title: "Confidence \(Int((insight.confidence * 100).rounded()))", tone: .soft)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: insight.signal.title,
                            systemImage: "sparkles",
                            tone: .accent
                        )
                        WLPill(title: "Confidence \(Int((insight.confidence * 100).rounded()))", tone: .soft)
                    }
                }

                Text(insight.title)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text(insight.summary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                if isUnlocked {
                    Text(insight.recommendedAction)
                        .font(WLTypography.body)
                        .foregroundStyle(WLPalette.ink)

                    Text(insight.safetyNote)
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)
                } else {
                    Text("The deeper pattern read and recommendation unlock with Plus.")
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)

                    WLUtilityButton(title: "Unlock pattern memory", systemImage: "sparkles") {
                        unlock()
                    }
                }
            }
        }
    }
}

private struct HistoryTimelineSection: View {
    let entries: [HistoryTimelineEntry]
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Recent memory",
                subtitle: "Chronological evidence of what the product learned from your behavior.",
                systemImage: "line.3.horizontal"
            )

            ForEach(entries) { entry in
                WLCompactCard {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: badgeTitle(for: entry.kind),
                            systemImage: badgeSymbol(for: entry.kind),
                            tone: badgeTone(for: entry.kind)
                        )

                        Text(entry.title)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text(entry.summary)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)

                        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(WLTypography.caption)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }
            }

            if totalCount > entries.count {
                Text("Showing the \(entries.count) most recent memory events.")
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
            }
        }
    }

    private func badgeTitle(for kind: HistoryTimelineKind) -> String {
        switch kind {
        case .scan:
            "Read"
        case .decision:
            "Decision"
        case .checkIn:
            "Body signal"
        case .memory:
            "Memory"
        case .conversation:
            "Strategist"
        }
    }

    private func badgeSymbol(for kind: HistoryTimelineKind) -> String {
        switch kind {
        case .scan:
            "viewfinder"
        case .decision:
            "checkmark.circle"
        case .checkIn:
            "heart.text.square"
        case .memory:
            "brain.head.profile"
        case .conversation:
            "message"
        }
    }

    private func badgeTone(for kind: HistoryTimelineKind) -> WLStatusBadge.Tone {
        switch kind {
        case .scan, .memory, .conversation:
            return .accent
        case .decision:
            return .success
        case .checkIn:
            return .caution
        }
    }
}

private struct HistoryScansSection: View {
    let records: [ScanRecord]
    @Binding var selectedRecordIDs: Set<UUID>
    let openRead: (ScanRecord) -> Void
    let toggleFavorite: (ScanRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Archive & compare",
                subtitle: "The raw archive still matters, but it should support recall and comparison.",
                systemImage: "square.stack"
            )

            ForEach(records) { record in
                HistoryRecordCard(
                    record: record,
                    isSelectedForComparison: selectedRecordIDs.contains(record.id),
                    openRead: { openRead(record) },
                    toggleFavorite: { toggleFavorite(record) },
                    toggleComparison: { toggleComparisonSelection(for: record.id) }
                )
            }
        }
    }

    private func toggleComparisonSelection(for id: UUID) {
        if selectedRecordIDs.contains(id) {
            selectedRecordIDs.remove(id)
            return
        }

        if selectedRecordIDs.count == 2, let first = selectedRecordIDs.first {
            selectedRecordIDs.remove(first)
        }

        selectedRecordIDs.insert(id)
    }
}

private struct HistoryRecordCard: View {
    let record: ScanRecord
    let isSelectedForComparison: Bool
    let openRead: () -> Void
    let toggleFavorite: () -> Void
    let toggleComparison: () -> Void

    private var strongestLens: LensScore? {
        record.analysis.lensScores.max(by: { $0.score < $1.score })
    }

    private var title: String {
        switch record.analysis.source {
        case .mealPhoto:
            return "Meal Snapshot"
        case .menuPhoto:
            return "Menu Scanner"
        default:
            return record.analysis.resolvedProduct.name
        }
    }

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WLSpacing.s) {
                        if let strongestLens {
                            WLStatusBadge(
                                title: strongestLens.lens.title,
                                systemImage: strongestLens.lens.icon,
                                tone: .accent
                            )
                        }

                        WLPill(title: record.analysis.source.title, tone: .soft)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        if let strongestLens {
                            WLStatusBadge(
                                title: strongestLens.lens.title,
                                systemImage: strongestLens.lens.icon,
                                tone: .accent
                            )
                        }

                        WLPill(title: record.analysis.source.title, tone: .soft)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WLSpacing.s) {
                        readContent

                        Spacer(minLength: 0)

                        favoriteButton
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        favoriteButton
                        readContent
                    }
                }

                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)

                WLActionGroup {
                    WLUtilityButton(title: "Open read", systemImage: "chart.bar") {
                        openRead()
                    }

                    comparisonButton
                }
            }
        }
    }

    private var readContent: some View {
        Button(action: openRead) {
            VStack(alignment: .leading, spacing: WLSpacing.xs) {
                Text(title)
                    .font(WLTypography.title)
                    .foregroundStyle(WLPalette.ink)
                    .multilineTextAlignment(.leading)

                Text(record.analysis.overallSummary)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var favoriteButton: some View {
        Button(action: toggleFavorite) {
            WLIcon(
                systemName: record.isFavorite ? "star.fill" : "star",
                color: record.isFavorite ? Color.yellow.opacity(0.90) : WLPalette.inkSoft,
                size: 18
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var comparisonButton: some View {
        WLSecondaryButton(
            title: isSelectedForComparison ? "Selected for compare" : "Select for compare",
            systemImage: isSelectedForComparison ? "checkmark.circle.fill" : "plus.circle"
        ) {
            toggleComparison()
        }
    }
}

private struct HistoryFallbackStateCard: View {
    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                WLStatusBadge(title: "Offline mode", systemImage: "icloud.slash", tone: .caution)

                Text("Showing on-device history insights")
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text("Weekly and pattern layers are using on-device insights right now.")
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
            }
        }
    }
}

struct ComparisonView: View {
    let comparison: ProductComparison

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WLScreen {
                WLPrimaryCard {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLSectionHeader(
                            title: "Product reads",
                            subtitle: "A direct side-by-side look at the two reads you selected.",
                            systemImage: "square.split.2x1"
                        )

                        comparisonRow(
                            title: comparison.left.resolvedProduct.name,
                            subtitle: comparison.left.overallSummary
                        )

                        comparisonRow(
                            title: comparison.right.resolvedProduct.name,
                            subtitle: comparison.right.overallSummary
                        )
                    }
                }

                VStack(alignment: .leading, spacing: WLSpacing.m) {
                    WLSectionHeader(
                        title: "Lens delta",
                        subtitle: "Positive values mean the right-hand product scored higher.",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )

                    ForEach(comparison.deltas) { delta in
                        WLCompactCard {
                            VStack(alignment: .leading, spacing: WLSpacing.s) {
                                HStack {
                                    Text(delta.lens.title)
                                        .font(WLTypography.bodyEmphasis)
                                        .foregroundStyle(WLPalette.ink)

                                    Spacer()

                                    WLStatusBadge(
                                        title: delta.delta >= 0 ? "+\(delta.delta)" : "\(delta.delta)",
                                        systemImage: delta.delta >= 0 ? "arrow.up.right" : "arrow.down.right",
                                        tone: delta.delta >= 0 ? .success : .caution
                                    )
                                }

                                Text("\(comparison.left.resolvedProduct.name): \(delta.leftScore)")
                                    .font(WLTypography.body)
                                    .foregroundStyle(WLPalette.inkSoft)

                                Text("\(comparison.right.resolvedProduct.name): \(delta.rightScore)")
                                    .font(WLTypography.body)
                                    .foregroundStyle(WLPalette.inkSoft)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: dismiss.callAsFunction)
                        .font(WLTypography.captionStrong)
                }
            }
        }
    }

    private func comparisonRow(title: String, subtitle: String) -> some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.xs) {
                Text(title)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text(subtitle)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)
            }
        }
    }
}

#Preview("History") {
    NavigationStack {
        HistoryView()
            .environment(AppModel())
    }
}
