import SwiftUI

enum AnalysisActionKind: String, Equatable {
    case saveToRoutine
    case avoidForNow
    case swapInstead
    case askStrategist
    case trackAgain
    case saveFavorite
    case saveToPantry
}

struct AnalysisPresentationPlan: Equatable {
    let displayTitle: String
    let heroBadgeTitle: String
    let verdict: AnalysisVerdict
    let verdictTitle: String
    let overallScore: Int
    let summary: String
    let whyToday: [String]
    let recommendedActions: [String]
    let followUpPrompt: String
    let primaryAction: AnalysisActionKind
    let primaryButtonTitle: String
    let primaryActionSummary: String
    let secondaryAction: AnalysisActionKind?
    let secondaryButtonTitle: String?
    let swapPreviewTitle: String?
    let swapPreviewReason: String?
    let confidence: ConfidenceLevel

    static func build(analysis: ScanAnalysis, structured: AnalysisEnvelope?) -> AnalysisPresentationPlan {
        let overallScore = structured?.overallScore ?? fallbackScore(for: analysis)
        let verdict = structured?.verdict ?? fallbackVerdict(for: overallScore, confidence: analysis.confidence)
        let whyToday = Array((structured?.whyToday ?? fallbackWhyToday(for: analysis)).prefix(2))
        let recommendedActions = Array((structured?.recommendedActions ?? []).prefix(2))
        let followUpPrompt = structured?.followUpPrompt ?? fallbackFollowUpPrompt(for: analysis.source)
        let hasAlternatives = !analysis.alternatives.isEmpty
        let topAlternative = analysis.alternatives.first

        let displayTitle: String = {
            switch structured?.entityType {
            case .meal:
                return "Meal Snapshot"
            case .menuItem:
                return "Menu Scanner"
            default:
                switch analysis.source {
                case .mealPhoto:
                    return "Meal Snapshot"
                case .menuPhoto:
                    return "Menu Scanner"
                default:
                    return analysis.resolvedProduct.name
                }
            }
        }()

        let heroBadgeTitle: String = {
            switch structured?.entityType {
            case .meal:
                return "Meal Snapshot"
            case .menuItem:
                return "Menu Scanner"
            default:
                switch analysis.source {
                case .mealPhoto:
                    return "Meal Snapshot"
                case .menuPhoto:
                    return "Menu Scanner"
                default:
                    return analysis.productType.title
                }
            }
        }()

        let verdictTitle: String = {
            switch verdict {
            case .good:
                return "Strong fit for today"
            case .adjust:
                return "Usable with adjustment"
            case .avoid:
                return hasAlternatives ? "Swap before repeating" : "Lower-fit choice today"
            case .needsMoreInfo:
                return "Needs a cleaner read"
            }
        }()

        let summary = whyToday.first ?? analysis.overallSummary

        let primaryAction: AnalysisActionKind
        let primaryButtonTitle: String
        let primaryActionSummary: String
        let secondaryAction: AnalysisActionKind?
        let secondaryButtonTitle: String?

        switch verdict {
        case .good:
            primaryAction = .saveToRoutine
            primaryButtonTitle = "Keep this in routine"
            primaryActionSummary = "The read is supportive enough to treat this as a likely repeat option if it matches how it felt in real life."
            secondaryAction = .askStrategist
            secondaryButtonTitle = "Ask strategist"
        case .adjust:
            if hasAlternatives {
                primaryAction = .swapInstead
                primaryButtonTitle = "Choose the softer swap"
                primaryActionSummary = "This is close, but the swap looks like the cleaner move for today."
            } else {
                primaryAction = .trackAgain
                primaryButtonTitle = "Track this again"
                primaryActionSummary = "This can work, but it needs one more deliberate read before it earns a routine slot."
            }
            secondaryAction = .askStrategist
            secondaryButtonTitle = "Ask strategist"
        case .avoid:
            if hasAlternatives {
                primaryAction = .swapInstead
                primaryButtonTitle = "Pick the swap instead"
                primaryActionSummary = "The current option reads as low-fit for today. Move to the softer alternative instead of forcing it."
                secondaryAction = .avoidForNow
                secondaryButtonTitle = "Avoid this for now"
            } else {
                primaryAction = .avoidForNow
                primaryButtonTitle = "Avoid this for now"
                primaryActionSummary = "Treat this as a lower-fit choice today and keep it out of the routine until the context changes."
                secondaryAction = .askStrategist
                secondaryButtonTitle = "Ask strategist"
            }
        case .needsMoreInfo:
            primaryAction = .askStrategist
            primaryButtonTitle = "Ask strategist"
            primaryActionSummary = "The input is thin enough that you should escalate or get a cleaner read before making this a repeat decision."
            secondaryAction = .trackAgain
            secondaryButtonTitle = "Track this again"
        }

        return AnalysisPresentationPlan(
            displayTitle: displayTitle,
            heroBadgeTitle: heroBadgeTitle,
            verdict: verdict,
            verdictTitle: verdictTitle,
            overallScore: overallScore,
            summary: summary,
            whyToday: whyToday,
            recommendedActions: recommendedActions,
            followUpPrompt: followUpPrompt,
            primaryAction: primaryAction,
            primaryButtonTitle: primaryButtonTitle,
            primaryActionSummary: primaryActionSummary,
            secondaryAction: secondaryAction,
            secondaryButtonTitle: secondaryButtonTitle,
            swapPreviewTitle: topAlternative?.productName,
            swapPreviewReason: topAlternative?.whyBetter,
            confidence: analysis.confidence
        )
    }

    private static func fallbackScore(for analysis: ScanAnalysis) -> Int {
        let total = analysis.lensScores.map(\.score).reduce(0, +)
        return Int((Double(total) / Double(max(analysis.lensScores.count, 1))).rounded())
    }

    private static func fallbackVerdict(for overallScore: Int, confidence: ConfidenceLevel) -> AnalysisVerdict {
        if confidence == .low && overallScore < 55 {
            return .needsMoreInfo
        }
        switch overallScore {
        case 78...:
            return .good
        case 58...:
            return .adjust
        default:
            return .avoid
        }
    }

    private static func fallbackWhyToday(for analysis: ScanAnalysis) -> [String] {
        var items = [analysis.overallSummary]
        if let topReason = analysis.topReasons.first?.detail {
            items.append(topReason)
        }
        if let firstWarning = analysis.warnings.first {
            items.append(firstWarning)
        }
        return Array(items.prefix(2))
    }

    private static func fallbackFollowUpPrompt(for source: ScanSource) -> String {
        switch source {
        case .mealPhoto:
            "How did this meal feel for your energy, digestion, and satiety a few hours later?"
        case .menuPhoto:
            "Did this menu choice feel aligned with what you needed today?"
        default:
            "Did this read match how this choice actually felt for you?"
        }
    }
}

struct ScanVerdictSurfaceContent: Equatable {
    struct WatchoutItem: Equatable, Identifiable {
        let id: UUID
        let title: String
        let detail: String
        let severity: LILADomain.WatchoutSeverity
        let relevance: LILADomain.PersonalRelevance
    }

    let productName: String
    let fit: LILADomain.FitLevel
    let fitTitle: String
    let headline: String
    let primaryReason: String
    let confidence: LILADomain.Confidence
    let confidenceTitle: String
    let metadataSummary: String
    let sourceTitle: String
    let readStateTitle: String
    let provenanceTitle: String
    let guidanceNote: String?
    let watchouts: [WatchoutItem]
    let betterSwapTitle: String?
    let betterSwapReason: String?
    let followUpPrompt: String?

    static func build(verdict: LILADomain.ScanVerdict) -> ScanVerdictSurfaceContent {
        let readStateTitle = verdict.scanSource.readStateTitle(for: verdict.resolvedProduct)
        let provenanceTitle = verdict.resolvedProduct.resolutionSource.surfaceTitle
        let confidenceTitle = verdict.confidence.surfaceTitle
        return ScanVerdictSurfaceContent(
            productName: verdict.resolvedProduct.name,
            fit: verdict.fit,
            fitTitle: verdict.fit.surfaceTitle,
            headline: verdict.headline,
            primaryReason: verdict.primaryReason,
            confidence: verdict.confidence,
            confidenceTitle: confidenceTitle,
            metadataSummary: [readStateTitle, provenanceTitle, confidenceTitle].joined(separator: " | "),
            sourceTitle: verdict.scanSource.surfaceTitle,
            readStateTitle: readStateTitle,
            provenanceTitle: provenanceTitle,
            guidanceNote: verdict.scanSource.directionalGuidanceNote(for: verdict.resolvedProduct),
            watchouts: Array(verdict.watchouts.prefix(2)).map {
                WatchoutItem(
                    id: $0.id,
                    title: $0.title,
                    detail: $0.detail,
                    severity: $0.severity,
                    relevance: $0.personalRelevance
                )
            },
            betterSwapTitle: verdict.betterSwap?.productName,
            betterSwapReason: verdict.betterSwap?.whyBetter,
            followUpPrompt: verdict.trackPrompt?.questionText
        )
    }
}

extension LILADomain.FitLevel {
    var surfaceTitle: String {
        switch self {
        case .greatFit:
            "Great fit"
        case .goodFit:
            "Good fit"
        case .occasional:
            "Occasional"
        case .skip:
            "Skip for now"
        case .unclear:
            "Needs a cleaner read"
        }
    }

    var badgeTone: WLStatusBadge.Tone {
        switch self {
        case .greatFit, .goodFit:
            .success
        case .occasional, .unclear:
            .accent
        case .skip:
            .caution
        }
    }

    var pillTone: WLPill.Tone {
        switch self {
        case .greatFit, .goodFit:
            .accent
        case .occasional, .unclear:
            .soft
        case .skip:
            .neutral
        }
    }

    var symbol: String {
        switch self {
        case .greatFit, .goodFit:
            "checkmark.seal"
        case .occasional:
            "slider.horizontal.3"
        case .skip:
            "exclamationmark.triangle"
        case .unclear:
            "questionmark.circle"
        }
    }
}

private extension LILADomain.Confidence {
    var surfaceTitle: String {
        switch self {
        case .high:
            "High confidence"
        case .medium:
            "Medium confidence"
        case .low:
            "Low confidence"
        case .insufficient:
            "Insufficient confidence"
        }
    }
}

private extension LILADomain.ScanSource {
    var surfaceTitle: String {
        switch self {
        case .liveBarcode:
            "Live barcode"
        case .manualBarcode:
            "Manual barcode"
        case .labelPhoto:
            "Label photo"
        case .mealPhoto:
            "Meal snapshot"
        case .menuPhoto:
            "Menu scanner"
        case .manualLabel:
            "Manual label"
        case .voiceLog:
            "Voice log"
        }
    }

    func readStateTitle(for resolvedProduct: LILADomain.ResolvedProduct) -> String {
        guard resolvedProduct.hasResolutionSemantic(.directional) else {
            return "Resolved product"
        }
        switch self {
        case .labelPhoto, .manualLabel:
            return "Directional label read"
        case .mealPhoto:
            return "Directional meal read"
        case .menuPhoto:
            return "Directional menu read"
        case .liveBarcode, .manualBarcode:
            return "Unresolved barcode read"
        case .voiceLog:
            return "Directional voice read"
        }
    }

    func directionalGuidanceNote(for resolvedProduct: LILADomain.ResolvedProduct) -> String? {
        guard resolvedProduct.hasResolutionSemantic(.directional) else {
            return nil
        }
        switch self {
        case .labelPhoto, .manualLabel:
            return "This is a directional label read, not an exact packaged-food match yet. Rescan with a barcode or a cleaner label when you can."
        case .mealPhoto:
            return "This meal read stays directional in this phase. Use it for guidance, not exact product identity."
        case .menuPhoto:
            return "This menu read stays directional in this phase. Treat it as a pre-order steer, not a resolved product."
        case .liveBarcode, .manualBarcode:
            return "The barcode did not resolve to a stable packaged-food match yet. Try another scan or add clearer label details."
        case .voiceLog:
            return "This voice-led read is directional and should be confirmed with a stronger packaged-food input."
        }
    }
}

private extension LILADomain.ResolutionSource {
    var surfaceTitle: String {
        switch self {
        case .openFoodFacts:
            "Open Food Facts"
        case .usdaFoodDataCentral:
            "USDA nutrients"
        case .nihDSLD:
            "NIH DSLD"
        case .cosing:
            "COSING"
        case .localCatalog:
            "Local catalog"
        case .agentInferred:
            "Directional inference"
        case .userProvided:
            "User provided"
        case .userEdited:
            "User edited"
        }
    }
}

private extension LILADomain.WatchoutSeverity {
    var surfaceTitle: String {
        switch self {
        case .gentle:
            "Gentle"
        case .moderate:
            "Watch"
        case .important:
            "Important"
        }
    }

    var pillTone: WLPill.Tone {
        switch self {
        case .gentle:
            .soft
        case .moderate, .important:
            .neutral
        }
    }
}

private extension LILADomain.PersonalRelevance {
    var surfaceTitle: String {
        switch self {
        case .general:
            "General"
        case .personal:
            "Personal"
        case .clinical:
            "Higher sensitivity"
        }
    }
}

struct AnalysisView: View {
    let analysis: ScanAnalysis

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showStrategist = false

    private var structuredEvent: ScanEvent? {
        model.scanEvent(for: analysis)
    }

    private var patternInsight: PatternInsight? {
        model.leadingPatternInsight(for: analysis)
    }

    private var sortedLensScores: [LensScore] {
        analysis.lensScores.sorted(by: { $0.score > $1.score })
    }

    private var presentation: AnalysisPresentationPlan {
        AnalysisPresentationPlan.build(
            analysis: analysis,
            structured: structuredEvent?.analysis
        )
    }

    private var scanVerdict: LILADomain.ScanVerdict {
        if let storedVerdict = model.scanVerdict(for: analysis) {
            return storedVerdict
        }

        let context = model.userProfile.lilaContext()
        if let structuredAnalysis = structuredEvent?.analysis {
            return structuredAnalysis.lilaVerdict(
                fallbackAnalysis: analysis,
                context: context
            )
        }

        return analysis.lilaVerdict(context: context)
    }

    private var verdictSurface: ScanVerdictSurfaceContent {
        ScanVerdictSurfaceContent.build(verdict: scanVerdict)
    }

    private var hiddenSupportActions: Set<AnalysisActionKind> {
        Set([presentation.primaryAction, presentation.secondaryAction].compactMap { $0 })
    }

    var body: some View {
        NavigationStack {
            WLScreen {
                AnalysisHero(
                    presentation: presentation,
                    verdictSurface: verdictSurface
                )

                AnalysisOutcomeCard(
                    presentation: presentation,
                    followUpPrompt: nil,
                    primaryAction: {
                        handleAction(presentation.primaryAction)
                    },
                    secondaryAction: presentation.secondaryAction.map { action in
                        {
                            handleAction(action)
                        }
                    }
                )

                AnalysisImpactCard(
                    content: verdictSurface,
                    lensScores: sortedLensScores
                )

                if model.featureFlags.patternAgent, let patternInsight {
                    AnalysisPatternInsightCard(
                        insight: patternInsight,
                        isUnlocked: model.hasAccess(to: .patternAgent),
                        unlock: {
                            _ = model.requireAccess(
                                to: .patternAgent,
                                surface: .patternDetail,
                                previewLines: [patternInsight.title, patternInsight.summary]
                            )
                        }
                    )
                }

                if !analysis.alternatives.isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLSectionHeader(
                            title: "Softer swaps",
                            subtitle: "Nearby alternatives worth reviewing before this becomes a repeat choice.",
                            systemImage: "arrow.triangle.2.circlepath"
                        )

                        ForEach(analysis.alternatives) { suggestion in
                            AnalysisSuggestionCard(suggestion: suggestion)
                        }
                    }
                }

                if !analysis.topReasons.isEmpty || !analysis.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLSectionHeader(
                            title: "Why it landed here",
                            subtitle: "The strongest supporting and caution signals behind the recommendation.",
                            systemImage: "slider.horizontal.3"
                        )

                        ForEach(Array(analysis.topReasons.prefix(3))) { reason in
                            AnalysisReasonCard(reason: reason)
                        }

                        ForEach(Array(analysis.warnings.prefix(2)), id: \.self) { warning in
                            AnalysisWarningCard(warning: warning)
                        }
                    }
                }

                AnalysisConfidenceCard(
                    explanation: confidenceExplanation,
                    confidence: analysis.confidence
                )

                AnalysisSupportingActionsCard(
                    pantryUnlocked: model.hasAccess(to: .pantryMVP),
                    showSaveToPantry: model.featureFlags.pantryMVP,
                    showAskStrategist: !hiddenSupportActions.contains(.askStrategist),
                    showTrackAgain: !hiddenSupportActions.contains(.trackAgain),
                    saveFavorite: {
                        handleAction(.saveFavorite)
                    },
                    saveToPantry: {
                        handleAction(.saveToPantry)
                    },
                    askStrategist: {
                        handleAction(.askStrategist)
                    },
                    trackAgain: {
                        handleAction(.trackAgain)
                    }
                )

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
        .sheet(isPresented: $showStrategist) {
            StrategistChatView(entryPoint: .scan, linkedAnalysis: analysis)
        }
    }

    private var confidenceExplanation: String {
        switch analysis.confidence {
        case .high:
            "This match is strong enough that the read should feel stable, not noisy."
        case .medium:
            "This is useful as directional guidance, but keep the decision flexible if real-life feedback disagrees."
        case .low:
            "The input was thinner than ideal. Treat the read as a prompt to verify, not a final answer."
        }
    }

    private func handleAction(_ action: AnalysisActionKind) {
        switch action {
        case .saveToRoutine:
            commitDecision(.saveToRoutine)
        case .avoidForNow:
            commitDecision(.avoidForNow)
        case .swapInstead:
            commitDecision(.swapInstead)
        case .askStrategist:
            commitDecision(.askStrategist, dismissAfter: false)
            showStrategist = true
        case .trackAgain:
            commitDecision(.trackAgain)
        case .saveFavorite:
            model.saveFavorite(from: analysis)
        case .saveToPantry:
            let preview = [
                "Pantry keeps your strongest repeat choices visible.",
                analysis.overallSummary
            ]
            guard model.requireAccess(
                to: .pantryMVP,
                surface: .pantry,
                previewLines: preview
            ) else { return }
            model.saveToPantry(from: analysis)
        }
    }

    private func commitDecision(_ kind: ScanDecisionKind, dismissAfter: Bool = true) {
        model.recordScanDecision(kind, for: analysis)
        if dismissAfter {
            dismiss()
        }
    }
}

private struct AnalysisHero: View {
    let presentation: AnalysisPresentationPlan
    let verdictSurface: ScanVerdictSurfaceContent

    var body: some View {
        WLHeroSurface {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: presentation.heroBadgeTitle,
                            systemImage: "seal",
                            tone: .accent,
                            style: .heroGlass
                        )

                        Spacer(minLength: WLSpacing.s)

                        WLPill(title: verdictSurface.fitTitle, tone: verdictSurface.fit.pillTone)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: presentation.heroBadgeTitle,
                            systemImage: "seal",
                            tone: .accent,
                            style: .heroGlass
                        )

                        WLPill(title: verdictSurface.fitTitle, tone: verdictSurface.fit.pillTone)
                    }
                }

                Text(verdictSurface.productName)
                    .font(WLTypography.hero)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(verdictSurface.headline)
                    .font(WLTypography.title)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(verdictSurface.primaryReason)
                    .font(WLTypography.body)
                    .foregroundStyle(Color.white.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 108), spacing: WLSpacing.s)],
                    alignment: .leading,
                    spacing: WLSpacing.s
                ) {
                    detailPill(title: "Fit", value: verdictSurface.fitTitle)
                    detailPill(title: "Confidence", value: verdictSurface.confidenceTitle)
                    detailPill(title: "Read", value: verdictSurface.readStateTitle)
                    detailPill(title: "Provenance", value: verdictSurface.provenanceTitle)
                }
            }
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                    .foregroundStyle(Color.white.opacity(0.72))
                Text(value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                    .foregroundStyle(.white)
            }
            .font(WLTypography.caption)
            .padding(.horizontal, WLSpacing.m)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AnalysisImpactCard: View {
    let content: ScanVerdictSurfaceContent
    let lensScores: [LensScore]

    var body: some View {
        WLFeatureCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Impact on your goals",
                    subtitle: "Where this looks supportive, where it softens, and what deserves extra attention.",
                    systemImage: "scope"
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: content.fitTitle,
                            systemImage: content.fit.symbol,
                            tone: content.fit.badgeTone
                        )

                        WLPill(title: content.confidenceTitle, tone: .soft)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: content.fitTitle,
                            systemImage: content.fit.symbol,
                            tone: content.fit.badgeTone
                        )

                        WLPill(title: content.confidenceTitle, tone: .soft)
                    }
                }

                Text(content.headline)
                    .font(WLTypography.title)
                    .foregroundStyle(WLPalette.ink)

                Text(content.primaryReason)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.inkSoft)

                if let guidanceNote = content.guidanceNote {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text(content.readStateTitle)
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.ink)

                        Text(guidanceNote)
                            .font(WLTypography.caption)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                    .padding(WLSpacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .wlCardSurface(style: .quiet)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: WLSpacing.s)], spacing: WLSpacing.s) {
                    ForEach(lensScores) { score in
                        WLLensTile(score: score)
                    }
                }

                if !content.watchouts.isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text("Watchouts")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.ink)

                        ForEach(content.watchouts) { watchout in
                            ScanVerdictWatchoutCard(watchout: watchout)
                        }
                    }
                }

                if let betterSwapTitle = content.betterSwapTitle,
                   let betterSwapReason = content.betterSwapReason {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text("Better swap")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.ink)

                        Text(betterSwapTitle)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text(betterSwapReason)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                    .padding(WLSpacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .wlCardSurface(style: .quiet)
                }

                if let followUpPrompt = content.followUpPrompt {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Follow-up prompt")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.rose)

                        Text(followUpPrompt)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }
            }
        }
    }
}

private struct ScanVerdictWatchoutCard: View {
    let watchout: ScanVerdictSurfaceContent.WatchoutItem

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.s) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: WLSpacing.s) {
                    Text(watchout.title)
                        .font(WLTypography.bodyEmphasis)
                        .foregroundStyle(WLPalette.ink)

                    Spacer(minLength: WLSpacing.s)

                    HStack(spacing: WLSpacing.xs) {
                        WLPill(title: watchout.severity.surfaceTitle, tone: watchout.severity.pillTone)
                        WLPill(title: watchout.relevance.surfaceTitle, tone: .soft)
                    }
                }

                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    Text(watchout.title)
                        .font(WLTypography.bodyEmphasis)
                        .foregroundStyle(WLPalette.ink)

                    HStack(spacing: WLSpacing.xs) {
                        WLPill(title: watchout.severity.surfaceTitle, tone: watchout.severity.pillTone)
                        WLPill(title: watchout.relevance.surfaceTitle, tone: .soft)
                    }
                }
            }

            Text(watchout.detail)
                .font(WLTypography.body)
                .foregroundStyle(WLPalette.inkSoft)
        }
        .padding(WLSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wlCardSurface(style: .caution)
    }
}

private struct AnalysisOutcomeCard: View {
    let presentation: AnalysisPresentationPlan
    let followUpPrompt: String?
    let primaryAction: () -> Void
    let secondaryAction: (() -> Void)?

    var body: some View {
        WLFeatureCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Best next step",
                    subtitle: "Make the decision before diving into the supporting detail.",
                    systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: presentation.verdictTitle,
                            systemImage: verdictSymbol,
                            tone: verdictTone
                        )
                        WLPill(title: "Score \(presentation.overallScore)", tone: .soft)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: presentation.verdictTitle,
                            systemImage: verdictSymbol,
                            tone: verdictTone
                        )
                        WLPill(title: "Score \(presentation.overallScore)", tone: .soft)
                    }
                }

                Text(presentation.primaryActionSummary)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                if !presentation.whyToday.isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Why today")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.ink)

                        ForEach(presentation.whyToday, id: \.self) { item in
                            Text("• \(item)")
                                .font(WLTypography.body)
                                .foregroundStyle(WLPalette.inkSoft)
                        }
                    }
                }

                if let swapPreviewTitle = presentation.swapPreviewTitle,
                   let swapPreviewReason = presentation.swapPreviewReason,
                   presentation.primaryAction != .swapInstead {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Swap preview")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.ink)

                        Text("\(swapPreviewTitle) looks softer because \(swapPreviewReason)")
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }

                if !presentation.recommendedActions.isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.xs) {
                        Text("Operational guidance")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.ink)

                        ForEach(presentation.recommendedActions, id: \.self) { action in
                            Text("• \(action)")
                                .font(WLTypography.body)
                                .foregroundStyle(WLPalette.inkSoft)
                        }
                    }
                }

                WLActionGroup {
                    WLPrimaryButton(
                        title: presentation.primaryButtonTitle,
                        systemImage: primarySymbol
                    ) {
                        primaryAction()
                    }

                    if let secondaryAction,
                       let secondaryButtonTitle = presentation.secondaryButtonTitle {
                        WLSecondaryButton(
                            title: secondaryButtonTitle,
                            systemImage: secondarySymbol
                        ) {
                            secondaryAction()
                        }
                    }
                }

                if let followUpPrompt {
                    Text(followUpPrompt)
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(WLPalette.rose)
                }
            }
        }
    }

    private var verdictTone: WLStatusBadge.Tone {
        switch presentation.verdict {
        case .good:
            return .success
        case .adjust, .needsMoreInfo:
            return .accent
        case .avoid:
            return .caution
        }
    }

    private var verdictSymbol: String {
        switch presentation.verdict {
        case .good:
            return "checkmark.seal"
        case .adjust:
            return "slider.horizontal.3"
        case .avoid:
            return "exclamationmark.triangle"
        case .needsMoreInfo:
            return "questionmark.circle"
        }
    }

    private var primarySymbol: String {
        switch presentation.primaryAction {
        case .saveToRoutine:
            return "checkmark.circle"
        case .avoidForNow:
            return "minus.circle"
        case .swapInstead:
            return "arrow.triangle.2.circlepath"
        case .askStrategist:
            return "message"
        case .trackAgain:
            return "clock.arrow.circlepath"
        case .saveFavorite:
            return "star"
        case .saveToPantry:
            return "shippingbox"
        }
    }

    private var secondarySymbol: String {
        switch presentation.secondaryAction {
        case .saveToRoutine:
            return "checkmark.circle"
        case .avoidForNow:
            return "minus.circle"
        case .swapInstead:
            return "arrow.triangle.2.circlepath"
        case .askStrategist:
            return "message"
        case .trackAgain:
            return "clock.arrow.circlepath"
        case .saveFavorite:
            return "star"
        case .saveToPantry:
            return "shippingbox"
        case nil:
            return "ellipsis"
        }
    }
}

private struct AnalysisConfidenceCard: View {
    let explanation: String
    let confidence: ConfidenceLevel

    private var tone: WLStatusBadge.Tone {
        switch confidence {
        case .high:
            return .success
        case .medium:
            return .accent
        case .low:
            return .caution
        }
    }

    private var framing: String {
        switch confidence {
        case .high:
            return "Stable signal"
        case .medium:
            return "Directional"
        case .low:
            return "Thin input"
        }
    }

    var body: some View {
        WLQuietCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: "Confidence: \(confidence.title)",
                            systemImage: "scope",
                            tone: tone
                        )

                        Spacer(minLength: WLSpacing.s)

                        WLPill(title: framing, tone: .soft)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: "Confidence: \(confidence.title)",
                            systemImage: "scope",
                            tone: tone
                        )

                        WLPill(title: framing, tone: .soft)
                    }
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

private struct AnalysisSupportingActionsCard: View {
    let pantryUnlocked: Bool
    let showSaveToPantry: Bool
    let showAskStrategist: Bool
    let showTrackAgain: Bool
    let saveFavorite: () -> Void
    let saveToPantry: () -> Void
    let askStrategist: () -> Void
    let trackAgain: () -> Void

    var body: some View {
        WLQuietCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: WLSpacing.s) {
                        WLSectionHeader(
                            title: "Save or keep exploring",
                            subtitle: "Use these when the read is useful, but not ready to become the main routine call.",
                            systemImage: "square.stack.3d.up"
                        )

                        Spacer(minLength: WLSpacing.s)

                        if showSaveToPantry {
                            WLPill(title: pantryUnlocked ? "Pantry unlocked" : "Pantry Pro", tone: pantryUnlocked ? .soft : .accent)
                        }
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        WLSectionHeader(
                            title: "Save or keep exploring",
                            subtitle: "Use these when the read is useful, but not ready to become the main routine call.",
                            systemImage: "square.stack.3d.up"
                        )

                        if showSaveToPantry {
                            WLPill(title: pantryUnlocked ? "Pantry unlocked" : "Pantry Pro", tone: pantryUnlocked ? .soft : .accent)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    WLUtilityButton(title: "Save favorite", systemImage: "star") {
                        saveFavorite()
                    }

                    if showSaveToPantry {
                        WLSecondaryButton(
                            title: pantryUnlocked ? "Save to pantry" : "Unlock pantry",
                            systemImage: "shippingbox"
                        ) {
                            saveToPantry()
                        }
                    }

                    if showAskStrategist {
                        WLUtilityButton(title: "Ask strategist", systemImage: "message") {
                            askStrategist()
                        }
                    }

                    if showTrackAgain {
                        WLUtilityButton(title: "Track this again", systemImage: "clock.arrow.circlepath") {
                            trackAgain()
                        }
                    }
                }
            }
        }
    }
}

private struct AnalysisPatternInsightCard: View {
    let insight: PatternInsight
    let isUnlocked: Bool
    let unlock: () -> Void

    var body: some View {
        WLQuietCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Pattern context",
                    subtitle: "This compares today’s read against your recent decisions and body-signal loop.",
                    systemImage: "waveform.path.ecg.rectangle"
                )

                HStack(spacing: WLSpacing.s) {
                    WLStatusBadge(
                        title: insight.signal.title,
                        systemImage: "sparkles",
                        tone: .accent
                    )
                    WLPill(title: "Confidence \(Int((insight.confidence * 100).rounded()))", tone: .soft)
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
                    Text("Preview only. The deeper pattern action opens with Plus.")
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)

                    WLUtilityButton(title: "Unlock pattern detail", systemImage: "sparkles") {
                        unlock()
                    }
                }
            }
        }
    }
}

private struct AnalysisReasonCard: View {
    let reason: ReasonItem

    private var tone: WLStatusBadge.Tone {
        switch reason.impact {
        case .positive:
            return .success
        case .caution:
            return .caution
        case .neutral:
            return .accent
        }
    }

    private var fill: LinearGradient {
        switch reason.impact {
        case .positive:
            return LinearGradient(
                colors: [WLPalette.success.opacity(0.12), Color.white.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .caution:
            return LinearGradient(
                colors: [WLPalette.caution.opacity(0.14), Color.white.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neutral:
            return LinearGradient(
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
        .wlCardSurface(style: reason.impact == .caution ? .caution : .quiet)
    }

    private var badgeTitle: String {
        switch reason.impact {
        case .positive:
            return "Supportive"
        case .caution:
            return "Caution"
        case .neutral:
            return "Context"
        }
    }

    private var badgeSymbol: String {
        switch reason.impact {
        case .positive:
            return "plus.circle"
        case .caution:
            return "exclamationmark.circle"
        case .neutral:
            return "circle.grid.2x2"
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
        .wlCardSurface(style: .caution)
    }
}

private struct AnalysisSuggestionCard: View {
    let suggestion: AlternativeSuggestion

    var body: some View {
        WLQuietCard {
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
    AnalysisView(analysis: previewAnalysis)
        .environment(AppModel())
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
