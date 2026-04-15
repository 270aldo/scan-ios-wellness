import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedRecordIDs = Set<UUID>()

    private var favoriteCount: Int {
        model.history.filter(\.isFavorite).count
    }

    var body: some View {
        @Bindable var model = model

        WLScreen {
            HistorySummaryCard(
                timelineCount: model.historyTimelineEntries.count,
                readCount: model.history.count,
                favoriteCount: favoriteCount,
                routineCount: model.routines.count,
                selectedCount: selectedRecordIDs.count,
                compareSelected: compareSelected
            )

            if model.historyTimelineEntries.isEmpty {
                WLPrimaryCard {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLStatusBadge(title: "No memory yet", systemImage: "sparkles", tone: .accent)

                        Text("History becomes valuable once scans, body signals, and decisions start connecting.")
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }
            } else {
                HistoryTimelineSection(entries: model.historyTimelineEntries)
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

    private func compareSelected() {
        let selectedRecords = model.history.filter { selectedRecordIDs.contains($0.id) }
        model.compare(selectedRecords)
    }
}

private struct HistorySummaryCard: View {
    let timelineCount: Int
    let readCount: Int
    let favoriteCount: Int
    let routineCount: Int
    let selectedCount: Int
    let compareSelected: () -> Void

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Memory timeline",
                    subtitle: "Scans, body signals, strategist notes, and saved routine decisions all live here now.",
                    systemImage: "clock.arrow.circlepath"
                )

                HStack(spacing: WLSpacing.s) {
                    HistoryMetricCard(title: "Events", value: "\(timelineCount)", systemImage: "clock")
                    HistoryMetricCard(title: "Reads", value: "\(readCount)", systemImage: "viewfinder")
                    HistoryMetricCard(title: "Favorites", value: "\(favoriteCount)", systemImage: "star")
                    HistoryMetricCard(title: "Routine", value: "\(routineCount)", systemImage: "tray.full")
                }

                if selectedCount == 2 {
                    WLPrimaryButton(title: "Compare selected reads", systemImage: "square.split.2x1") {
                        compareSelected()
                    }
                } else {
                    Text("Select two reads below whenever you want a direct side-by-side comparison.")
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)
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

private struct HistoryTimelineSection: View {
    let entries: [HistoryTimelineEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: "Timeline",
                subtitle: "This is the product’s working memory, not just a log of scans.",
                systemImage: "line.3.horizontal"
            )

            ForEach(entries) { entry in
                WLCompactCard {
                    HStack(alignment: .top, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: badgeTitle(for: entry.kind),
                            systemImage: badgeSymbol(for: entry.kind),
                            tone: badgeTone(for: entry.kind)
                        )

                        VStack(alignment: .leading, spacing: WLSpacing.xs) {
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
            }
        }
    }

    private func badgeTitle(for kind: HistoryTimelineKind) -> String {
        switch kind {
        case .scan:
            "Scan"
        case .decision:
            "Decision"
        case .checkIn:
            "Check-in"
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
        case .scan, .memory:
            .accent
        case .decision:
            .success
        case .checkIn:
            .caution
        case .conversation:
            .accent
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
                title: "Saved reads",
                subtitle: "Reads still matter, but now they sit inside a bigger memory system.",
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

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                HStack(alignment: .top, spacing: WLSpacing.s) {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        if let strongestLens {
                            WLStatusBadge(
                                title: strongestLens.lens.title,
                                systemImage: strongestLens.lens.icon,
                                tone: .accent
                            )
                        }

                        Button(action: openRead) {
                            VStack(alignment: .leading, spacing: WLSpacing.xs) {
                                Text(record.analysis.resolvedProduct.name)
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

                        Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(WLTypography.caption)
                            .foregroundStyle(WLPalette.inkSoft)
                    }

                    Spacer(minLength: 0)

                    Button(action: toggleFavorite) {
                        WLIcon(
                            systemName: record.isFavorite ? "star.fill" : "star",
                            color: record.isFavorite ? Color.yellow.opacity(0.90) : WLPalette.inkSoft,
                            size: 18
                        )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: WLSpacing.s) {
                    WLSecondaryButton(title: "Open read", systemImage: "chart.bar") {
                        openRead()
                    }

                    if isSelectedForComparison {
                        Button(action: toggleComparison) {
                            Text("Selected for compare")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(WLPrimaryButtonStyle())
                    } else {
                        Button(action: toggleComparison) {
                            Text("Select to compare")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(WLSecondaryButtonStyle())
                    }
                }
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
