import Foundation

enum UserLifecycleState: String, Codable, CaseIterable, Identifiable {
    case unonboarded
    case calibrating
    case active
    case drifting
    case reengagement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unonboarded:
            "Start"
        case .calibrating:
            "Calibrating"
        case .active:
            "Active"
        case .drifting:
            "Needs a reset"
        case .reengagement:
            "Come back in"
        }
    }
}

enum GuidanceStyle: String, Codable, CaseIterable, Identifiable {
    case calmAndDirect
    case warmAndEncouraging
    case strategicAndPrecise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calmAndDirect:
            "Calm and direct"
        case .warmAndEncouraging:
            "Warm and encouraging"
        case .strategicAndPrecise:
            "Strategic and precise"
        }
    }

    var strategistVoice: String {
        switch self {
        case .calmAndDirect:
            "clear, calm, and lightly editorial"
        case .warmAndEncouraging:
            "supportive, warm, and gently motivating"
        case .strategicAndPrecise:
            "sharp, structured, and highly actionable"
        }
    }
}

enum UserFriction: String, Codable, CaseIterable, Identifiable {
    case energyCrash
    case bloating
    case cravings
    case supplementConfusion
    case inconsistentMeals
    case reactiveSkin
    case stressSnacking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .energyCrash:
            "Energy crashes"
        case .bloating:
            "Bloating"
        case .cravings:
            "Cravings"
        case .supplementConfusion:
            "Supplement confusion"
        case .inconsistentMeals:
            "Inconsistent meals"
        case .reactiveSkin:
            "Reactive skin"
        case .stressSnacking:
            "Stress snacking"
        }
    }

    var strategistSummary: String {
        switch self {
        case .energyCrash:
            "protect steadier energy through the day"
        case .bloating:
            "soften digestion friction before it snowballs"
        case .cravings:
            "reduce the rebound loop that drives cravings"
        case .supplementConfusion:
            "make the supplement stack feel less noisy"
        case .inconsistentMeals:
            "bring more consistency to meals and anchors"
        case .reactiveSkin:
            "reduce the product choices that irritate skin"
        case .stressSnacking:
            "interrupt the stress-to-snack reflex earlier"
        }
    }
}

enum EatingRhythm: String, Codable, CaseIterable, Identifiable {
    case structured
    case flexible
    case onTheGo
    case eveningHeavy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .structured:
            "Structured meals"
        case .flexible:
            "Flexible routine"
        case .onTheGo:
            "On the go"
        case .eveningHeavy:
            "Evening-heavy"
        }
    }
}

enum SupplementRoutineStyle: String, Codable, CaseIterable, Identifiable {
    case none
    case simple
    case stacked
    case inconsistent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            "No routine"
        case .simple:
            "Simple routine"
        case .stacked:
            "Layered stack"
        case .inconsistent:
            "Inconsistent"
        }
    }
}

enum GoalStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case holding
    case won

    var id: String { rawValue }
}

enum RecommendationKind: String, Codable, CaseIterable, Identifiable {
    case scanStaple
    case checkInNow
    case swapProduct
    case askStrategist
    case repeatProduct
    case tidyRoutine

    var id: String { rawValue }
}

enum RecommendationFeedback: String, Codable, CaseIterable, Identifiable {
    case helpful
    case ignored
    case notRelevant

    var id: String { rawValue }
}

enum ScanDecisionKind: String, Codable, CaseIterable, Identifiable {
    case saveToRoutine
    case avoidForNow
    case swapInstead
    case askStrategist
    case trackAgain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveToRoutine:
            "Save to routine"
        case .avoidForNow:
            "Avoid for now"
        case .swapInstead:
            "Pick a swap"
        case .askStrategist:
            "Ask strategist"
        case .trackAgain:
            "Track this again"
        }
    }

    var keepsLoopOpen: Bool {
        switch self {
        case .saveToRoutine, .swapInstead, .trackAgain:
            true
        case .avoidForNow, .askStrategist:
            false
        }
    }
}

enum MemoryItemKind: String, Codable, CaseIterable, Identifiable {
    case staple
    case avoid
    case strategistTakeaway
    case checkInPattern
    case scanDecision
    case experimentWin
    case experimentCaution
    case routineNote

    var id: String { rawValue }
}

enum ExperimentStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case paused
    case learned

    var id: String { rawValue }
}

enum StrategistEntryPoint: String, Codable, CaseIterable, Identifiable {
    case home
    case scan
    case checkIn
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            "Daily strategist"
        case .scan:
            "Scan strategist"
        case .checkIn:
            "Body signal strategist"
        case .profile:
            "Profile strategist"
        }
    }
}

enum ConversationSpeaker: String, Codable, CaseIterable, Identifiable {
    case user
    case strategist

    var id: String { rawValue }
}

enum SignalTone: String, Codable, CaseIterable, Identifiable {
    case supportive
    case caution
    case neutral

    var id: String { rawValue }
}

struct UserProfile: Codable, Hashable {
    var userContext: UserContext
    var frictions: [UserFriction]
    var guidanceStyle: GuidanceStyle
    var eatingRhythm: EatingRhythm
    var supplementStyle: SupplementRoutineStyle
    var memoryEnabled: Bool
    var ageRange: AgeRange
    var restaurantFrequency: RestaurantFrequency
    var nutritionPriorities: [DailyNutritionPriority]
    var consentFlags: ConsentFlags
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userContext
        case frictions
        case guidanceStyle
        case eatingRhythm
        case supplementStyle
        case memoryEnabled
        case ageRange
        case restaurantFrequency
        case nutritionPriorities
        case consentFlags
        case createdAt
    }

    static let starter = UserProfile(
        userContext: .starter,
        frictions: [.energyCrash, .bloating],
        guidanceStyle: .calmAndDirect,
        eatingRhythm: .flexible,
        supplementStyle: .simple,
        memoryEnabled: true,
        ageRange: .thirties,
        restaurantFrequency: .balanced,
        nutritionPriorities: [.energy, .digestion, .skin],
        consentFlags: .starter,
        createdAt: .now
    )

    static func migrated(from context: UserContext, createdAt: Date = .now) -> UserProfile {
        let frictions: [UserFriction]
        if context.goals.contains(.steadyEnergy) {
            frictions = [.energyCrash, .cravings]
        } else if context.goals.contains(.gutCalm) || context.goals.contains(.deBloat) {
            frictions = [.bloating, .inconsistentMeals]
        } else {
            frictions = [.supplementConfusion]
        }

        return UserProfile(
            userContext: context,
            frictions: frictions,
            guidanceStyle: .calmAndDirect,
            eatingRhythm: .flexible,
            supplementStyle: .simple,
            memoryEnabled: true,
            ageRange: .thirties,
            restaurantFrequency: .balanced,
            nutritionPriorities: defaultPriorities(for: context.goals),
            consentFlags: .starter,
            createdAt: createdAt
        )
    }

    init(
        userContext: UserContext,
        frictions: [UserFriction],
        guidanceStyle: GuidanceStyle,
        eatingRhythm: EatingRhythm,
        supplementStyle: SupplementRoutineStyle,
        memoryEnabled: Bool,
        ageRange: AgeRange,
        restaurantFrequency: RestaurantFrequency,
        nutritionPriorities: [DailyNutritionPriority],
        consentFlags: ConsentFlags,
        createdAt: Date
    ) {
        self.userContext = userContext
        self.frictions = frictions
        self.guidanceStyle = guidanceStyle
        self.eatingRhythm = eatingRhythm
        self.supplementStyle = supplementStyle
        self.memoryEnabled = memoryEnabled
        self.ageRange = ageRange
        self.restaurantFrequency = restaurantFrequency
        self.nutritionPriorities = nutritionPriorities
        self.consentFlags = consentFlags
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userContext = try container.decode(UserContext.self, forKey: .userContext)
        frictions = try container.decode([UserFriction].self, forKey: .frictions)
        guidanceStyle = try container.decode(GuidanceStyle.self, forKey: .guidanceStyle)
        eatingRhythm = try container.decode(EatingRhythm.self, forKey: .eatingRhythm)
        supplementStyle = try container.decode(SupplementRoutineStyle.self, forKey: .supplementStyle)
        memoryEnabled = try container.decode(Bool.self, forKey: .memoryEnabled)
        ageRange = try container.decodeIfPresent(AgeRange.self, forKey: .ageRange) ?? .thirties
        restaurantFrequency = try container.decodeIfPresent(RestaurantFrequency.self, forKey: .restaurantFrequency) ?? .balanced
        nutritionPriorities = try container.decodeIfPresent([DailyNutritionPriority].self, forKey: .nutritionPriorities) ?? Self.defaultPriorities(for: userContext.goals)
        consentFlags = try container.decodeIfPresent(ConsentFlags.self, forKey: .consentFlags) ?? .starter
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userContext, forKey: .userContext)
        try container.encode(frictions, forKey: .frictions)
        try container.encode(guidanceStyle, forKey: .guidanceStyle)
        try container.encode(eatingRhythm, forKey: .eatingRhythm)
        try container.encode(supplementStyle, forKey: .supplementStyle)
        try container.encode(memoryEnabled, forKey: .memoryEnabled)
        try container.encode(ageRange, forKey: .ageRange)
        try container.encode(restaurantFrequency, forKey: .restaurantFrequency)
        try container.encode(nutritionPriorities, forKey: .nutritionPriorities)
        try container.encode(consentFlags, forKey: .consentFlags)
        try container.encode(createdAt, forKey: .createdAt)
    }

    private static func defaultPriorities(for goals: [UserGoal]) -> [DailyNutritionPriority] {
        var priorities: [DailyNutritionPriority] = []

        for goal in goals {
            switch goal {
            case .steadyEnergy:
                priorities.append(.energy)
            case .gutCalm, .deBloat:
                priorities.append(.digestion)
            case .clearSkin:
                priorities.append(.skin)
            case .hormoneSupport:
                priorities.append(.hormones)
            case .leanStrength:
                priorities.append(.bodyComposition)
            }
        }

        if priorities.isEmpty {
            priorities = [.energy, .digestion, .skin]
        }

        var seen = Set<DailyNutritionPriority>()
        return priorities.filter { seen.insert($0).inserted }
    }
}

struct GoalMilestone: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var detail: String
    var progressHint: String
}

struct ActiveGoal: Codable, Hashable, Identifiable {
    var id = UUID()
    var goal: UserGoal
    var title: String
    var summary: String
    var status: GoalStatus
    var focusMetric: String
    var currentSignalSummary: String
    var milestone: GoalMilestone
}

struct FirstWeekPlanStep: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var detail: String
    var isComplete: Bool = false
}

struct FirstWeekPlan: Codable, Hashable {
    var title: String
    var summary: String
    var steps: [FirstWeekPlanStep]
}

struct Recommendation: Codable, Hashable, Identifiable {
    var id: String
    var kind: RecommendationKind
    var title: String
    var summary: String
    var cta: String
    var relatedProductID: String?
    var relatedGoal: UserGoal?
}

struct RoutineItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var productID: String
    var productName: String
    var cadenceSummary: String
    var note: String
    var createdAt: Date
}

struct ScanDecision: Codable, Hashable, Identifiable {
    var id = UUID()
    var createdAt: Date
    var productID: String
    var productName: String
    var kind: ScanDecisionKind
    var note: String
    var relatedGoal: UserGoal?
    var resolvedAt: Date?
}

struct CheckInSignal: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var summary: String
    var tone: SignalTone
}

struct MemoryItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var kind: MemoryItemKind
    var title: String
    var summary: String
    var relatedProductID: String?
    var relatedProductName: String?
    var createdAt: Date
    var lastReferencedAt: Date
}

struct Experiment: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var hypothesis: String
    var status: ExperimentStatus
    var relatedProductID: String? = nil
    var relatedGoal: UserGoal?
    var createdAt: Date
    var lastUpdatedAt: Date
}

struct ConversationMessage: Codable, Hashable, Identifiable {
    var id = UUID()
    var speaker: ConversationSpeaker
    var text: String
    var createdAt: Date
    var citedMemoryIDs: [UUID] = []
    var coachPayload: ConversationMessageCoachPayload? = nil

    var coachHistoryText: String {
        guard let followUpQuestion = coachPayload?.followUpQuestion, !followUpQuestion.isEmpty else {
            return text
        }

        return "\(text)\n\n\(followUpQuestion)"
    }
}

struct ConversationMessageCoachPayload: Codable, Hashable {
    var replyID: String
    var referencedVerdictID: String?
    var referencedVerdictSummary: String?
    var referencedPatterns: [String]
    var suggestedActions: [CoachSuggestedAction]
    var followUpQuestion: String?
    var safetyFlags: [CoachSafetyFlag]
    var evidenceTier: CoachEvidenceTier
    var disclaimer: String
    var voiceTags: [CoachVoiceTag]
    var voiceDirective: String?
    var spokenVersion: String?

    init(reply: CoachReply) {
        replyID = reply.replyId
        referencedVerdictID = reply.referencedVerdictId
        referencedVerdictSummary = reply.referencedVerdictSummary
        referencedPatterns = reply.referencedPatterns
        suggestedActions = reply.suggestedActions
        followUpQuestion = reply.followUpQuestion
        safetyFlags = reply.safetyFlags
        evidenceTier = reply.evidenceTier
        disclaimer = reply.disclaimer
        voiceTags = reply.voiceTags ?? []
        voiceDirective = reply.voiceDirective
        spokenVersion = reply.spokenVersion
    }

    var hasVoiceMetadata: Bool {
        spokenVersion != nil || !voiceTags.isEmpty || voiceDirective != nil
    }

    var hasSafetyNotice: Bool {
        !safetyFlags.isEmpty
    }
}

struct ConversationThread: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var entryPoint: StrategistEntryPoint
    var createdAt: Date
    var updatedAt: Date
    var messages: [ConversationMessage]
}

struct ConversationTurnContext: Codable, Hashable {
    var activeGoalTitles: [String]
    var recentSignals: [String]
    var recentProducts: [String]
    var openLoopSummaries: [String]
    var memorySummaries: [String]
    var latestDecisionSummary: String?
    var latestReadSummary: String?
    var latestPatternTitle: String?
    var latestPatternSummary: String?
    var weeklyNarrativeHeadline: String?
    var weeklyNarrativeSummary: String?
    var weeklyNextExperiment: String?
}

struct TodayFocus: Codable, Hashable {
    var title: String
    var summary: String
}

struct OpenLoop: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var summary: String
}

struct StrategistNote: Codable, Hashable {
    var title: String
    var summary: String
}

struct RecentWin: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var summary: String
}

struct DailyHomePayload: Codable, Hashable {
    var state: UserLifecycleState
    var todayFocus: TodayFocus
    var bodySignal: CheckInSignal
    var nextAction: Recommendation
    var recommendedSwap: AlternativeSuggestion?
    var openLoops: [OpenLoop]
    var strategistNote: StrategistNote
    var recentWins: [RecentWin]
}

enum HomeSurfaceModule: String, Codable, CaseIterable, Hashable, Identifiable {
    case firstWeekPlan
    case dailyBrief
    case activeGoals
    case recommendedSwap
    case openLoops
    case recentWins
    case strategistNote
    case routineMemory
    case pantry
    case sampleReads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstWeekPlan:
            "First week plan"
        case .dailyBrief:
            "Daily brief"
        case .activeGoals:
            "Goals"
        case .recommendedSwap:
            "Recommended swap"
        case .openLoops:
            "Open loops"
        case .recentWins:
            "Recent wins"
        case .strategistNote:
            "Strategist note"
        case .routineMemory:
            "Routine memory"
        case .pantry:
            "Pantry"
        case .sampleReads:
            "Sample reads"
        }
    }
}

struct HomeSurfacePlan: Hashable {
    var primaryModule: HomeSurfaceModule?
    var secondaryModules: [HomeSurfaceModule]
}

struct HomeSurfacePlanner {
    func plan(
        payload: DailyHomePayload,
        hasFirstWeekPlan: Bool,
        hasDailyBrief: Bool,
        hasGoals: Bool,
        hasRoutines: Bool,
        hasPantry: Bool,
        hasSampleReads: Bool
    ) -> HomeSurfacePlan {
        let primaryModule: HomeSurfaceModule? = {
            if payload.state == .calibrating, hasFirstWeekPlan {
                return .firstWeekPlan
            }
            if payload.recommendedSwap != nil {
                return .recommendedSwap
            }
            if hasDailyBrief {
                return .dailyBrief
            }
            if hasGoals {
                return .activeGoals
            }
            return .strategistNote
        }()

        let orderedModules: [HomeSurfaceModule] = [
            .dailyBrief,
            .activeGoals,
            .recommendedSwap,
            .openLoops,
            .recentWins,
            .strategistNote,
            .routineMemory,
            .pantry,
            .sampleReads
        ]

        let availableModules = Set(orderedModules.filter { module in
            switch module {
            case .firstWeekPlan:
                return hasFirstWeekPlan
            case .dailyBrief:
                return hasDailyBrief
            case .activeGoals:
                return hasGoals
            case .recommendedSwap:
                return payload.recommendedSwap != nil
            case .openLoops:
                return !payload.openLoops.isEmpty
            case .recentWins:
                return !payload.recentWins.isEmpty
            case .strategistNote:
                return !payload.strategistNote.summary.isEmpty
            case .routineMemory:
                return hasRoutines
            case .pantry:
                return hasPantry
            case .sampleReads:
                return hasSampleReads
            }
        })

        let secondaryModules = orderedModules.filter { module in
            availableModules.contains(module) && module != primaryModule
        }

        return HomeSurfacePlan(
            primaryModule: primaryModule,
            secondaryModules: secondaryModules
        )
    }
}

struct DailyHomeSurfaceAvailability: Codable, Hashable {
    var hasFirstWeekPlan: Bool
    var hasDailyBrief: Bool
    var hasGoals: Bool
    var hasRoutines: Bool
    var hasPantry: Bool
    var hasSampleReads: Bool
    var hasUserActivity: Bool
}

enum DailyHomeHeroEmphasis: String, Codable, Hashable {
    case onboarding
    case protectMomentum
    case rebuildMomentum
    case reengage
}

enum HomeModuleSuppressionReason: String, Codable, Hashable {
    case redundantNarrative
    case redundantMemory
    case demoOnly
}

struct SuppressedHomeModule: Codable, Hashable {
    var module: HomeSurfaceModule
    var reason: HomeModuleSuppressionReason
}

struct DailyHomeHeroV2: Codable, Hashable {
    var emphasis: DailyHomeHeroEmphasis
    var whyNow: String
}

struct DailyHomePayloadV2: Codable, Hashable {
    var schemaVersion = 2
    var hero: DailyHomeHeroV2
    var primaryModule: HomeSurfaceModule?
    var secondaryModules: [HomeSurfaceModule]
    var deferredModules: [HomeSurfaceModule]
    var suppressedModules: [SuppressedHomeModule]
    var ctaPriority: RecommendationKind

    static func legacy(
        payload: DailyHomePayload,
        plan: HomeSurfacePlan
    ) -> DailyHomePayloadV2 {
        DailyHomePayloadV2(
            hero: DailyHomeHeroV2(
                emphasis: .protectMomentum,
                whyNow: "Legacy Home keeps supporting context visible without the tighter v2 curation rules."
            ),
            primaryModule: plan.primaryModule,
            secondaryModules: plan.secondaryModules,
            deferredModules: [],
            suppressedModules: [],
            ctaPriority: payload.nextAction.kind
        )
    }
}

struct DailyHomePayloadV2Builder {
    private let orderedModules: [HomeSurfaceModule] = [
        .dailyBrief,
        .activeGoals,
        .recommendedSwap,
        .openLoops,
        .recentWins,
        .strategistNote,
        .routineMemory,
        .pantry,
        .sampleReads
    ]

    private let maxSecondaryModules = 3

    func build(
        payload: DailyHomePayload,
        availability: DailyHomeSurfaceAvailability
    ) -> DailyHomePayloadV2 {
        let primaryModule = primaryModule(
            payload: payload,
            availability: availability
        )
        let availableModules = orderedModules.filter {
            isAvailable($0, payload: payload, availability: availability)
        }

        var suppressionLookup: [HomeSurfaceModule: HomeModuleSuppressionReason] = [:]

        func suppress(_ module: HomeSurfaceModule, reason: HomeModuleSuppressionReason) {
            guard availableModules.contains(module), module != primaryModule else { return }
            suppressionLookup[module] = reason
        }

        if availability.hasSampleReads, availability.hasUserActivity || payload.state != .calibrating {
            suppress(.sampleReads, reason: .demoOnly)
        }

        if availability.hasPantry, availability.hasRoutines {
            suppress(.routineMemory, reason: .redundantMemory)
        }

        if availability.hasDailyBrief || primaryModule == .firstWeekPlan || primaryModule == .recommendedSwap {
            suppress(.strategistNote, reason: .redundantNarrative)
        }

        let candidateModules = orderedModules.filter { module in
            availableModules.contains(module) &&
                module != primaryModule &&
                suppressionLookup[module] == nil
        }

        let secondaryModules = Array(candidateModules.prefix(maxSecondaryModules))
        let deferredModules = Array(candidateModules.dropFirst(maxSecondaryModules))
        let suppressedModules: [SuppressedHomeModule] = orderedModules.compactMap { module -> SuppressedHomeModule? in
            guard let reason = suppressionLookup[module] else { return nil }
            return SuppressedHomeModule(module: module, reason: reason)
        }

        return DailyHomePayloadV2(
            hero: DailyHomeHeroV2(
                emphasis: heroEmphasis(for: payload.state),
                whyNow: whyNow(
                    payload: payload,
                    primaryModule: primaryModule,
                    secondaryModules: secondaryModules,
                    deferredModules: deferredModules,
                    suppressedModules: suppressedModules
                )
            ),
            primaryModule: primaryModule,
            secondaryModules: secondaryModules,
            deferredModules: deferredModules,
            suppressedModules: suppressedModules,
            ctaPriority: payload.nextAction.kind
        )
    }

    private func primaryModule(
        payload: DailyHomePayload,
        availability: DailyHomeSurfaceAvailability
    ) -> HomeSurfaceModule? {
        if payload.state == .calibrating, availability.hasFirstWeekPlan {
            return .firstWeekPlan
        }
        if payload.recommendedSwap != nil {
            return .recommendedSwap
        }
        if availability.hasDailyBrief {
            return .dailyBrief
        }
        if availability.hasGoals {
            return .activeGoals
        }
        return !payload.strategistNote.summary.isEmpty ? .strategistNote : nil
    }

    private func isAvailable(
        _ module: HomeSurfaceModule,
        payload: DailyHomePayload,
        availability: DailyHomeSurfaceAvailability
    ) -> Bool {
        switch module {
        case .firstWeekPlan:
            availability.hasFirstWeekPlan
        case .dailyBrief:
            availability.hasDailyBrief
        case .activeGoals:
            availability.hasGoals
        case .recommendedSwap:
            payload.recommendedSwap != nil
        case .openLoops:
            !payload.openLoops.isEmpty
        case .recentWins:
            !payload.recentWins.isEmpty
        case .strategistNote:
            !payload.strategistNote.summary.isEmpty
        case .routineMemory:
            availability.hasRoutines
        case .pantry:
            availability.hasPantry
        case .sampleReads:
            availability.hasSampleReads
        }
    }

    private func heroEmphasis(for state: UserLifecycleState) -> DailyHomeHeroEmphasis {
        switch state {
        case .unonboarded, .calibrating:
            .onboarding
        case .active:
            .protectMomentum
        case .drifting:
            .rebuildMomentum
        case .reengagement:
            .reengage
        }
    }

    private func whyNow(
        payload: DailyHomePayload,
        primaryModule: HomeSurfaceModule?,
        secondaryModules: [HomeSurfaceModule],
        deferredModules: [HomeSurfaceModule],
        suppressedModules: [SuppressedHomeModule]
    ) -> String {
        let deferredCount = deferredModules.count
        let narrativeWasTrimmed = suppressedModules.contains {
            $0.reason == .redundantNarrative
        }

        switch primaryModule {
        case .firstWeekPlan:
            if narrativeWasTrimmed {
                return "Home is holding the first-week calibration plan above the fold and trimming duplicate coaching."
            }
            return "Home is leading with the calibration plan so the first decision stays obvious."
        case .recommendedSwap:
            return "A softer swap is already on the table, so Home keeps only the context that helps you act on it."
        case .dailyBrief:
            return deferredCount > 0
                ? "No single swap is dominating today, so Home leads with the brief and defers lower-priority modules."
                : "No single swap is dominating today, so Home leads with the brief and keeps the rest lightweight."
        case .activeGoals:
            return "Home is anchoring to your active goal first so the supporting context does not compete with it."
        case .strategistNote:
            return secondaryModules.isEmpty
                ? "The strategist note is carrying the story today because the rest of the signal is still light."
                : "The strategist note is carrying the story today, with only a few supporting modules nearby."
        case nil:
            return payload.todayFocus.summary
        case .openLoops, .recentWins, .routineMemory, .pantry, .sampleReads:
            return payload.todayFocus.summary
        }
    }
}

enum HistoryTimelineKind: String, Codable, CaseIterable, Identifiable {
    case scan
    case decision
    case checkIn
    case memory
    case conversation

    var id: String { rawValue }
}

struct HistoryTimelineEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var kind: HistoryTimelineKind
    var title: String
    var summary: String
    var createdAt: Date
}

struct StrategistBootstrap {
    var profile: UserProfile
    var activeGoals: [ActiveGoal]
    var firstWeekPlan: FirstWeekPlan
    var seededMemory: [MemoryItem]
    var initialThread: ConversationThread
}

struct OnboardingPlanner {
    func build(profile: UserProfile) -> StrategistBootstrap {
        let activeGoals = Array(profile.userContext.goals.prefix(3)).map { goal in
            ActiveGoal(
                goal: goal,
                title: goal.title,
                summary: goalSummary(for: goal, profile: profile),
                status: .active,
                focusMetric: focusMetric(for: goal),
                currentSignalSummary: signalSummary(for: goal, frictions: profile.frictions),
                milestone: GoalMilestone(
                    title: milestoneTitle(for: goal),
                    detail: milestoneDetail(for: goal),
                    progressHint: "Use 3-4 scans and 2 check-ins to make this signal feel honest."
                )
            )
        }

        let firstWeekPlan = FirstWeekPlan(
            title: "Your first 7 days",
            summary: "Build enough signal to let the strategist stop guessing and start learning.",
            steps: [
                FirstWeekPlanStep(
                    title: "Scan two everyday staples",
                    detail: "Use breakfast, snacks, or supplements you already reach for."
                ),
                FirstWeekPlanStep(
                    title: "Log one body signal",
                    detail: "A short morning or evening check-in gives the app something human to optimize for."
                ),
                FirstWeekPlanStep(
                    title: "Save or avoid one product on purpose",
                    detail: "This teaches the strategist what should stay in your routine versus what needs distance."
                )
            ]
        )

        let seededMemory = [
            MemoryItem(
                kind: .strategistTakeaway,
                title: "Primary focus",
                summary: activeGoals.first?.summary ?? "Start with clearer product decisions that support your week.",
                relatedProductID: nil,
                relatedProductName: nil,
                createdAt: profile.createdAt,
                lastReferencedAt: profile.createdAt
            ),
            MemoryItem(
                kind: .routineNote,
                title: "Preferred guidance",
                summary: "Guide with a \(profile.guidanceStyle.strategistVoice) tone.",
                relatedProductID: nil,
                relatedProductName: nil,
                createdAt: profile.createdAt,
                lastReferencedAt: profile.createdAt
            )
        ]

        let initialThread = ConversationThread(
            title: "Daily strategist",
            entryPoint: .home,
            createdAt: profile.createdAt,
            updatedAt: profile.createdAt,
            messages: [
                ConversationMessage(
                    speaker: .strategist,
                    text: openingMessage(for: profile, goals: activeGoals),
                    createdAt: profile.createdAt
                )
            ]
        )

        return StrategistBootstrap(
            profile: profile,
            activeGoals: activeGoals,
            firstWeekPlan: firstWeekPlan,
            seededMemory: seededMemory,
            initialThread: initialThread
        )
    }

    private func goalSummary(for goal: UserGoal, profile: UserProfile) -> String {
        switch goal {
        case .clearSkin:
            "Protect the food and supplement choices that keep skin calmer, clearer, and less inflamed."
        case .steadyEnergy:
            "Reduce the highs and crashes so the day feels steadier and less reactive."
        case .gutCalm:
            "Make digestion feel lighter and less noisy from meals, snacks, and supplements."
        case .hormoneSupport:
            "Favor routines that feel less inflammatory and more stable through the week."
        case .leanStrength:
            "Keep protein-forward decisions easy enough to repeat without overthinking them."
        case .deBloat:
            "Spot the products that quietly create heaviness, rebound hunger, or digestive drag."
        }
    }

    private func focusMetric(for goal: UserGoal) -> String {
        switch goal {
        case .clearSkin:
            "Barrier-friendly intake"
        case .steadyEnergy:
            "Steadier energy windows"
        case .gutCalm, .deBloat:
            "Digestive calm"
        case .hormoneSupport:
            "Lower-friction routine"
        case .leanStrength:
            "Repeatable protein anchors"
        }
    }

    private func signalSummary(for goal: UserGoal, frictions: [UserFriction]) -> String {
        if let friction = frictions.first {
            return "Watch how \(friction.title.lowercased()) changes as you tighten this goal."
        }
        return "Use scans and check-ins together so this stops being theoretical."
    }

    private func milestoneTitle(for goal: UserGoal) -> String {
        switch goal {
        case .clearSkin:
            "Build a calmer default stack"
        case .steadyEnergy:
            "Anchor one steadier morning"
        case .gutCalm:
            "Find one lighter repeat product"
        case .hormoneSupport:
            "Reduce the inflammatory noise"
        case .leanStrength:
            "Lock one reliable protein staple"
        case .deBloat:
            "Name one repeat trigger"
        }
    }

    private func milestoneDetail(for goal: UserGoal) -> String {
        switch goal {
        case .clearSkin:
            "Keep one scan-worthy staple and remove one obvious irritant or sugar-forward repeat."
        case .steadyEnergy:
            "Replace one jittery or hollow product with something more stable."
        case .gutCalm:
            "Scan and compare the products you reach for on busy days."
        case .hormoneSupport:
            "Reduce the products that pile on unnecessary stress."
        case .leanStrength:
            "Find a protein-forward option that still feels premium and easy."
        case .deBloat:
            "Track one product that seems fine on paper but feels heavy in real life."
        }
    }

    private func openingMessage(for profile: UserProfile, goals: [ActiveGoal]) -> String {
        let leadingGoal = goals.first?.title.lowercased() ?? "your week"
        let friction = profile.frictions.first?.strategistSummary ?? "build a clearer rhythm"
        return "I’m here to help you shape better daily product decisions around \(leadingGoal). We’ll start by using scans and body signals to \(friction)."
    }
}

struct RecommendationEngine {
    func nextAction(
        state: UserLifecycleState,
        profile: UserProfile,
        history: [ScanRecord],
        checkIns: [CheckInEntry],
        decisions: [ScanDecision],
        recommendedSwap: AlternativeSuggestion?
    ) -> Recommendation {
        if history.isEmpty {
            return Recommendation(
                id: "scan-staple",
                kind: .scanStaple,
                title: "Scan a daily staple",
                summary: "Start with something you already buy so the strategist learns from a real decision, not a demo.",
                cta: "Open scan",
                relatedProductID: nil,
                relatedGoal: profile.userContext.goals.first
            )
        }

        if needsCheckIn(checkIns: checkIns) {
            return Recommendation(
                id: "check-in-now",
                kind: .checkInNow,
                title: "Log a 30-second body signal",
                summary: "You already have product reads. Now give them a body signal so the next recommendation becomes more honest.",
                cta: "Check in",
                relatedProductID: nil,
                relatedGoal: profile.userContext.goals.first
            )
        }

        if let recommendedSwap {
            return Recommendation(
                id: "swap-\(recommendedSwap.productID)",
                kind: .swapProduct,
                title: "Test a softer swap",
                summary: recommendedSwap.whyBetter,
                cta: "Review swap",
                relatedProductID: recommendedSwap.productID,
                relatedGoal: profile.userContext.goals.first
            )
        }

        if decisions.contains(where: { $0.kind == .trackAgain && $0.resolvedAt == nil }) {
            return Recommendation(
                id: "repeat-track",
                kind: .repeatProduct,
                title: "Repeat one uncertain product",
                summary: "You marked something to watch again. A second read helps separate noise from a real pattern.",
                cta: "Open history",
                relatedProductID: nil,
                relatedGoal: profile.userContext.goals.first
            )
        }

        return Recommendation(
            id: "ask-strategist",
            kind: .askStrategist,
            title: "Ask the strategist what matters today",
            summary: "You have enough context for a more opinionated recommendation now.",
            cta: "Open strategist",
            relatedProductID: nil,
            relatedGoal: profile.userContext.goals.first
        )
    }

    private func needsCheckIn(checkIns: [CheckInEntry]) -> Bool {
        guard let latest = checkIns.first else { return true }
        return Calendar.current.dateComponents([.day], from: latest.createdAt, to: .now).day ?? 0 >= 1
    }
}

struct HomeComposer {
    private let recommendationEngine = RecommendationEngine()

    func compose(
        profile: UserProfile,
        activeGoals: [ActiveGoal],
        firstWeekPlan: FirstWeekPlan?,
        history: [ScanRecord],
        checkIns: [CheckInEntry],
        decisions: [ScanDecision],
        memoryItems: [MemoryItem],
        experiments: [Experiment]
    ) -> DailyHomePayload {
        let state = lifecycleState(history: history, checkIns: checkIns)
        let recommendedSwap = latestRecommendedSwap(from: history)
        let nextAction = recommendationEngine.nextAction(
            state: state,
            profile: profile,
            history: history,
            checkIns: checkIns,
            decisions: decisions,
            recommendedSwap: recommendedSwap
        )

        return DailyHomePayload(
            state: state,
            todayFocus: todayFocus(for: activeGoals, firstWeekPlan: firstWeekPlan, state: state),
            bodySignal: bodySignal(from: checkIns, goal: activeGoals.first),
            nextAction: nextAction,
            recommendedSwap: recommendedSwap,
            openLoops: openLoops(from: decisions, firstWeekPlan: firstWeekPlan, experiments: experiments),
            strategistNote: strategistNote(profile: profile, goal: activeGoals.first, checkIns: checkIns, history: history),
            recentWins: recentWins(history: history, decisions: decisions, memoryItems: memoryItems)
        )
    }

    private func lifecycleState(history: [ScanRecord], checkIns: [CheckInEntry]) -> UserLifecycleState {
        let latestEventDate = [history.first?.createdAt, checkIns.first?.createdAt].compactMap { $0 }.max() ?? .distantPast
        let daysSinceLastEvent = Calendar.current.dateComponents([.day], from: latestEventDate, to: .now).day ?? 99

        if history.count < 2 || checkIns.count < 2 {
            return .calibrating
        }
        if daysSinceLastEvent >= 12 {
            return .reengagement
        }
        if daysSinceLastEvent >= 6 {
            return .drifting
        }
        return .active
    }

    private func todayFocus(for goals: [ActiveGoal], firstWeekPlan: FirstWeekPlan?, state: UserLifecycleState) -> TodayFocus {
        if state == .calibrating, let nextStep = firstWeekPlan?.steps.first(where: { !$0.isComplete }) {
            return TodayFocus(
                title: "Calibrate your strategist",
                summary: nextStep.detail
            )
        }

        if let goal = goals.first {
            return TodayFocus(
                title: goal.title,
                summary: goal.summary
            )
        }

        return TodayFocus(
            title: "Shape a better default",
            summary: "Use one real scan and one real body signal so the app can stop speaking in generalities."
        )
    }

    private func bodySignal(from checkIns: [CheckInEntry], goal: ActiveGoal?) -> CheckInSignal {
        guard !checkIns.isEmpty else {
            return CheckInSignal(
                title: "No fresh body signal yet",
                summary: "A short check-in will make the next recommendation feel less generic.",
                tone: .neutral
            )
        }

        let recent = Array(checkIns.prefix(3))
        let energyAverage = average(recent.map(\.energy))
        let bloatingAverage = average(recent.map(\.bloatingRelief))

        if energyAverage < 3.2 {
            return CheckInSignal(
                title: "Energy still looks soft",
                summary: "Your recent check-ins suggest the day is still wobbling. Use that as the lens for the next product decision.",
                tone: .caution
            )
        }

        if bloatingAverage < 3.1 {
            return CheckInSignal(
                title: "Digestion needs a lighter hand",
                summary: "Recent signals still point to heaviness or bloating. Protect the gut-comfort lens today.",
                tone: .caution
            )
        }

        return CheckInSignal(
            title: "\(goal?.focusMetric ?? "Body signal") is holding steady",
            summary: "Your latest signals are supportive enough to keep building on what already fits.",
            tone: .supportive
        )
    }

    private func latestRecommendedSwap(from history: [ScanRecord]) -> AlternativeSuggestion? {
        history.first(where: {
            ($0.analysis.lensScores.min(by: { $0.score < $1.score })?.score ?? 100) < 58
        })?.analysis.alternatives.first
    }

    private func openLoops(from decisions: [ScanDecision], firstWeekPlan: FirstWeekPlan?, experiments: [Experiment]) -> [OpenLoop] {
        var items = decisions
            .filter { $0.resolvedAt == nil && $0.kind.keepsLoopOpen }
            .prefix(2)
            .map {
                switch $0.kind {
                case .saveToRoutine:
                    return OpenLoop(
                        title: "Confirm the routine slot",
                        summary: "Use the next check-in to confirm whether \($0.productName) really deserves repeat space."
                    )
                case .swapInstead:
                    return OpenLoop(
                        title: "Test the softer swap",
                        summary: "Do not let \($0.productName) harden into routine before the cleaner alternative gets a real try."
                    )
                case .trackAgain:
                    return OpenLoop(
                        title: "Retest \($0.productName)",
                        summary: "Run one cleaner repeat so the next decision is based on signal, not guesswork."
                    )
                case .avoidForNow, .askStrategist:
                    return OpenLoop(
                        title: $0.kind.title,
                        summary: $0.note
                    )
                }
            }

        if let incompletePlanStep = firstWeekPlan?.steps.first(where: { !$0.isComplete }) {
            items.append(
                OpenLoop(
                    title: incompletePlanStep.title,
                    summary: incompletePlanStep.detail
                )
            )
        }

        items.append(contentsOf: experiments.filter { $0.status == .active }.prefix(1).map {
            OpenLoop(
                title: $0.title,
                summary: $0.hypothesis
            )
        })

        return Array(items.prefix(3))
    }

    private func strategistNote(
        profile: UserProfile,
        goal: ActiveGoal?,
        checkIns: [CheckInEntry],
        history: [ScanRecord]
    ) -> StrategistNote {
        let scannedProduct = history.first?.analysis.resolvedProduct.name ?? "your next staple"
        let tone = profile.guidanceStyle

        if let note = checkIns.first?.note, !note.isEmpty {
            return StrategistNote(
                title: "Strategist note",
                summary: "You logged “\(note)”. I’d use that as a lens before trusting \(scannedProduct) as a repeat choice."
            )
        }

        if let goal {
            return StrategistNote(
                title: "Strategist note",
                summary: "Stay \(tone.strategistVoice). Today should be about protecting \(goal.title.lowercased()) with one deliberate decision, not ten small guesses."
            )
        }

        return StrategistNote(
            title: "Strategist note",
            summary: "The app is strongest when it sees one real product and one real body signal in the same week."
        )
    }

    private func recentWins(
        history: [ScanRecord],
        decisions: [ScanDecision],
        memoryItems: [MemoryItem]
    ) -> [RecentWin] {
        var wins: [RecentWin] = history
            .filter {
                ($0.analysis.lensScores.max(by: { $0.score < $1.score })?.score ?? 0) >= 82
            }
            .prefix(2)
            .map {
                RecentWin(
                    title: "\($0.analysis.resolvedProduct.name) landed well",
                    summary: $0.analysis.overallSummary
                )
            }

        wins.append(contentsOf: decisions.filter { $0.kind == .saveToRoutine }.prefix(1).map {
            RecentWin(
                title: "Routine saved",
                summary: "\($0.productName) is now treated like a keeper, not just a one-off read."
            )
        })

        wins.append(contentsOf: memoryItems.filter { $0.kind == .experimentWin }.prefix(1).map {
            RecentWin(title: $0.title, summary: $0.summary)
        })

        return Array(wins.prefix(3))
    }

    private func average(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

struct ConversationContextAssembler {
    func build(
        profile: UserProfile,
        activeGoals: [ActiveGoal],
        history: [ScanRecord],
        checkIns: [CheckInEntry],
        decisions: [ScanDecision],
        memoryItems: [MemoryItem],
        patternInsights: [PatternInsight],
        weeklyNarrative: WeeklyInsightNarrative?
    ) -> ConversationTurnContext {
        let signalSummaries: [String]
        if let latest = checkIns.first {
            signalSummaries = [
                "Energy \(latest.energy)/5",
                "Bloating relief \(latest.bloatingRelief)/5",
                "Mood \(latest.mood)/5"
            ]
        } else {
            signalSummaries = ["No recent body signal"]
        }

        return ConversationTurnContext(
            activeGoalTitles: activeGoals.map(\.title),
            recentSignals: signalSummaries,
            recentProducts: Array(history.prefix(3)).map(\.analysis.resolvedProduct.name),
            openLoopSummaries: Array(decisions.filter { $0.resolvedAt == nil }.prefix(3)).map(\.note),
            memorySummaries: Array(memoryItems.prefix(4)).map(\.summary),
            latestDecisionSummary: decisions.first?.note,
            latestReadSummary: history.first?.analysis.overallSummary,
            latestPatternTitle: patternInsights.first?.title,
            latestPatternSummary: patternInsights.first?.summary,
            weeklyNarrativeHeadline: weeklyNarrative?.headline,
            weeklyNarrativeSummary: weeklyNarrative?.patternSummary,
            weeklyNextExperiment: weeklyNarrative?.nextExperiment
        )
    }
}

struct StrategistResponseEngine {
    func respond(
        to message: String,
        profile: UserProfile,
        entryPoint: StrategistEntryPoint,
        context: ConversationTurnContext,
        linkedAnalysis: ScanAnalysis?
    ) -> ConversationMessage {
        let goal = context.activeGoalTitles.first?.lowercased() ?? "your week"
        let signal = context.recentSignals.first?.lowercased() ?? "your last body signal"
        let product = linkedAnalysis?.resolvedProduct.name ?? context.recentProducts.first ?? "that product"
        let whyNow = context.weeklyNarrativeSummary ?? context.latestPatternSummary ?? context.latestDecisionSummary ?? "Keep the next decision tied to \(goal)."
        let experiment = context.weeklyNextExperiment ?? context.openLoopSummaries.first ?? "Use the next scan to make one explicit keep, avoid, or swap decision."
        let memoryAnchor = context.memorySummaries.first ?? "No strong saved memory yet."
        let normalizedMessage = message.lowercased()

        let reply: String
        if let linkedAnalysis {
            reply = linkedReadReply(
                for: linkedAnalysis,
                product: product,
                goal: goal,
                signal: signal,
                whyNow: whyNow,
                prompt: normalizedMessage
            )
        } else if normalizedMessage.contains("learned") || normalizedMessage.contains("me so far") || entryPoint == .profile {
            reply = [
                "What I'm learning: \(context.latestPatternTitle ?? memoryAnchor)",
                "Strongest signal: \(whyNow)",
                "Best next step: Use the next real decision to support \(goal), then keep the result if it still matches how the day feels.",
                "Ask next: Do you want me to narrow your goal, call out the noisiest friction, or name the easiest repeat win?"
            ].joined(separator: "\n\n")
        } else if entryPoint == .checkIn || normalizedMessage.contains("energy") || normalizedMessage.contains("signal") || normalizedMessage.contains("feel off") {
            reply = [
                "Best next step: Keep the next choice as calm and repeatable as possible for \(goal).",
                "Why now: \(signal.capitalizedSentence) is the freshest signal, and \(whyNow)",
                "Watch for: A rough-feeling day is a bad time to force a big experiment.",
                "Ask next: Do you want the easiest product category to protect today or the one to avoid?"
            ].joined(separator: "\n\n")
        } else {
            reply = [
                "Best next step: \(context.latestDecisionSummary ?? "Use your next scan to make one explicit keep, avoid, or swap call for \(goal).")",
                "Why now: \(whyNow)",
                "Watch for: \(context.latestPatternSummary ?? "If the day already feels rough, favor calmer repeats over novelty.")",
                "Ask next: \(experiment)"
            ].joined(separator: "\n\n")
        }

        return ConversationMessage(
            speaker: .strategist,
            text: reply,
            createdAt: .now
        )
    }

    private func linkedReadReply(
        for analysis: ScanAnalysis,
        product: String,
        goal: String,
        signal: String,
        whyNow: String,
        prompt: String
    ) -> String {
        let weakestLens = analysis.lensScores.min(by: { $0.score < $1.score })?.lens.title.lowercased() ?? "fit"
        let strongestLens = analysis.lensScores.max(by: { $0.score < $1.score })?.lens.title.lowercased() ?? "fit"
        let averageScore = Int((Double(analysis.lensScores.map(\.score).reduce(0, +)) / Double(max(analysis.lensScores.count, 1))).rounded())
        let verdict = linkedVerdict(for: analysis, averageScore: averageScore)
        let alternative = analysis.alternatives.first

        let bestNextStep: String
        switch verdict {
        case .good:
            bestNextStep = "Keep \(product) in play for \(goal), but only graduate it into routine if the next real use still feels stable."
        case .adjust:
            if let alternative {
                bestNextStep = "Treat \(product) as borderline and test \(alternative.productName) first if you want the softer move."
            } else {
                bestNextStep = "Use \(product) as a directional option, not a routine lock. One more real-world repeat should decide it."
            }
        case .avoid:
            if let alternative {
                bestNextStep = "Skip \(product) for now and test \(alternative.productName) instead."
            } else {
                bestNextStep = "Keep \(product) out of the routine for now and wait for a calmer context before repeating it."
            }
        case .needsMoreInfo:
            bestNextStep = "Do not over-commit on \(product) yet. Get a cleaner read or a more grounded follow-up before deciding."
        }

        let askNext: String
        if prompt.contains("swap"), let alternative {
            askNext = "Do you want the exact reason \(alternative.productName) reads as the softer swap?"
        } else if prompt.contains("routine") {
            askNext = "Do you want me to turn this into a keep, avoid, or retest call in one sentence?"
        } else if let alternative {
            askNext = "Do you want me to compare \(product) against \(alternative.productName) directly?"
        } else {
            askNext = "Do you want me to explain whether this is a keep, avoid, or retest decision?"
        }

        return [
            "Best next step: \(bestNextStep)",
            "Why now: \(whyNow)",
            "Watch for: \(product) is strongest around \(strongestLens), but the soft spot is \(weakestLens) when \(signal).",
            "Ask next: \(askNext)"
        ].joined(separator: "\n\n")
    }

    private func linkedVerdict(for analysis: ScanAnalysis, averageScore: Int) -> AnalysisVerdict {
        if analysis.confidence == .low && averageScore < 55 {
            return .needsMoreInfo
        }
        switch averageScore {
        case 78...:
            return .good
        case 58...:
            return .adjust
        default:
            return .avoid
        }
    }
}

private extension String {
    var capitalizedSentence: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

extension UserGoal {
    var strategistPrompt: String {
        switch self {
        case .clearSkin:
            "What should I stop buying if I want calmer skin?"
        case .steadyEnergy:
            "Which product is most likely causing my crash?"
        case .gutCalm:
            "What should I scan next if digestion feels heavy?"
        case .hormoneSupport:
            "What choices feel least inflammatory this week?"
        case .leanStrength:
            "What’s the easiest protein-forward staple to keep?"
        case .deBloat:
            "How do I spot the products that make me feel puffy?"
        }
    }
}
