import SwiftUI

struct AnalysisView: View {
    let analysis: ScanAnalysis

    @Environment(\.dismiss) private var dismiss

    private var strongestLens: LensScore? {
        analysis.lensScores.max(by: { $0.score < $1.score })
    }

    private var softestLens: LensScore? {
        analysis.lensScores.min(by: { $0.score < $1.score })
    }

    private var sortedLensScores: [LensScore] {
        analysis.lensScores.sorted(by: { $0.score > $1.score })
    }

    var body: some View {
        NavigationStack {
            WLScreen {
                AnalysisHero(analysis: analysis, strongestLens: strongestLens, softestLens: softestLens)
                AnalysisConfidenceCard(explanation: confidenceExplanation, confidence: analysis.confidence)

                VStack(alignment: .leading, spacing: WLSpacing.m) {
                    WLSectionHeader(
                        title: WLProductCopy.ProductRead.lensReadTitle,
                        subtitle: WLProductCopy.ProductRead.lensReadSubtitle,
                        systemImage: "circle.grid.2x2"
                    )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: WLSpacing.s)], spacing: WLSpacing.s) {
                        ForEach(sortedLensScores) { score in
                            WLLensTile(score: score)
                        }
                    }
                }

                if !analysis.topReasons.isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLSectionHeader(
                            title: WLProductCopy.ProductRead.reasonsTitle,
                            subtitle: WLProductCopy.ProductRead.reasonsSubtitle,
                            systemImage: "sparkles"
                        )

                        ForEach(analysis.topReasons) { reason in
                            AnalysisReasonCard(reason: reason)
                        }
                    }
                }

                if !analysis.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLSectionHeader(
                            title: WLProductCopy.ProductRead.watchoutsTitle,
                            subtitle: WLProductCopy.ProductRead.watchoutsSubtitle,
                            systemImage: "exclamationmark.triangle"
                        )

                        ForEach(analysis.warnings, id: \.self) { warning in
                            AnalysisWarningCard(warning: warning)
                        }
                    }
                }

                if !analysis.alternatives.isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLSectionHeader(
                            title: WLProductCopy.ProductRead.swapsTitle,
                            subtitle: WLProductCopy.ProductRead.swapsSubtitle,
                            systemImage: "arrow.triangle.2.circlepath"
                        )

                        ForEach(analysis.alternatives) { suggestion in
                            AnalysisSuggestionCard(suggestion: suggestion)
                        }
                    }
                }

                Text(analysis.disclaimer)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)
                    .padding(.top, WLSpacing.xs)
            }
            .navigationTitle(WLProductCopy.ProductRead.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: dismiss.callAsFunction)
                        .font(WLTypography.captionStrong)
                }
            }
        }
    }

    private var confidenceExplanation: String {
        switch analysis.confidence {
        case .high:
            "This match is strong enough that the summary should feel stable, not noisy."
        case .medium:
            "This read is still useful, but treat it as directional context rather than a final verdict."
        case .low:
            "This was inferred from thinner input. Double-check the label before acting on it."
        }
    }
}

private struct AnalysisHero: View {
    let analysis: ScanAnalysis
    let strongestLens: LensScore?
    let softestLens: LensScore?

    var body: some View {
        WLHeroSurface {
            VStack(alignment: .leading, spacing: WLSpacing.l) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: analysis.productType.title,
                            systemImage: "seal",
                            tone: .accent,
                            style: .heroGlass
                        )

                        Text(analysis.resolvedProduct.name)
                            .font(WLTypography.hero)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(analysis.overallSummary)
                            .font(WLTypography.body)
                            .foregroundStyle(Color.white.opacity(0.90))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: WLSpacing.s)
                }

                WLHeroGlassGroup {
                    HStack(spacing: WLSpacing.s) {
                        metricPill(
                            title: "Standout",
                            value: strongestLens?.lens.title ?? "—"
                        )

                        metricPill(
                            title: "Gentle caution",
                            value: softestLens?.lens.title ?? "—"
                        )
                    }
                }

                WLHeroGlassGroup {
                    HStack(spacing: WLSpacing.s) {
                        detailPill(title: "Source", value: analysis.source.title)
                        detailPill(title: "Confidence", value: analysis.confidence.title)
                    }
                }
            }
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        WLAdaptiveGlassSurface(
            shape: .roundedRect(WLCorner.m),
            tint: Color.white.opacity(0.16),
            fallbackFill: Color.white.opacity(0.12),
            fallbackStroke: Color.white.opacity(0.10)
        ) {
            VStack(alignment: .leading, spacing: WLSpacing.xxs) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.70))
                Text(value)
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WLSpacing.m)
            .padding(.vertical, 14)
        }
    }

    private func detailPill(title: String, value: String) -> some View {
        WLAdaptiveGlassSurface(
            shape: .capsule,
            tint: Color.white.opacity(0.14),
            fallbackFill: Color.white.opacity(0.10),
            fallbackStroke: Color.white.opacity(0.10)
        ) {
            HStack(spacing: WLSpacing.xs) {
                Text(title)
                    .foregroundStyle(Color.white.opacity(0.72))
                Text(value)
                    .foregroundStyle(.white)
            }
            .font(WLTypography.caption)
            .padding(.horizontal, WLSpacing.m)
            .padding(.vertical, 12)
        }
    }
}

private struct AnalysisConfidenceCard: View {
    let explanation: String
    let confidence: ConfidenceLevel

    private var tone: WLStatusBadge.Tone {
        switch confidence {
        case .high:
            .success
        case .medium:
            .accent
        case .low:
            .caution
        }
    }

    var body: some View {
        WLSurfaceCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                HStack(alignment: .top) {
                    WLStatusBadge(
                        title: "Confidence: \(confidence.title)",
                        systemImage: "scope",
                        tone: tone
                    )

                    Spacer()

                    WLPill(title: "Directional only", tone: .soft)
                }

                Text(explanation)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                Text("This is consumer wellness guidance, not medical advice.")
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.ink)
            }
        }
    }
}

private struct AnalysisReasonCard: View {
    let reason: ReasonItem

    private var tone: WLStatusBadge.Tone {
        switch reason.impact {
        case .positive:
            .success
        case .caution:
            .caution
        case .neutral:
            .accent
        }
    }

    private var fill: LinearGradient {
        switch reason.impact {
        case .positive:
            LinearGradient(
                colors: [WLPalette.success.opacity(0.12), Color.white.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .caution:
            LinearGradient(
                colors: [WLPalette.caution.opacity(0.14), Color.white.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neutral:
            LinearGradient(
                colors: [WLPalette.lavender.opacity(0.12), Color.white.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.s) {
            HStack(alignment: .top) {
                Text(reason.title)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Spacer()

                WLStatusBadge(
                    title: badgeTitle,
                    systemImage: badgeSymbol,
                    tone: tone
                )
            }

            Text(reason.detail)
                .font(WLTypography.body)
                .foregroundStyle(WLPalette.inkSoft)
        }
        .padding(WLSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wlCardSurface(fill: fill)
    }

    private var badgeTitle: String {
        switch reason.impact {
        case .positive:
            "Supportive"
        case .caution:
            "Caution"
        case .neutral:
            "Context"
        }
    }

    private var badgeSymbol: String {
        switch reason.impact {
        case .positive:
            "plus.circle"
        case .caution:
            "exclamationmark.circle"
        case .neutral:
            "circle.grid.2x2"
        }
    }
}

private struct AnalysisWarningCard: View {
    let warning: String

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.s) {
            HStack(spacing: WLSpacing.s) {
                WLIcon(systemName: "exclamationmark.triangle", color: WLPalette.caution, size: 15)
                Text("Watch this")
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.caution)
            }

            Text(warning)
                .font(WLTypography.body)
                .foregroundStyle(WLPalette.inkSoft)
        }
        .padding(WLSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wlCardSurface(
            fill: LinearGradient(
                colors: [WLPalette.caution.opacity(0.12), Color.white.opacity(0.97)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct AnalysisSuggestionCard: View {
    let suggestion: AlternativeSuggestion

    var body: some View {
        WLSurfaceCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text(suggestion.productName)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text(suggestion.whyBetter)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }

                    Spacer()
                }

                FlowLayout(spacing: WLSpacing.xs) {
                    ForEach(suggestion.improvedLenses, id: \.self) { lens in
                        WLStatusBadge(title: lens.title, systemImage: lens.icon, tone: .accent)
                    }
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        return CGSize(width: width, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if point.x + size.width > bounds.maxX, point.x > bounds.minX {
                point.x = bounds.minX
                point.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: point, proposal: ProposedViewSize(width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            point.x += size.width + spacing
        }
    }
}

#Preview("Analysis") {
    AnalysisView(
        analysis: previewAnalysis
    )
}

private var previewAnalysis: ScanAnalysis {
    let product = SampleCatalog.products.first(where: { $0.barcode == "850000001" }) ?? SampleCatalog.products[0]
    return AnalysisEngine().analyze(
        product: product,
        userContext: .starter,
        source: .manualBarcode,
        confidence: .high,
        catalog: SampleCatalog.products
    )
}
