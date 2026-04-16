import Foundation

enum AgeRange: String, Codable, CaseIterable, Identifiable {
    case twenties = "20-29"
    case thirties = "30-39"
    case forties = "40-49"
    case fiftiesPlus = "50+"

    var id: String { rawValue }

    var title: String {
        rawValue
    }
}

enum RestaurantFrequency: String, Codable, CaseIterable, Identifiable {
    case mostlyHome
    case balanced
    case oftenOut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mostlyHome:
            "Mostly home"
        case .balanced:
            "Balanced"
        case .oftenOut:
            "Often out"
        }
    }
}

enum DailyNutritionPriority: String, Codable, CaseIterable, Identifiable {
    case energy
    case digestion
    case skin
    case hormones
    case bodyComposition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .energy:
            "Energy"
        case .digestion:
            "Digestion"
        case .skin:
            "Skin"
        case .hormones:
            "Hormones"
        case .bodyComposition:
            "Body composition"
        }
    }
}

struct ConsentFlags: Codable, Hashable {
    var aiProcessing: Bool
    var analytics: Bool
    var notifications: Bool
    var healthDataProcessing: Bool

    static let starter = ConsentFlags(
        aiProcessing: true,
        analytics: false,
        notifications: false,
        healthDataProcessing: true
    )
}

struct ConsentRecord: Codable, Hashable, Identifiable {
    var id = UUID()
    var localProfileID: String
    var policyVersion: String
    var flags: ConsentFlags
    var createdAt: Date
}

enum AnalysisInputType: String, Codable, CaseIterable {
    case barcode
    case labelPhoto = "label_photo"
    case mealPhoto = "meal_photo"
    case menuPhoto = "menu_photo"
    case manual
}

enum AnalysisEntityType: String, Codable, CaseIterable {
    case product
    case meal
    case menuItem = "menu_item"
    case supplement
}

enum AnalysisVerdict: String, Codable, CaseIterable {
    case good
    case adjust
    case avoid
    case needsMoreInfo = "needs_more_info"
}

enum SwapPriority: String, Codable, CaseIterable {
    case high
    case medium
    case low
}

struct StructuredLensScores: Codable, Hashable {
    var skin: Int
    var hormones: Int
    var gut: Int
    var energy: Int
    var bodyComp: Int

    enum CodingKeys: String, CodingKey {
        case skin
        case hormones
        case gut
        case energy
        case bodyComp = "body_comp"
    }

    init(skin: Int = 0, hormones: Int = 0, gut: Int = 0, energy: Int = 0, bodyComp: Int = 0) {
        self.skin = skin
        self.hormones = hormones
        self.gut = gut
        self.energy = energy
        self.bodyComp = bodyComp
    }

    init(lensScores: [LensScore]) {
        self.init(
            skin: lensScores.first(where: { $0.lens == .glowSkin })?.score ?? 0,
            hormones: lensScores.first(where: { $0.lens == .hormoneBalance })?.score ?? 0,
            gut: lensScores.first(where: { $0.lens == .gutComfort })?.score ?? 0,
            energy: lensScores.first(where: { $0.lens == .energyMood })?.score ?? 0,
            bodyComp: lensScores.first(where: { $0.lens == .bodyCompositionStrength })?.score ?? 0
        )
    }

    var values: [Int] {
        [skin, hormones, gut, energy, bodyComp]
    }
}

struct SwapSuggestion: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var reason: String
    var priority: SwapPriority
}

enum SafetyRiskLevel: String, Codable, CaseIterable {
    case low
    case medium
    case high
}

struct MedicalSafety: Codable, Hashable {
    var isMedicalAdvice: Bool
    var disclaimerNeeded: Bool
    var riskLevel: SafetyRiskLevel

    enum CodingKeys: String, CodingKey {
        case isMedicalAdvice = "is_medical_advice"
        case disclaimerNeeded = "disclaimer_needed"
        case riskLevel = "risk_level"
    }
}

struct PatternContext: Codable, Hashable {
    var usedHistory: Bool
    var relevantPattern: String?

    enum CodingKeys: String, CodingKey {
        case usedHistory = "used_history"
        case relevantPattern = "relevant_pattern"
    }
}

struct AnalysisEnvelope: Codable, Hashable, Identifiable {
    var id: String { analysisID }
    var analysisID: String
    var timestamp: Date
    var inputType: AnalysisInputType
    var entityType: AnalysisEntityType
    var verdict: AnalysisVerdict
    var overallScore: Int
    var lensScores: StructuredLensScores
    var whyToday: [String]
    var greenFlags: [String]
    var redFlags: [String]
    var recommendedActions: [String]
    var swapSuggestions: [SwapSuggestion]
    var followUpPrompt: String
    var confidence: Double
    var medicalSafety: MedicalSafety
    var patternContext: PatternContext

    enum CodingKeys: String, CodingKey {
        case analysisID = "analysis_id"
        case timestamp
        case inputType = "input_type"
        case entityType = "entity_type"
        case verdict
        case overallScore = "overall_score"
        case lensScores = "lens_scores"
        case whyToday = "why_today"
        case greenFlags = "green_flags"
        case redFlags = "red_flags"
        case recommendedActions = "recommended_actions"
        case swapSuggestions = "swap_suggestions"
        case followUpPrompt = "follow_up_prompt"
        case confidence
        case medicalSafety = "medical_safety"
        case patternContext = "pattern_context"
    }
}

struct NormalizedScanPayload: Codable, Hashable {
    var source: AnalysisInputType
    var entityName: String
    var brand: String?
    var productType: ProductType?
    var ingredients: [String]
    var claims: [String]
    var extractedText: String?
    var inferredTags: [String]
}

struct ScanEvent: Codable, Hashable, Identifiable {
    var id: String
    var timestamp: Date
    var localProfileID: String
    var inputType: AnalysisInputType
    var normalizedPayload: NormalizedScanPayload
    var analysis: AnalysisEnvelope
    var legacyAnalysis: ScanAnalysis
    var sourceAgents: [String]
    var latencyMs: Int

    enum CodingKeys: String, CodingKey {
        case id = "scan_id"
        case timestamp
        case localProfileID = "local_profile_id"
        case inputType = "input_type"
        case normalizedPayload = "normalized_payload"
        case analysis
        case legacyAnalysis = "legacy_analysis"
        case sourceAgents = "source_agents"
        case latencyMs = "latency_ms"
    }
}

struct CheckInEvent: Codable, Hashable, Identifiable {
    var id: String
    var timestamp: Date
    var localProfileID: String
    var linkedScanIDs: [String]
    var energy: Int
    var bloating: Int
    var mood: Int
    var cravings: Int
    var skin: Int
    var satiety: Int
    var notes: String
    var readHelpful: Bool?
    var legacyEntry: CheckInEntry

    enum CodingKeys: String, CodingKey {
        case id = "checkin_id"
        case timestamp
        case localProfileID = "local_profile_id"
        case linkedScanIDs = "linked_scan_ids"
        case energy
        case bloating
        case mood
        case cravings
        case skin
        case satiety
        case notes
        case readHelpful = "read_helpful"
        case legacyEntry = "legacy_entry"
    }
}

struct FavoriteItem: Codable, Hashable, Identifiable {
    var id: String
    var scanEventID: String
    var createdAt: Date
    var title: String
    var summary: String

    enum CodingKeys: String, CodingKey {
        case id = "favorite_id"
        case scanEventID = "scan_event_id"
        case createdAt = "created_at"
        case title
        case summary
    }
}

enum PatternSignal: String, Codable, CaseIterable, Identifiable {
    case energy = "energy"
    case digestion = "digestion"
    case routine = "routine"
    case menu = "menu"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .energy:
            "Energy rhythm"
        case .digestion:
            "Digestion rhythm"
        case .routine:
            "Routine anchor"
        case .menu:
            "Restaurant rhythm"
        }
    }
}

struct PatternInsight: Codable, Hashable, Identifiable {
    var id: String { patternID }
    var patternID: String
    var title: String
    var summary: String
    var signal: PatternSignal
    var confidence: Double
    var recommendedAction: String
    var linkedScanIDs: [String]
    var linkedCheckInIDs: [String]
    var safetyNote: String

    enum CodingKeys: String, CodingKey {
        case patternID = "pattern_id"
        case title
        case summary
        case signal
        case confidence
        case recommendedAction = "recommended_action"
        case linkedScanIDs = "linked_scan_ids"
        case linkedCheckInIDs = "linked_checkin_ids"
        case safetyNote = "safety_note"
    }
}

struct WeeklyInsightNarrative: Codable, Hashable {
    var headline: String
    var patternSummary: String
    var whatToProtect: String
    var whatToReduce: String
    var nextExperiment: String
    var confidence: Double
    var supportingPatternIDs: [String]

    enum CodingKeys: String, CodingKey {
        case headline
        case patternSummary = "pattern_summary"
        case whatToProtect = "what_to_protect"
        case whatToReduce = "what_to_reduce"
        case nextExperiment = "next_experiment"
        case confidence
        case supportingPatternIDs = "supporting_pattern_ids"
    }
}

enum PantrySourceKind: String, Codable, CaseIterable, Identifiable {
    case supportiveScan = "supportive_scan"
    case favorite
    case routine
    case menuScan = "menu_scan"
    case manualSave = "manual_save"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .supportiveScan:
            "Supportive scan"
        case .favorite:
            "Favorite"
        case .routine:
            "Routine"
        case .menuScan:
            "Menu scan"
        case .manualSave:
            "Saved now"
        }
    }
}

struct PantryItem: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var summary: String
    var relatedProductID: String?
    var sourceKind: PantrySourceKind
    var sourceScanID: String?
    var createdAt: Date
    var lastUpdatedAt: Date
    var archivedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "pantry_item_id"
        case title
        case summary
        case relatedProductID = "related_product_id"
        case sourceKind = "source_kind"
        case sourceScanID = "source_scan_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case archivedAt = "archived_at"
    }

    var isArchived: Bool {
        archivedAt != nil
    }

    var dedupeKey: String {
        relatedProductID?.lowercased() ?? title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct PantrySuggestion: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var summary: String
    var reason: String
    var supportingPantryItemIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id = "suggestion_id"
        case title
        case summary
        case reason
        case supportingPantryItemIDs = "supporting_pantry_item_ids"
    }
}

enum WellnessEntitlement: String, Codable, CaseIterable, Identifiable {
    case patternAgent = "pattern_agent"
    case weeklyInsightV2 = "weekly_insight_v2"
    case menuScanner = "menu_scanner"
    case pantryMVP = "pantry_mvp"
    case pantrySuggestions = "pantry_suggestions"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .patternAgent:
            "Pattern Agent"
        case .weeklyInsightV2:
            "Weekly Insight v2"
        case .menuScanner:
            "Menu Scanner"
        case .pantryMVP:
            "Pantry"
        case .pantrySuggestions:
            "Pantry Suggestions"
        }
    }

    var targetTier: SubscriptionStatus {
        switch self {
        case .patternAgent, .weeklyInsightV2, .menuScanner:
            .plus
        case .pantryMVP, .pantrySuggestions:
            .pro
        }
    }
}

enum PaywallSurface: String, Codable, CaseIterable, Identifiable {
    case patternDetail = "pattern_detail"
    case weeklyNarrative = "weekly_narrative"
    case menuScanner = "menu_scanner"
    case pantry = "pantry"
    case pantrySuggestions = "pantry_suggestions"

    var id: String { rawValue }
}

enum BillingMode: String, Codable, CaseIterable {
    case demo
    case storeKit = "storekit"
}

struct EntitlementSnapshot: Codable, Hashable {
    var tier: SubscriptionStatus
    var activeEntitlements: [WellnessEntitlement]
    var billingMode: BillingMode
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case tier
        case activeEntitlements = "active_entitlements"
        case billingMode = "billing_mode"
        case updatedAt = "updated_at"
    }

    func includes(_ entitlement: WellnessEntitlement) -> Bool {
        activeEntitlements.contains(entitlement)
    }
}

struct PaywallContext: Codable, Hashable, Identifiable {
    var id = UUID()
    var feature: WellnessEntitlement
    var surface: PaywallSurface
    var targetTier: SubscriptionStatus
    var title: String
    var message: String
    var previewLines: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case feature
        case surface
        case targetTier = "target_tier"
        case title
        case message
        case previewLines = "preview_lines"
    }
}

struct AccessPolicy {
    func snapshot(
        subscriptionStatus: SubscriptionStatus,
        billingMode: BillingMode,
        now: Date = .now
    ) -> EntitlementSnapshot {
        let unlocked: [WellnessEntitlement] = WellnessEntitlement.allCases.filter {
            subscriptionStatus.rank >= $0.targetTier.rank
        }

        return EntitlementSnapshot(
            tier: subscriptionStatus,
            activeEntitlements: unlocked,
            billingMode: billingMode,
            updatedAt: now
        )
    }

    func isUnlocked(_ entitlement: WellnessEntitlement, snapshot: EntitlementSnapshot) -> Bool {
        snapshot.includes(entitlement)
    }

    func paywallContext(
        for entitlement: WellnessEntitlement,
        surface: PaywallSurface,
        previewLines: [String],
        snapshot: EntitlementSnapshot
    ) -> PaywallContext {
        let tier = entitlement.targetTier
        let message: String = {
            switch entitlement {
            case .patternAgent:
                "See the repeat patterns behind softer scans and body-signal days before you lock in a routine."
            case .weeklyInsightV2:
                "Turn raw scans into one narrative that tells you what to protect, what to soften, and what to test next."
            case .menuScanner:
                "Use the same wellness read on restaurant decisions before the order becomes the day."
            case .pantryMVP:
                "Keep your strongest repeat choices in one place so better defaults stay easy."
            case .pantrySuggestions:
                "Get sharper pantry suggestions that connect your saved anchors to your current pattern."
            }
        }()

        let preview = previewLines.isEmpty ? [message] : previewLines

        return PaywallContext(
            feature: entitlement,
            surface: surface,
            targetTier: tier,
            title: tier == .pro ? "Unlock Pro" : "Unlock Plus",
            message: snapshot.billingMode == .storeKit
                ? message
                : "\(message) Demo mode still lets you simulate the upgrade path safely.",
            previewLines: preview
        )
    }
}

enum PantryPresentationCopy {
    static func supportingMessage(isUnlocked: Bool, hasSuggestion: Bool) -> String? {
        guard !hasSuggestion else { return nil }
        if isUnlocked {
            return "Suggestions will appear after a few more supportive repeat choices."
        }

        return "Preview only. Pantry actions and suggestions unlock with Pro."
    }
}

enum DailyBriefActionKind: String, Codable, CaseIterable {
    case scanBreakfast
    case scanSnack
    case mealSnapshot
    case updateFeedback
    case openHistory
}

struct DailyBriefAction: Codable, Hashable {
    var kind: DailyBriefActionKind
    var title: String
    var subtitle: String
}

struct DailyBrief: Codable, Hashable {
    var headline: String
    var riskHeadline: String
    var nutritionPriority: String
    var cta: DailyBriefAction
    var notificationCopy: String
}

extension ScanSource {
    var analysisInputType: AnalysisInputType {
        switch self {
        case .liveBarcode, .manualBarcode:
            .barcode
        case .labelPhoto:
            .labelPhoto
        case .mealPhoto:
            .mealPhoto
        case .menuPhoto:
            .menuPhoto
        case .manualLabel:
            .manual
        }
    }
}

extension ProductType {
    var analysisEntityType: AnalysisEntityType {
        switch self {
        case .supplement:
            .supplement
        case .food:
            .product
        case .skincare, .haircare, .personalCare:
            .product
        }
    }
}

extension ScanAnalysis {
    func makeEnvelope(
        input: ScanInput,
        recentScans: [ScanEvent],
        recentCheckIns: [CheckInEvent]
    ) -> AnalysisEnvelope {
        let structuredLensScores = StructuredLensScores(lensScores: lensScores)
        let overallScore = Int(Double(structuredLensScores.values.reduce(0, +)) / Double(max(structuredLensScores.values.count, 1)))
        let cautionReasons = topReasons.filter { $0.impact == .caution }.map(\.title)
        let positiveReasons = topReasons.filter { $0.impact == .positive }.map(\.title)
        let redFlags = Array((warnings + cautionReasons).uniqued().prefix(4))
        let greenFlags = Array((positiveReasons + resolvedProduct.claims).uniqued().prefix(4))
        let recommendedActions = makeRecommendedActions(overallScore: overallScore)
        let patternContext = PatternContext(
            usedHistory: !recentScans.isEmpty || !recentCheckIns.isEmpty,
            relevantPattern: AnalysisEnvelope.relevantPattern(
                overallScore: overallScore,
                recentScans: recentScans,
                recentCheckIns: recentCheckIns
            )
        )
        let entityType: AnalysisEntityType = {
            switch source {
            case .mealPhoto:
                return .meal
            case .menuPhoto:
                return .menuItem
            default:
                return productType.analysisEntityType
            }
        }()

        return AnalysisEnvelope(
            analysisID: UUID().uuidString,
            timestamp: createdAt,
            inputType: source.analysisInputType,
            entityType: entityType,
            verdict: AnalysisEnvelope.verdict(for: overallScore, confidence: confidence),
            overallScore: overallScore,
            lensScores: structuredLensScores,
            whyToday: AnalysisEnvelope.whyToday(
                summary: overallSummary,
                recentCheckIns: recentCheckIns,
                source: source
            ),
            greenFlags: greenFlags,
            redFlags: redFlags,
            recommendedActions: recommendedActions,
            swapSuggestions: alternatives.map { $0.swapSuggestion },
            followUpPrompt: AnalysisEnvelope.followUpPrompt(for: source),
            confidence: confidence.numericValue,
            medicalSafety: MedicalSafety(
                isMedicalAdvice: false,
                disclaimerNeeded: true,
                riskLevel: redFlags.isEmpty && confidence != .low ? .low : .medium
            ),
            patternContext: patternContext
        )
    }

    private func makeRecommendedActions(overallScore: Int) -> [String] {
        if overallScore >= 78 {
            return [
                "Keep this as a likely repeat option today.",
                "Save it if this is a pattern you want to reuse.",
                AnalysisEnvelope.followUpPrompt(for: source)
            ]
        }

        if overallScore >= 58 {
            return [
                "Use a small adjustment before repeating this choice.",
                alternatives.first.map { "Try \($0.productName) as a softer swap." } ?? "Pair it with more protein or fiber for a steadier read.",
                AnalysisEnvelope.followUpPrompt(for: source)
            ]
        }

        return [
            "Treat this as a lower-fit option for today.",
            alternatives.first.map { "Prefer \($0.productName) if available." } ?? "Look for a gentler alternative in the same category.",
            AnalysisEnvelope.followUpPrompt(for: source)
        ]
    }
}

extension AlternativeSuggestion {
    var swapSuggestion: SwapSuggestion {
        let priority: SwapPriority
        switch improvedLenses.count {
        case 3...:
            priority = .high
        case 2:
            priority = .medium
        default:
            priority = .low
        }

        return SwapSuggestion(
            title: productName,
            reason: whyBetter,
            priority: priority
        )
    }
}

extension ConfidenceLevel {
    var numericValue: Double {
        switch self {
        case .high:
            0.92
        case .medium:
            0.71
        case .low:
            0.43
        }
    }
}

extension SubscriptionStatus {
    var rank: Int {
        switch self {
        case .free:
            0
        case .plus:
            1
        case .pro:
            2
        }
    }
}

extension CheckInEntry {
    func makeEvent(localProfileID: String, linkedScanIDs: [String], readHelpful: Bool?, satiety: Int) -> CheckInEvent {
        CheckInEvent(
            id: UUID().uuidString,
            timestamp: createdAt,
            localProfileID: localProfileID,
            linkedScanIDs: linkedScanIDs,
            energy: energy,
            bloating: 6 - bloatingRelief,
            mood: mood,
            cravings: 6 - cravingControl,
            skin: skin,
            satiety: satiety,
            notes: note,
            readHelpful: readHelpful,
            legacyEntry: self
        )
    }
}

private extension AnalysisEnvelope {
    static func verdict(for overallScore: Int, confidence: ConfidenceLevel) -> AnalysisVerdict {
        if confidence == .low && overallScore < 55 {
            return .needsMoreInfo
        }
        switch overallScore {
        case 78...:
            return .good
        case 58...77:
            return .adjust
        default:
            return .avoid
        }
    }

    static func whyToday(summary: String, recentCheckIns: [CheckInEvent], source: ScanSource) -> [String] {
        var items = [summary]
        if let latestCheckIn = recentCheckIns.first {
            if latestCheckIn.energy <= 2 {
                items.append("Recent feedback suggests energy needs steadier choices today.")
            }
            if latestCheckIn.bloating >= 4 {
                items.append("Recent digestion feedback suggests using a lighter hand today.")
            }
        }
        if source == .mealPhoto {
            items.append("Meal Snapshot reads are meant to guide the next choice, not replace your judgment.")
        }
        if source == .menuPhoto {
            items.append("Menu Scanner reads are directional and work best when you compare two realistic options, not the whole menu.")
        }
        return Array(items.prefix(3))
    }

    static func followUpPrompt(for source: ScanSource) -> String {
        switch source {
        case .mealPhoto:
            "How did this meal feel for your energy, digestion, and satiety a few hours later?"
        case .menuPhoto:
            "Did this menu choice feel aligned with what you needed today?"
        default:
            "Did this read match how this choice actually felt for you?"
        }
    }

    static func relevantPattern(
        overallScore: Int,
        recentScans: [ScanEvent],
        recentCheckIns: [CheckInEvent]
    ) -> String? {
        if let latestCheckIn = recentCheckIns.first, latestCheckIn.energy <= 2, overallScore < 60 {
            return "Lower-fit choices tend to line up with softer energy days."
        }
        if recentScans.count >= 2 {
            let recentScores = recentScans.prefix(3).map(\.analysis.overallScore)
            let recentAverage = Int((Double(recentScores.reduce(0, +)) / Double(max(recentScores.count, 1))).rounded())
            if overallScore >= 78 && recentAverage < 70 {
                return "This looks stronger than your recent average decisions."
            }
        }
        return nil
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
