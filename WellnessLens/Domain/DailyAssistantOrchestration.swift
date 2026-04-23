import Foundation
import OSLog

struct SafetyClaimsGuard {
    private let replacements: [(target: String, replacement: String)] = [
        ("diagnose", "guide"),
        ("diagnosis", "guidance"),
        ("treat", "support"),
        ("treatment", "support plan"),
        ("cure", "support"),
        ("reverse", "reduce"),
        ("heal", "support"),
        ("fix your hormones", "support a more hormone-friendly routine"),
        ("medical advice", "wellness guidance")
    ]

    func review(_ envelope: AnalysisEnvelope) -> AnalysisEnvelope {
        let sanitizedGreenFlags = envelope.greenFlags.map(sanitize)
        let sanitizedRedFlags = envelope.redFlags.map(sanitize)
        let sanitizedWhyToday = envelope.whyToday.map(sanitize)
        let sanitizedActions = envelope.recommendedActions.map(sanitize)
        let sanitizedSwaps = envelope.swapSuggestions.map {
            SwapSuggestion(title: sanitize($0.title), reason: sanitize($0.reason), priority: $0.priority)
        }
        let elevatedRisk: SafetyRiskLevel = envelope.confidence < 0.5 ? .medium : envelope.medicalSafety.riskLevel

        WLAssistantLogger.analysis.info("SafetyClaimsGuard reviewed analysis \(envelope.analysisID, privacy: .public)")

        return AnalysisEnvelope(
            analysisID: envelope.analysisID,
            timestamp: envelope.timestamp,
            inputType: envelope.inputType,
            entityType: envelope.entityType,
            verdict: envelope.verdict,
            overallScore: envelope.overallScore,
            lensScores: envelope.lensScores,
            whyToday: sanitizedWhyToday,
            greenFlags: sanitizedGreenFlags,
            redFlags: sanitizedRedFlags,
            recommendedActions: sanitizedActions,
            swapSuggestions: sanitizedSwaps,
            followUpPrompt: sanitize(envelope.followUpPrompt),
            confidence: envelope.confidence,
            medicalSafety: MedicalSafety(
                isMedicalAdvice: false,
                disclaimerNeeded: true,
                riskLevel: elevatedRisk
            ),
            patternContext: PatternContext(
                usedHistory: envelope.patternContext.usedHistory,
                relevantPattern: envelope.patternContext.relevantPattern.map(sanitize)
            )
        )
    }

    func review(_ insights: [PatternInsight]) -> [PatternInsight] {
        insights.map {
            PatternInsight(
                patternID: $0.patternID,
                title: sanitize($0.title),
                summary: sanitize($0.summary),
                signal: $0.signal,
                confidence: $0.confidence,
                recommendedAction: sanitize($0.recommendedAction),
                linkedScanIDs: $0.linkedScanIDs,
                linkedCheckInIDs: $0.linkedCheckInIDs,
                safetyNote: sanitize($0.safetyNote)
            )
        }
    }

    func review(_ narrative: WeeklyInsightNarrative) -> WeeklyInsightNarrative {
        WeeklyInsightNarrative(
            headline: sanitize(narrative.headline),
            patternSummary: sanitize(narrative.patternSummary),
            whatToProtect: sanitize(narrative.whatToProtect),
            whatToReduce: sanitize(narrative.whatToReduce),
            nextExperiment: sanitize(narrative.nextExperiment),
            confidence: narrative.confidence,
            supportingPatternIDs: narrative.supportingPatternIDs
        )
    }

    private func sanitize(_ raw: String) -> String {
        replacements.reduce(raw) { partial, replacement in
            partial.replacingOccurrences(
                of: replacement.target,
                with: replacement.replacement,
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }
    }
}

struct PhaseTwoArtifacts {
    var patternInsights: [PatternInsight]
    var weeklyNarrative: WeeklyInsightNarrative?
    var pantryItems: [PantryItem]
}

struct PatternAgentEngine {
    func derive(scanEvents: [ScanEvent], checkInEvents: [CheckInEvent]) -> [PatternInsight] {
        let recentScans = Array(scanEvents.prefix(10))
        let recentCheckIns = Array(checkInEvents.prefix(10))

        guard recentScans.count >= 2 || recentCheckIns.count >= 2 else {
            return []
        }

        var insights: [PatternInsight] = []
        let lowFitScans = recentScans.filter { $0.analysis.overallScore < 60 }
        let supportiveScans = recentScans.filter { $0.analysis.overallScore >= 78 }

        let softEnergyCheckIns = recentCheckIns.filter { $0.energy <= 2 }
        let softDigestionCheckIns = recentCheckIns.filter { $0.bloating >= 4 }
        let menuScans = recentScans.filter { $0.inputType == .menuPhoto }

        let energyScanIDs = orderedUnique(softEnergyCheckIns.flatMap(\.linkedScanIDs))
        let linkedEnergyScans = energyScanIDs.isEmpty
            ? Array(lowFitScans.prefix(3))
            : recentScans.filter { energyScanIDs.contains($0.id) }

        if softEnergyCheckIns.count >= 2, linkedEnergyScans.isEmpty == false {
            insights.append(
                PatternInsight(
                    patternID: "pattern-energy-soft-days",
                    title: "Softer energy days cluster around lower-fit choices",
                    summary: "Lower-fit scans are showing up near the same days your energy check-ins feel flatter.",
                    signal: .energy,
                    confidence: 0.78,
                    recommendedAction: "Bias the next few choices toward steadier protein, fiber, and calmer energy support before repeating the softer options.",
                    linkedScanIDs: linkedEnergyScans.map(\.id),
                    linkedCheckInIDs: softEnergyCheckIns.map(\.id),
                    safetyNote: "Pattern guidance only. It helps organize your week, not diagnose what caused it."
                )
            )
        }

        let digestionScanIDs = orderedUnique(softDigestionCheckIns.flatMap(\.linkedScanIDs))
        let linkedDigestionScans = digestionScanIDs.isEmpty
            ? Array(lowFitScans.prefix(3))
            : recentScans.filter { digestionScanIDs.contains($0.id) }

        if softDigestionCheckIns.count >= 2, linkedDigestionScans.isEmpty == false {
            insights.append(
                PatternInsight(
                    patternID: "pattern-digestion-load",
                    title: "Heavier digestion days are repeating",
                    summary: "Recent check-ins suggest digestion gets noisier around lower-fit meals or snacks, especially when choices stack close together.",
                    signal: .digestion,
                    confidence: 0.76,
                    recommendedAction: "Use the next few scans to protect gentler, simpler choices and avoid stacking the heaviest options back-to-back.",
                    linkedScanIDs: linkedDigestionScans.map(\.id),
                    linkedCheckInIDs: softDigestionCheckIns.map(\.id),
                    safetyNote: "This is a wellness pattern, not a medical conclusion."
                )
            )
        }

        if supportiveScans.count >= 2 {
            insights.append(
                PatternInsight(
                    patternID: "pattern-routine-anchor",
                    title: "A few repeat choices are acting like anchors",
                    summary: "Your strongest recent scans are clustering around a smaller set of repeat choices, which is a useful signal for routine building.",
                    signal: .routine,
                    confidence: 0.74,
                    recommendedAction: "Keep those stronger repeat choices easy to reach before experimenting with anything noisier.",
                    linkedScanIDs: Array(supportiveScans.prefix(3)).map(\.id),
                    linkedCheckInIDs: [],
                    safetyNote: "Treat this as a repeatability signal, not a guarantee."
                )
            )
        }

        let menuAverage = average(menuScans.map(\.analysis.overallScore))
        if menuScans.count >= 2, menuAverage > 0, menuAverage < 67 {
            insights.append(
                PatternInsight(
                    patternID: "pattern-menu-friction",
                    title: "Restaurant decisions are landing softer than home choices",
                    summary: "Menu reads are averaging lower than the rest of your recent scans, which suggests restaurant decisions deserve a slower first pass.",
                    signal: .menu,
                    confidence: 0.71,
                    recommendedAction: "Use Menu Scanner before ordering and look for one cleaner anchor instead of trying to optimize the whole menu.",
                    linkedScanIDs: menuScans.map(\.id),
                    linkedCheckInIDs: recentCheckIns.filter { !$0.linkedScanIDs.isEmpty }.map(\.id),
                    safetyNote: "Use this as decision support for eating out, not as a strict rule."
                )
            )
        }

        return Array(insights.prefix(3))
    }

    private func average(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

struct WeeklyInsightNarrativeEngine {
    func compose(
        patterns: [PatternInsight],
        scanEvents: [ScanEvent],
        checkInEvents: [CheckInEvent]
    ) -> WeeklyInsightNarrative? {
        guard patterns.isEmpty == false, scanEvents.count >= 2 || checkInEvents.count >= 2 else {
            return nil
        }

        let leadPattern = patterns[0]
        let protectPattern = patterns.first(where: { $0.signal == .routine }) ?? patterns[0]
        let reducePattern = patterns.first(where: { $0.signal != .routine }) ?? patterns[0]
        let confidence = min(max(patterns.map(\.confidence).reduce(0, +) / Double(patterns.count), 0.55), 0.92)

        let experiment: String = {
            switch reducePattern.signal {
            case .energy:
                "Pick one calmer, protein-forward anchor before the most reactive part of the day and check in on how energy actually holds."
            case .digestion:
                "Keep the next two choices simpler and lighter, then use check-ins to see whether digestion feels quieter."
            case .routine:
                "Save the best repeat choice to pantry so the stronger option stays easy on busy days."
            case .menu:
                "Scan the next menu before ordering and compare the first two viable options instead of choosing on autopilot."
            }
        }()

        return WeeklyInsightNarrative(
            headline: "Your week is starting to show a cleaner pattern",
            patternSummary: leadPattern.summary,
            whatToProtect: protectPattern.recommendedAction,
            whatToReduce: reducePattern.recommendedAction,
            nextExperiment: experiment,
            confidence: confidence,
            supportingPatternIDs: patterns.map(\.patternID)
        )
    }
}

struct PantrySeedEngine {
    func refresh(
        existingItems: [PantryItem],
        scanEvents: [ScanEvent],
        favoriteItems: [FavoriteItem],
        routines: [RoutineItem]
    ) -> [PantryItem] {
        var indexed = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.dedupeKey, $0) })

        for seed in supportiveSeeds(from: scanEvents) + favoriteSeeds(from: favoriteItems, scanEvents: scanEvents) + routineSeeds(from: routines) {
            let key = seed.dedupeKey
            if var existing = indexed[key] {
                if existing.isArchived {
                    indexed[key] = existing
                    continue
                }
                existing.title = seed.title
                existing.summary = seed.summary
                existing.relatedProductID = existing.relatedProductID ?? seed.relatedProductID
                existing.sourceKind = existing.sourceKind == .manualSave ? .manualSave : seed.sourceKind
                existing.sourceScanID = existing.sourceScanID ?? seed.sourceScanID
                if seed.lastUpdatedAt > existing.lastUpdatedAt {
                    existing.lastUpdatedAt = seed.lastUpdatedAt
                }
                indexed[key] = existing
            } else {
                indexed[key] = seed
            }
        }

        return indexed.values.sorted(by: { $0.lastUpdatedAt > $1.lastUpdatedAt })
    }

    private func supportiveSeeds(from scanEvents: [ScanEvent]) -> [PantryItem] {
        scanEvents.compactMap { event -> PantryItem? in
            guard event.analysis.overallScore >= 78 else { return nil }
            guard event.analysis.entityType == .product || event.analysis.entityType == .meal || event.analysis.entityType == .menuItem else {
                return nil
            }

            let sourceKind: PantrySourceKind = event.inputType == .menuPhoto ? .menuScan : .supportiveScan
            return PantryItem(
                id: "pantry-\(event.id)",
                title: event.normalizedPayload.entityName,
                summary: event.analysis.whyToday.first ?? "A stronger fit worth keeping close.",
                relatedProductID: event.legacyAnalysis.resolvedProduct.id,
                sourceKind: sourceKind,
                sourceScanID: event.id,
                createdAt: event.timestamp,
                lastUpdatedAt: event.timestamp,
                archivedAt: nil
            )
        }
    }

    private func favoriteSeeds(from favorites: [FavoriteItem], scanEvents: [ScanEvent]) -> [PantryItem] {
        favorites.compactMap { favorite in
            let relatedScan = scanEvents.first(where: { $0.id == favorite.scanEventID })
            return PantryItem(
                id: "pantry-favorite-\(favorite.scanEventID)",
                title: favorite.title,
                summary: favorite.summary,
                relatedProductID: relatedScan?.legacyAnalysis.resolvedProduct.id,
                sourceKind: .favorite,
                sourceScanID: favorite.scanEventID,
                createdAt: favorite.createdAt,
                lastUpdatedAt: favorite.createdAt,
                archivedAt: nil
            )
        }
    }

    private func routineSeeds(from routines: [RoutineItem]) -> [PantryItem] {
        routines.map {
            PantryItem(
                id: "pantry-routine-\($0.productID)",
                title: $0.productName,
                summary: $0.note,
                relatedProductID: $0.productID,
                sourceKind: .routine,
                sourceScanID: nil,
                createdAt: $0.createdAt,
                lastUpdatedAt: $0.createdAt,
                archivedAt: nil
            )
        }
    }
}

struct PantrySuggestionEngine {
    func suggest(pantryItems: [PantryItem], patternInsights: [PatternInsight]) -> [PantrySuggestion] {
        let activeItems = pantryItems.filter { !$0.isArchived }
        guard activeItems.isEmpty == false else { return [] }

        var suggestions: [PantrySuggestion] = []

        if let digestionPattern = patternInsights.first(where: { $0.signal == .digestion }) {
            let supporting = Array(activeItems.prefix(2))
            suggestions.append(
                PantrySuggestion(
                    id: "pantry-digestion-anchor",
                    title: "Keep a gentler backup close",
                    summary: "Use one calmer pantry anchor on the days digestion already feels noisy.",
                    reason: digestionPattern.summary,
                    supportingPantryItemIDs: supporting.map(\.id)
                )
            )
        }

        if let energyPattern = patternInsights.first(where: { $0.signal == .energy }) {
            let supporting = Array(activeItems.prefix(2))
            suggestions.append(
                PantrySuggestion(
                    id: "pantry-energy-anchor",
                    title: "Protect your first steady option",
                    summary: "Make the easiest strong option visible before the softer choice wins by convenience.",
                    reason: energyPattern.summary,
                    supportingPantryItemIDs: supporting.map(\.id)
                )
            )
        }

        if suggestions.isEmpty, activeItems.count >= 2 {
            suggestions.append(
                PantrySuggestion(
                    id: "pantry-default-anchor",
                    title: "Keep your two strongest repeats visible",
                    summary: "A tiny pantry system works best when the better default is easy to see and easy to repeat.",
                    reason: "Your pantry is large enough to start acting like a real decision shortcut.",
                    supportingPantryItemIDs: Array(activeItems.prefix(2)).map(\.id)
                )
            )
        }

        return Array(suggestions.prefix(2))
    }
}

struct RootOrchestrator {
    private let safetyGuard = SafetyClaimsGuard()
    private let patternAgent = PatternAgentEngine()
    private let weeklyNarrativeEngine = WeeklyInsightNarrativeEngine()
    private let pantrySeedEngine = PantrySeedEngine()
    private let pantrySuggestionEngine = PantrySuggestionEngine()

    func localStructuredAnalysis(
        input: ScanInput,
        legacyAnalysis: ScanAnalysis,
        recentScans: [ScanEvent],
        recentCheckIns: [CheckInEvent]
    ) -> AnalysisEnvelope {
        legacyAnalysis.makeEnvelope(
            input: input,
            recentScans: recentScans,
            recentCheckIns: recentCheckIns
        )
    }

    func composeScanEvent(
        input: ScanInput,
        legacyAnalysis: ScanAnalysis,
        structuredAnalysis: AnalysisEnvelope? = nil,
        localProfileID: String,
        recentScans: [ScanEvent],
        recentCheckIns: [CheckInEvent],
        latencyMs: Int
    ) -> ScanEvent {
        let envelope = safetyGuard.review(
            structuredAnalysis ?? localStructuredAnalysis(
                input: input,
                legacyAnalysis: legacyAnalysis,
                recentScans: recentScans,
                recentCheckIns: recentCheckIns
            )
        )

        let normalizedPayload = NormalizedScanPayload(
            source: input.sourceType.analysisInputType,
            entityName: legacyAnalysis.resolvedProduct.name,
            brand: legacyAnalysis.resolvedProduct.brand,
            productType: legacyAnalysis.productType,
            ingredients: legacyAnalysis.resolvedProduct.ingredients.map(\.name),
            claims: legacyAnalysis.resolvedProduct.claims,
            extractedText: input.rawText,
            inferredTags: legacyAnalysis.resolvedProduct.tags.map(\.rawValue)
        )

        return ScanEvent(
            id: UUID().uuidString,
            timestamp: legacyAnalysis.createdAt,
            localProfileID: localProfileID,
            inputType: input.sourceType.analysisInputType,
            normalizedPayload: normalizedPayload,
            analysis: envelope,
            legacyAnalysis: legacyAnalysis,
            sourceAgents: [
                "DeterministicScoringEngine",
                "SafetyClaimsGuard",
                "RootOrchestrator"
            ],
            latencyMs: latencyMs
        )
    }

    func composeDailyBrief(
        payload: DailyHomePayload,
        profile: UserProfile,
        latestScan: ScanEvent?,
        latestCheckIn: CheckInEvent?,
        checkInEvents: [CheckInEvent],
        routines: [RoutineItem]
    ) -> DailyBrief {
        let riskHeadline: String
        if let latestCheckIn, latestCheckIn.bloating >= 4 {
            riskHeadline = "Digestion is the main risk to protect today."
        } else if let latestScan, latestScan.analysis.overallScore < 58 {
            riskHeadline = "Recent scans leaned softer than ideal, so today needs a cleaner first decision."
        } else {
            riskHeadline = "Protect steadier energy and digestion with the first decision of the day."
        }

        let priority = profile.nutritionPriorities.first?.title ?? profile.userContext.goals.first?.title ?? "Daily clarity"
        let cta: DailyBriefAction = {
            if let latestScan,
               checkInEvents.contains(where: { $0.linkedScanIDs.contains(latestScan.id) }) == false {
                return DailyBriefAction(
                    kind: .updateFeedback,
                    title: "Close the last loop",
                    subtitle: "Log whether \(latestScan.legacyAnalysis.resolvedProduct.name) actually held up in real use."
                )
            }
            if let latestCheckIn,
               (latestCheckIn.energy <= 2 || latestCheckIn.bloating <= 2),
               let routine = routines.first {
                return DailyBriefAction(
                    kind: .scanBreakfast,
                    title: "Scan your safest default",
                    subtitle: "Use \(routine.productName) as the benchmark before anything noisier."
                )
            }
            if profile.restaurantFrequency == .oftenOut {
                return DailyBriefAction(
                    kind: .mealSnapshot,
                    title: "Snapshot your next meal",
                    subtitle: "Use Meal Snapshot before a restaurant or snack decision."
                )
            }
            return DailyBriefAction(
                kind: .scanBreakfast,
                title: "Scan your first real choice",
                subtitle: "Use breakfast, coffee, or a snack to set the tone."
            )
        }()

        return DailyBrief(
            headline: payload.todayFocus.title,
            riskHeadline: riskHeadline,
            nutritionPriority: priority,
            cta: cta,
            notificationCopy: "\(payload.todayFocus.title). \(riskHeadline)"
        )
    }

    func refreshPhaseTwoArtifacts(
        scanEvents: [ScanEvent],
        checkInEvents: [CheckInEvent],
        favoriteItems: [FavoriteItem],
        routines: [RoutineItem],
        existingPantryItems: [PantryItem]
    ) -> PhaseTwoArtifacts {
        let reviewedPatterns = safetyGuard.review(
            patternAgent.derive(scanEvents: scanEvents, checkInEvents: checkInEvents)
        )
        let weeklyNarrative = weeklyNarrativeEngine.compose(
            patterns: reviewedPatterns,
            scanEvents: scanEvents,
            checkInEvents: checkInEvents
        ).map(safetyGuard.review)
        let pantryItems = pantrySeedEngine.refresh(
            existingItems: existingPantryItems,
            scanEvents: scanEvents,
            favoriteItems: favoriteItems,
            routines: routines
        )

        WLAssistantLogger.analysis.info(
            "Phase 2 refresh generated \(reviewedPatterns.count, privacy: .public) patterns and \(pantryItems.count, privacy: .public) pantry items"
        )

        return PhaseTwoArtifacts(
            patternInsights: reviewedPatterns,
            weeklyNarrative: weeklyNarrative,
            pantryItems: pantryItems
        )
    }

    func pantrySuggestions(pantryItems: [PantryItem], patternInsights: [PatternInsight]) -> [PantrySuggestion] {
        pantrySuggestionEngine.suggest(pantryItems: pantryItems, patternInsights: patternInsights)
    }
}

enum WLAssistantLogger {
    static let analysis = Logger(subsystem: "com.aldoolivas.WellnessLens", category: "analysis")
    static let persistence = Logger(subsystem: "com.aldoolivas.WellnessLens", category: "persistence")
}

private func orderedUnique(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
}
