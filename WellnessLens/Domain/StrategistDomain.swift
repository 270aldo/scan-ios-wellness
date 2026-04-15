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
    var createdAt: Date

    static let starter = UserProfile(
        userContext: .starter,
        frictions: [.energyCrash, .bloating],
        guidanceStyle: .calmAndDirect,
        eatingRhythm: .flexible,
        supplementStyle: .simple,
        memoryEnabled: true,
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
            createdAt: createdAt
        )
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
            .filter { $0.resolvedAt == nil }
            .prefix(2)
            .map {
                OpenLoop(
                    title: $0.kind.title,
                    summary: "\($0.productName) is still open in your routine."
                )
            }

        if let incompletePlanStep = firstWeekPlan?.steps.first(where: { !$0.isComplete }) {
            items.append(
                OpenLoop(
                    title: incompletePlanStep.title,
                    summary: incompletePlanStep.detail
                )
            )
        }

        items.append(contentsOf: experiments.prefix(1).map {
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
        memoryItems: [MemoryItem]
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
            memorySummaries: Array(memoryItems.prefix(4)).map(\.summary)
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
        let friction = profile.frictions.first?.strategistSummary ?? "tighten the pattern"

        let reply: String
        if let linkedAnalysis {
            let weakestLens = linkedAnalysis.lensScores.min(by: { $0.score < $1.score })?.lens.title.lowercased() ?? "fit"
            reply = "\(product) looks usable, but I’d frame it around \(goal). The soft spot is \(weakestLens), so if today already feels rough in \(signal), I’d either swap it or track it again instead of assuming it belongs."
        } else if message.lowercased().contains("craving") || message.lowercased().contains("energy") {
            reply = "Given \(signal), I’d stay with one calmer decision today: protect \(goal) first, then use the next scan to \(friction). Don’t try to optimize the whole week at once."
        } else {
            reply = "From here, I’d keep the strategy simple: use your next decision to support \(goal), keep an eye on \(signal), and let me remember what actually helped instead of relying on intention alone."
        }

        return ConversationMessage(
            speaker: .strategist,
            text: reply,
            createdAt: .now
        )
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
