import Foundation
import Observation

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case scan
    case history
    case checkIn
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: WLProductCopy.Tabs.home
        case .scan: WLProductCopy.Tabs.scan
        case .history: WLProductCopy.Tabs.history
        case .checkIn: WLProductCopy.Tabs.checkIn
        case .profile: WLProductCopy.Tabs.profile
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .scan: "viewfinder"
        case .history: "square.stack"
        case .checkIn: "heart.text.square"
        case .profile: "person"
        }
    }

    var tabRole: AppTabRole {
        switch self {
        case .scan:
            .primaryAction
        case .home, .history, .checkIn, .profile:
            .destination
        }
    }

    var visualPriority: AppTabVisualPriority {
        switch self {
        case .scan:
            .primary
        case .home, .history, .checkIn, .profile:
            .standard
        }
    }
}

enum AppTabRole {
    case destination
    case primaryAction
}

enum AppTabVisualPriority {
    case standard
    case primary
}

enum ScanFeedback: Equatable {
    case emptyInput
    case unresolved
    case ocrEmpty
    case ocrFailed
    case custom(String)

    var title: String {
        switch self {
        case .emptyInput:
            "Add something to analyze"
        case .unresolved:
            "We couldn't resolve this product yet"
        case .ocrEmpty:
            "No readable label text found"
        case .ocrFailed:
            "Label OCR needs a cleaner image"
        case .custom:
            "Scan needs attention"
        }
    }

    var message: String {
        switch self {
        case .emptyInput:
            "Use a barcode, a label snippet, or a one-tap demo scenario before analyzing."
        case .unresolved:
            "Try a brighter label photo, a cleaner barcode, or one of the guided demo scenarios."
        case .ocrEmpty:
            "The selected image did not return enough readable text. Try a tighter, brighter crop."
        case .ocrFailed:
            "Try a sharper, brighter label photo or switch to manual label text."
        case let .custom(message):
            message
        }
    }
}

@MainActor
@Observable
final class AppModel {
    let services: AppServices

    var selectedTab: AppTab = .home
    var hasCompletedOnboarding: Bool
    var userContext: UserContext
    var userProfile: UserProfile
    var activeGoals: [ActiveGoal]
    var firstWeekPlan: FirstWeekPlan?
    var history: [ScanRecord]
    var checkIns: [CheckInEntry]
    var routines: [RoutineItem]
    var memoryItems: [MemoryItem]
    var scanDecisions: [ScanDecision]
    var experiments: [Experiment]
    var conversationThreads: [ConversationThread]
    var lastDemoScenarioID: String?
    var latestAnalysis: ScanAnalysis?
    var activeComparison: ProductComparison?
    var scanFeedback: ScanFeedback?
    var isAnalyzing = false
    var subscriptionStatus: SubscriptionStatus
    var remoteInsights: [WeeklyInsight] = []
    var remoteHomePayload: DailyHomePayload?
    var bootstrapCompleted = false

    private let homeComposer = HomeComposer()
    private let onboardingPlanner = OnboardingPlanner()
    private let contextAssembler = ConversationContextAssembler()
    private let strategistResponseEngine = StrategistResponseEngine()

    init(services: AppServices? = nil) {
        let resolvedServices = services ?? AppServices.makePreviewServices()
        self.services = resolvedServices
        let snapshot = resolvedServices.store.load()
        let derivedProfile = snapshot.userProfile ?? UserProfile.migrated(from: snapshot.userContext)
        let bootstrap = onboardingPlanner.build(profile: derivedProfile)

        hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        userContext = derivedProfile.userContext
        userProfile = derivedProfile
        activeGoals = snapshot.activeGoals.isEmpty && snapshot.hasCompletedOnboarding ? bootstrap.activeGoals : snapshot.activeGoals
        firstWeekPlan = snapshot.firstWeekPlan ?? (snapshot.hasCompletedOnboarding ? bootstrap.firstWeekPlan : nil)
        history = snapshot.history.sorted(by: { $0.createdAt > $1.createdAt })
        checkIns = snapshot.checkIns.sorted(by: { $0.createdAt > $1.createdAt })
        routines = snapshot.routines
        memoryItems = snapshot.memoryItems.isEmpty && snapshot.hasCompletedOnboarding ? bootstrap.seededMemory : snapshot.memoryItems
        scanDecisions = snapshot.scanDecisions.sorted(by: { $0.createdAt > $1.createdAt })
        experiments = snapshot.experiments.sorted(by: { $0.lastUpdatedAt > $1.lastUpdatedAt })
        conversationThreads = snapshot.conversationThreads.isEmpty && snapshot.hasCompletedOnboarding ? [bootstrap.initialThread] : snapshot.conversationThreads
        lastDemoScenarioID = snapshot.lastDemoScenarioID
        subscriptionStatus = snapshot.subscriptionStatus
    }

    var featuredProducts: [ProductCandidate] {
        services.scanService.featuredProducts
    }

    var demoScenarioPacks: [DemoScenarioPack] {
        DemoScenarioCatalog.packs
    }

    var lastDemoScenario: DemoScenario? {
        DemoScenarioCatalog.scenario(id: lastDemoScenarioID)
    }

    var weeklyInsights: [WeeklyInsight] {
        remoteInsights.isEmpty ? WeeklyInsightEngine().generate(history: history, checkIns: checkIns) : remoteInsights
    }

    var latestRecord: ScanRecord? {
        history.first
    }

    var dailyHomePayload: DailyHomePayload {
        remoteHomePayload ?? homeComposer.compose(
            profile: userProfile,
            activeGoals: activeGoals,
            firstWeekPlan: firstWeekPlan,
            history: history,
            checkIns: checkIns,
            decisions: scanDecisions,
            memoryItems: memoryItems,
            experiments: experiments
        )
    }

    var historyTimelineEntries: [HistoryTimelineEntry] {
        let scanEntries = history.map {
            HistoryTimelineEntry(
                kind: .scan,
                title: $0.analysis.resolvedProduct.name,
                summary: $0.analysis.overallSummary,
                createdAt: $0.createdAt
            )
        }

        let decisionEntries = scanDecisions.map {
            HistoryTimelineEntry(
                kind: .decision,
                title: $0.kind.title,
                summary: "\($0.productName) • \($0.note)",
                createdAt: $0.createdAt
            )
        }

        let checkInEntries = checkIns.map {
            HistoryTimelineEntry(
                kind: .checkIn,
                title: "Body signal",
                summary: bodySignalSummary(for: $0),
                createdAt: $0.createdAt
            )
        }

        let routineEntries = routines.map {
            HistoryTimelineEntry(
                kind: .memory,
                title: "\($0.productName) joined routine",
                summary: $0.note,
                createdAt: $0.createdAt
            )
        }

        let memoryEntries = memoryItems.map {
            HistoryTimelineEntry(
                kind: .memory,
                title: $0.title,
                summary: $0.summary,
                createdAt: $0.createdAt
            )
        }

        let experimentEntries = experiments.map {
            HistoryTimelineEntry(
                kind: .memory,
                title: $0.title,
                summary: $0.hypothesis,
                createdAt: $0.lastUpdatedAt
            )
        }

        let conversationEntries = conversationThreads.compactMap { thread -> HistoryTimelineEntry? in
            guard let latest = thread.messages.last else { return nil }
            return HistoryTimelineEntry(
                kind: .conversation,
                title: thread.title,
                summary: latest.text,
                createdAt: latest.createdAt
            )
        }

        return (scanEntries + decisionEntries + checkInEntries + routineEntries + memoryEntries + experimentEntries + conversationEntries)
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    func completeOnboarding(with context: UserContext) {
        completeOnboarding(with: UserProfile.migrated(from: context))
    }

    func completeOnboarding(with profile: UserProfile) {
        let bootstrap = onboardingPlanner.build(profile: profile)
        userProfile = bootstrap.profile
        userContext = bootstrap.profile.userContext
        hasCompletedOnboarding = true
        activeGoals = bootstrap.activeGoals
        firstWeekPlan = bootstrap.firstWeekPlan
        memoryItems = bootstrap.seededMemory
        conversationThreads = [bootstrap.initialThread]
        persist()

        Task {
            await syncProfileIfNeeded()
            await refreshInsightsIfNeeded()
            await refreshHomeIfNeeded()
        }
    }

    func analyzeBarcode(_ barcode: String, source: ScanSource = .manualBarcode) async {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        await analyze(
            ScanInput(
                sourceType: source,
                barcode: trimmed,
                capturedImageRef: nil,
                rawText: nil,
                productTypeHint: nil,
                locale: Locale.current.identifier
            )
        )
    }

    func analyzeLabelText(_ text: String, source: ScanSource = .manualLabel, typeHint: ProductType? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        await analyze(
            ScanInput(
                sourceType: source,
                barcode: nil,
                capturedImageRef: nil,
                rawText: trimmed,
                productTypeHint: typeHint,
                locale: Locale.current.identifier
            )
        )
    }

    func analyzeSample(_ product: ProductCandidate) async {
        if let barcode = product.barcode {
            await analyzeBarcode(barcode, source: .manualBarcode)
        } else {
            let joined = product.ingredients.map(\.name).joined(separator: ", ")
            await analyzeLabelText(joined, source: .manualLabel, typeHint: product.productType)
        }
    }

    func runDemoScenario(_ scenario: DemoScenario) async {
        lastDemoScenarioID = scenario.id
        persist()
        await analyze(scenario.scanInput)
    }

    func dismissAnalysis() {
        latestAnalysis = nil
    }

    func dismissComparison() {
        activeComparison = nil
    }

    func toggleFavorite(for recordID: UUID) {
        guard let index = history.firstIndex(where: { $0.id == recordID }) else { return }
        history[index].isFavorite.toggle()
        persist()
    }

    func addCheckIn(
        energy: Int,
        skin: Int,
        bloatingRelief: Int,
        cravingControl: Int,
        mood: Int,
        note: String
    ) {
        let checkIn = CheckInEntry(
            createdAt: .now,
            energy: energy,
            skin: skin,
            bloatingRelief: bloatingRelief,
            cravingControl: cravingControl,
            mood: mood,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        checkIns.insert(checkIn, at: 0)

        if let planStep = firstWeekPlan?.steps.firstIndex(where: { $0.title.localizedCaseInsensitiveContains("body signal") }) {
            firstWeekPlan?.steps[planStep].isComplete = true
        }

        if !checkIn.note.isEmpty {
            upsertMemoryItem(
                MemoryItem(
                    kind: .checkInPattern,
                    title: "Body note saved",
                    summary: checkIn.note,
                    relatedProductID: nil,
                    relatedProductName: nil,
                    createdAt: .now,
                    lastReferencedAt: .now
                )
            )
        } else if checkIn.energy <= 2 || checkIn.bloatingRelief <= 2 {
            upsertMemoryItem(
                MemoryItem(
                    kind: .checkInPattern,
                    title: "Today felt softer",
                    summary: bodySignalSummary(for: checkIn),
                    relatedProductID: nil,
                    relatedProductName: nil,
                    createdAt: .now,
                    lastReferencedAt: .now
                )
            )
        } else if checkIn.energy >= 4 && checkIn.mood >= 4 {
            upsertMemoryItem(
                MemoryItem(
                    kind: .experimentWin,
                    title: "A stronger day",
                    summary: "Energy and mood both landed in a supportive range today.",
                    relatedProductID: nil,
                    relatedProductName: nil,
                    createdAt: .now,
                    lastReferencedAt: .now
                )
            )
        }

        persist()
        Task {
            await syncCheckInIfNeeded(checkIn)
            await syncMemoryIfNeeded()
            await refreshInsightsIfNeeded()
            await refreshHomeIfNeeded()
        }
    }

    func compare(_ records: [ScanRecord]) {
        guard records.count == 2 else { return }
        activeComparison = AnalysisEngine().compare(records[0].analysis, records[1].analysis)
    }

    func purchase(_ target: SubscriptionStatus) async {
        subscriptionStatus = await services.subscription.purchase(target)
        persist()
    }

    func restorePurchases() async {
        subscriptionStatus = await services.subscription.restore()
        persist()
    }

    func updateUserContext(_ context: UserContext) {
        updateUserProfile(
            UserProfile(
                userContext: context,
                frictions: userProfile.frictions,
                guidanceStyle: userProfile.guidanceStyle,
                eatingRhythm: userProfile.eatingRhythm,
                supplementStyle: userProfile.supplementStyle,
                memoryEnabled: userProfile.memoryEnabled,
                createdAt: userProfile.createdAt
            )
        )
    }

    func updateUserProfile(_ profile: UserProfile) {
        userProfile = profile
        userContext = profile.userContext

        let bootstrap = onboardingPlanner.build(profile: profile)
        activeGoals = bootstrap.activeGoals
        firstWeekPlan = merge(firstWeekPlan, with: bootstrap.firstWeekPlan)

        if memoryItems.isEmpty {
            memoryItems = bootstrap.seededMemory
        } else {
            upsertMemoryItem(
                MemoryItem(
                    kind: .routineNote,
                    title: "Preferred guidance",
                    summary: "Guide with a \(profile.guidanceStyle.strategistVoice) tone.",
                    relatedProductID: nil,
                    relatedProductName: nil,
                    createdAt: .now,
                    lastReferencedAt: .now
                )
            )
        }

        if conversationThreads.isEmpty {
            conversationThreads = [bootstrap.initialThread]
        }

        persist()
        Task {
            await syncProfileIfNeeded()
            await syncMemoryIfNeeded()
            await refreshInsightsIfNeeded()
            await refreshHomeIfNeeded()
        }
    }

    func clearScanFeedback() {
        scanFeedback = nil
    }

    func presentScanFeedback(_ feedback: ScanFeedback) {
        scanFeedback = feedback
    }

    func consumeIntentRouteIfNeeded() {
        guard let route = IntentBridge.consume() else { return }
        selectedTab = route.tab
    }

    func bootstrap() async {
        guard !bootstrapCompleted else { return }
        bootstrapCompleted = true

        await services.identityProvider.prepare()
        await refreshInsightsIfNeeded()
        await refreshHomeIfNeeded()
    }

    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "wellnesslens" else { return }
        if url.host == "tab", let component = url.pathComponents.dropFirst().first, let tab = AppTab(rawValue: component) {
            selectedTab = tab
        }
    }

    func recordScanDecision(_ kind: ScanDecisionKind, for analysis: ScanAnalysis) {
        let decision = ScanDecision(
            createdAt: .now,
            productID: analysis.resolvedProduct.id,
            productName: analysis.resolvedProduct.name,
            kind: kind,
            note: decisionNote(for: kind, analysis: analysis),
            relatedGoal: userProfile.userContext.goals.first,
            resolvedAt: kind == .askStrategist ? .now : nil
        )

        scanDecisions.insert(decision, at: 0)

        switch kind {
        case .saveToRoutine:
            upsertRoutine(
                RoutineItem(
                    productID: analysis.resolvedProduct.id,
                    productName: analysis.resolvedProduct.name,
                    cadenceSummary: "Keep as a likely repeat choice",
                    note: "Saved after a supportive read.",
                    createdAt: .now
                )
            )
            upsertMemoryItem(
                MemoryItem(
                    kind: .staple,
                    title: "\(analysis.resolvedProduct.name) became a staple",
                    summary: analysis.overallSummary,
                    relatedProductID: analysis.resolvedProduct.id,
                    relatedProductName: analysis.resolvedProduct.name,
                    createdAt: .now,
                    lastReferencedAt: .now
                )
            )
        case .avoidForNow:
            upsertMemoryItem(
                MemoryItem(
                    kind: .avoid,
                    title: "Avoid for now",
                    summary: "\(analysis.resolvedProduct.name) is currently a softer fit for your week.",
                    relatedProductID: analysis.resolvedProduct.id,
                    relatedProductName: analysis.resolvedProduct.name,
                    createdAt: .now,
                    lastReferencedAt: .now
                )
            )
        case .swapInstead:
            if let alternative = analysis.alternatives.first {
                upsertMemoryItem(
                    MemoryItem(
                        kind: .experimentCaution,
                        title: "Swap to test",
                        summary: "Try \(alternative.productName) instead. \(alternative.whyBetter)",
                        relatedProductID: alternative.productID,
                        relatedProductName: alternative.productName,
                        createdAt: .now,
                        lastReferencedAt: .now
                    )
                )
            }
        case .askStrategist:
            sendStrategistMessage(
                "Help me decide whether \(analysis.resolvedProduct.name) belongs in my routine.",
                entryPoint: .scan,
                linkedAnalysis: analysis
            )
        case .trackAgain:
            upsertExperiment(
                Experiment(
                    title: "Retest \(analysis.resolvedProduct.name)",
                    hypothesis: "A second read will show whether this is a one-off or a repeat friction point.",
                    status: .active,
                    relatedGoal: userProfile.userContext.goals.first,
                    createdAt: .now,
                    lastUpdatedAt: .now
                )
            )
        }

        if let planStep = firstWeekPlan?.steps.firstIndex(where: { $0.title.localizedCaseInsensitiveContains("Save or avoid") }) {
            firstWeekPlan?.steps[planStep].isComplete = true
        }

        persist()
        Task {
            await syncScanDecisionIfNeeded(decision)
            await syncMemoryIfNeeded()
            await refreshHomeIfNeeded()
        }
    }

    func conversationThread(for entryPoint: StrategistEntryPoint) -> ConversationThread {
        if let thread = conversationThreads.first(where: { $0.entryPoint == entryPoint }) {
            return thread
        }

        let fallback = onboardingPlanner.build(profile: userProfile).initialThread
        return ConversationThread(
            title: entryPoint.title,
            entryPoint: entryPoint,
            createdAt: .now,
            updatedAt: .now,
            messages: fallback.messages
        )
    }

    func strategistStarterPrompts(for entryPoint: StrategistEntryPoint) -> [String] {
        let base = userProfile.userContext.goals.prefix(2).map(\.strategistPrompt)
        switch entryPoint {
        case .home:
            return Array(base) + ["What’s the one decision that matters most today?"]
        case .scan:
            return ["Should this stay in my routine?", "What would be a softer swap?"] + base
        case .checkIn:
            return ["What should I avoid if today already feels off?", "How do I use this body signal well?"]
        case .profile:
            return ["What have you learned about me so far?", "What goal should I narrow next?"]
        }
    }

    func sendStrategistMessage(
        _ text: String,
        entryPoint: StrategistEntryPoint,
        linkedAnalysis: ScanAnalysis? = nil
    ) {
        let threadIndex = ensureConversationThread(for: entryPoint)
        let userMessage = ConversationMessage(
            speaker: .user,
            text: text,
            createdAt: .now
        )
        conversationThreads[threadIndex].messages.append(userMessage)

        let context = contextAssembler.build(
            profile: userProfile,
            activeGoals: activeGoals,
            history: history,
            checkIns: checkIns,
            decisions: scanDecisions,
            memoryItems: memoryItems
        )
        let reply = strategistResponseEngine.respond(
            to: text,
            profile: userProfile,
            entryPoint: entryPoint,
            context: context,
            linkedAnalysis: linkedAnalysis
        )
        conversationThreads[threadIndex].messages.append(reply)
        conversationThreads[threadIndex].updatedAt = .now

        if linkedAnalysis != nil {
            upsertMemoryItem(
                MemoryItem(
                    kind: .strategistTakeaway,
                    title: "Strategist takeaway",
                    summary: reply.text,
                    relatedProductID: linkedAnalysis?.resolvedProduct.id,
                    relatedProductName: linkedAnalysis?.resolvedProduct.name,
                    createdAt: .now,
                    lastReferencedAt: .now
                )
            )
        }

        persist()
    }

    private func analyze(_ input: ScanInput) async {
        isAnalyzing = true
        scanFeedback = nil
        defer { isAnalyzing = false }

        do {
            let analysis = try await services.scanService.analyze(input: input, userContext: userContext)
            latestAnalysis = analysis
            history.insert(ScanRecord(createdAt: .now, analysis: analysis), at: 0)
            if history.count > 60 {
                history = Array(history.prefix(60))
            }

            if let planStep = firstWeekPlan?.steps.firstIndex(where: { $0.title.localizedCaseInsensitiveContains("Scan two") }) {
                firstWeekPlan?.steps[planStep].isComplete = history.count >= 2
            }

            persist()
            await refreshInsightsIfNeeded()
            await refreshHomeIfNeeded()
        } catch {
            if let serviceError = error as? ScanServiceError {
                switch serviceError {
                case .emptyInput:
                    scanFeedback = .emptyInput
                case .unresolvedScan:
                    scanFeedback = .unresolved
                }
            } else {
                scanFeedback = .custom(error.localizedDescription)
            }
        }
    }

    private func syncProfileIfNeeded() async {
        guard let backendAPI = services.backendAPI else { return }
        try? await backendAPI.completeOnboarding(
            profile: userProfile,
            activeGoals: activeGoals,
            firstWeekPlan: firstWeekPlan
        )
    }

    private func syncCheckInIfNeeded(_ checkIn: CheckInEntry) async {
        guard let backendAPI = services.backendAPI else { return }
        try? await backendAPI.saveCheckIn(checkIn, userContext: userContext)
    }

    private func syncMemoryIfNeeded() async {
        guard let backendAPI = services.backendAPI else { return }
        try? await backendAPI.upsertMemoryItems(memoryItems)
    }

    private func syncScanDecisionIfNeeded(_ decision: ScanDecision) async {
        guard let backendAPI = services.backendAPI else { return }
        try? await backendAPI.saveScanDecision(decision)
    }

    private func refreshInsightsIfNeeded() async {
        guard let backendAPI = services.backendAPI else { return }
        do {
            remoteInsights = try await backendAPI.getWeeklyInsights(userContext: userContext)
        } catch {
            remoteInsights = []
        }
    }

    private func refreshHomeIfNeeded() async {
        guard let backendAPI = services.backendAPI else {
            remoteHomePayload = nil
            return
        }

        do {
            remoteHomePayload = try await backendAPI.fetchDailyHome(
                profile: userProfile,
                activeGoals: activeGoals
            )
        } catch {
            remoteHomePayload = nil
        }
    }

    private func persist() {
        services.store.save(
            StoredAppState(
                hasCompletedOnboarding: hasCompletedOnboarding,
                userContext: userContext,
                history: history,
                checkIns: checkIns,
                subscriptionStatus: subscriptionStatus,
                lastDemoScenarioID: lastDemoScenarioID,
                userProfile: userProfile,
                activeGoals: activeGoals,
                firstWeekPlan: firstWeekPlan,
                routines: routines,
                memoryItems: memoryItems,
                scanDecisions: scanDecisions,
                experiments: experiments,
                conversationThreads: conversationThreads
            )
        )
    }

    private func ensureConversationThread(for entryPoint: StrategistEntryPoint) -> Int {
        if let index = conversationThreads.firstIndex(where: { $0.entryPoint == entryPoint }) {
            return index
        }

        let bootstrap = onboardingPlanner.build(profile: userProfile)
        let thread = ConversationThread(
            title: entryPoint.title,
            entryPoint: entryPoint,
            createdAt: .now,
            updatedAt: .now,
            messages: bootstrap.initialThread.messages
        )
        conversationThreads.insert(thread, at: 0)
        return 0
    }

    private func upsertRoutine(_ routine: RoutineItem) {
        if let index = routines.firstIndex(where: { $0.productID == routine.productID }) {
            routines[index] = routine
        } else {
            routines.insert(routine, at: 0)
        }
    }

    private func upsertExperiment(_ experiment: Experiment) {
        if let index = experiments.firstIndex(where: { $0.title == experiment.title }) {
            experiments[index] = experiment
        } else {
            experiments.insert(experiment, at: 0)
        }
    }

    private func upsertMemoryItem(_ item: MemoryItem) {
        if let index = memoryItems.firstIndex(where: { $0.title == item.title && $0.relatedProductID == item.relatedProductID }) {
            memoryItems[index] = item
        } else {
            memoryItems.insert(item, at: 0)
        }

        if memoryItems.count > 80 {
            memoryItems = Array(memoryItems.prefix(80))
        }
    }

    private func merge(_ existing: FirstWeekPlan?, with planned: FirstWeekPlan) -> FirstWeekPlan {
        guard let existing else { return planned }

        let mergedSteps = planned.steps.map { plannedStep in
            guard let existingStep = existing.steps.first(where: { $0.title == plannedStep.title }) else {
                return plannedStep
            }

            var step = plannedStep
            step.isComplete = existingStep.isComplete
            return step
        }

        return FirstWeekPlan(
            title: planned.title,
            summary: planned.summary,
            steps: mergedSteps
        )
    }

    private func bodySignalSummary(for checkIn: CheckInEntry) -> String {
        "Energy \(checkIn.energy)/5 • Skin \(checkIn.skin)/5 • Bloating \(checkIn.bloatingRelief)/5 • Cravings \(checkIn.cravingControl)/5 • Mood \(checkIn.mood)/5"
    }

    private func decisionNote(for kind: ScanDecisionKind, analysis: ScanAnalysis) -> String {
        switch kind {
        case .saveToRoutine:
            return "Keep \(analysis.resolvedProduct.name) in the likely-repeat shortlist."
        case .avoidForNow:
            return "Give \(analysis.resolvedProduct.name) some distance while the current goal is active."
        case .swapInstead:
            if let alternative = analysis.alternatives.first {
                return "Test \(alternative.productName) instead of \(analysis.resolvedProduct.name)."
            }
            return "Find a softer alternative before repeating \(analysis.resolvedProduct.name)."
        case .askStrategist:
            return "Ask for a more contextual read before deciding."
        case .trackAgain:
            return "Retest \(analysis.resolvedProduct.name) after another real-world use."
        }
    }
}
