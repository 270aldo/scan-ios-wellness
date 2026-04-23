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
            "Use a barcode, label photo, meal snapshot, or menu text before analyzing."
        case .unresolved:
            "Try a brighter label photo, a cleaner barcode, or enough text to make the fallback read directional."
        case .ocrEmpty:
            "The selected image did not return enough readable text. Try a tighter, brighter crop."
        case .ocrFailed:
            "Try a sharper, brighter label photo or switch to manual label text."
        case let .custom(message):
            message
        }
    }
}

struct ScanProductCorrectionCandidate: Identifiable, Equatable {
    var id: String { targetScanEventID }
    let targetScanEventID: String
    let targetProductID: String
    let targetProductName: String
    let sourceTitle: String
    let confidence: ConfidenceLevel
}

struct PresentedScanAnalysisContext {
    let analysis: ScanAnalysis
    let structuredAnalysis: AnalysisEnvelope?
    let verdict: LILADomain.ScanVerdict
    let correction: ScanProductCorrection?
}

@MainActor
@Observable
final class AppModel {
    let services: AppServices

    var selectedTab: AppTab = .home
    var localProfileID: String
    var hasCompletedOnboarding: Bool
    var onboardingDraft: OnboardingDraft?
    var userContext: UserContext
    var userProfile: UserProfile
    var activeGoals: [ActiveGoal]
    var firstWeekPlan: FirstWeekPlan?
    var history: [ScanRecord]
    var checkIns: [CheckInEntry]
    var scanEvents: [ScanEvent]
    var scanVerdicts: [StoredScanVerdict]
    var scanProductCorrections: [ScanProductCorrection]
    var checkInEvents: [CheckInEvent]
    var favoriteItems: [FavoriteItem]
    var consentRecords: [ConsentRecord]
    var routines: [RoutineItem]
    var memoryItems: [MemoryItem]
    var scanDecisions: [ScanDecision]
    var experiments: [Experiment]
    var conversationThreads: [ConversationThread]
    var lastDemoScenarioID: String?
    var latestAnalysis: ScanAnalysis?
    var latestVerdict: LILADomain.ScanVerdict?
    var activeComparison: ProductComparison?
    var scanFeedback: ScanFeedback?
    var isAnalyzing = false
    var subscriptionStatus: SubscriptionStatus
    var patternInsights: [PatternInsight]
    var weeklyNarrative: WeeklyInsightNarrative?
    var pantryItems: [PantryItem]
    var entitlementSnapshot: EntitlementSnapshot
    var activePaywall: PaywallContext?
    var remoteInsights: [WeeklyInsight] = []
    var remoteHomePayload: DailyHomePayload?
    var remoteHomePayloadV2: DailyHomePayloadV2?
    var remoteClientConfig: ClientConfigResponse?
    var backendStatuses: [BackendSurfaceKind: BackendSurfaceStatus]
    var hasAttemptedRemoteInsightsRefresh = false
    var hasAttemptedRemoteHomeRefresh = false
    var bootstrapCompleted = false
    var pendingStrategistReplyMessageIDs = Set<ConversationMessage.ID>()

    private let homeComposer = HomeComposer()
    private let onboardingPlanner = OnboardingPlanner()
    private let contextAssembler = ConversationContextAssembler()
    private let strategistResponseEngine = StrategistResponseEngine()
    private let rootOrchestrator = RootOrchestrator()
    private let accessPolicy = AccessPolicy()
    private let deterministicScanVerdictAgent = DeterministicScanVerdictAgent()
    private let deterministicCoachAgent = DeterministicCoachAgent()
    private var coachReplyTask: Task<Void, Never>?

    init(services: AppServices? = nil) {
        let resolvedServices = services ?? AppServices.makePreviewServices()
        self.services = resolvedServices
        let snapshot = resolvedServices.store.load()
        let derivedProfile = snapshot.userProfile ?? UserProfile.migrated(from: snapshot.userContext)
        let resolvedOnboardingDraft: OnboardingDraft?
        if snapshot.hasCompletedOnboarding {
            resolvedOnboardingDraft = nil
        } else if let snapshotDraft = snapshot.onboardingDraft {
            resolvedOnboardingDraft = snapshotDraft
        } else {
            resolvedOnboardingDraft = OnboardingDraft(profile: derivedProfile)
        }
        let bootstrap = onboardingPlanner.build(profile: derivedProfile)
        let billingMode: BillingMode = resolvedServices.configuration.isStoreKitEnabled ? .storeKit : .demo
        let phaseTwoArtifacts = RootOrchestrator().refreshPhaseTwoArtifacts(
            scanEvents: snapshot.scanEvents.sorted(by: { $0.timestamp > $1.timestamp }),
            checkInEvents: snapshot.checkInEvents.sorted(by: { $0.timestamp > $1.timestamp }),
            favoriteItems: snapshot.favoriteItems.sorted(by: { $0.createdAt > $1.createdAt }),
            routines: snapshot.routines,
            existingPantryItems: snapshot.pantryItems
        )

        localProfileID = snapshot.localProfileID
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        onboardingDraft = resolvedOnboardingDraft
        userContext = derivedProfile.userContext
        userProfile = derivedProfile
        activeGoals = snapshot.activeGoals.isEmpty && snapshot.hasCompletedOnboarding ? bootstrap.activeGoals : snapshot.activeGoals
        firstWeekPlan = snapshot.firstWeekPlan ?? (snapshot.hasCompletedOnboarding ? bootstrap.firstWeekPlan : nil)
        history = snapshot.history.sorted(by: { $0.createdAt > $1.createdAt })
        checkIns = snapshot.checkIns.sorted(by: { $0.createdAt > $1.createdAt })
        scanEvents = snapshot.scanEvents.sorted(by: { $0.timestamp > $1.timestamp })
        scanVerdicts = snapshot.scanVerdicts.sorted(by: { $0.createdAt > $1.createdAt })
        scanProductCorrections = snapshot.scanProductCorrections.sorted(by: { $0.updatedAt > $1.updatedAt })
        checkInEvents = snapshot.checkInEvents.sorted(by: { $0.timestamp > $1.timestamp })
        favoriteItems = snapshot.favoriteItems.sorted(by: { $0.createdAt > $1.createdAt })
        consentRecords = snapshot.consentRecords.sorted(by: { $0.createdAt > $1.createdAt })
        routines = snapshot.routines
        memoryItems = snapshot.memoryItems.isEmpty && snapshot.hasCompletedOnboarding ? bootstrap.seededMemory : snapshot.memoryItems
        scanDecisions = snapshot.scanDecisions.sorted(by: { $0.createdAt > $1.createdAt })
        experiments = snapshot.experiments.sorted(by: { $0.lastUpdatedAt > $1.lastUpdatedAt })
        conversationThreads = snapshot.conversationThreads.isEmpty && snapshot.hasCompletedOnboarding ? [bootstrap.initialThread] : snapshot.conversationThreads
        lastDemoScenarioID = snapshot.lastDemoScenarioID
        subscriptionStatus = snapshot.subscriptionStatus
        patternInsights = phaseTwoArtifacts.patternInsights
        weeklyNarrative = phaseTwoArtifacts.weeklyNarrative
        pantryItems = phaseTwoArtifacts.pantryItems
        entitlementSnapshot = AccessPolicy().snapshot(subscriptionStatus: snapshot.subscriptionStatus, billingMode: billingMode)
        activePaywall = nil
        backendStatuses = initialBackendStatuses(
            hasBackend: resolvedServices.backendAPI != nil,
            hasAgentService: resolvedServices.configuration.hasAgentService
        )
        latestVerdict = nil
        reconcileScanVerdictsIfNeeded()
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

    var featureFlags: WellnessFeatureFlags {
        remoteClientConfig?.flags ?? services.featureFlags
    }

    var backendStatusList: [BackendSurfaceStatus] {
        BackendSurfaceKind.allCases.compactMap { backendStatuses[$0] }
    }

    var hasBackendDebugSurface: Bool {
        services.configuration.isBackendDebugSurfaceEnabled
            || services.configuration.hasBackend
            || services.configuration.hasAgentService
            || remoteClientConfig != nil
            || services.configuration.isFirebaseEnabled
    }

    var backendAuthModeTitle: String {
        if services.configuration.isFirebaseEnabled {
            return services.firebaseBootstrapState == .configured
                ? "Firebase anonymous auth"
                : "Firebase requested, bootstrap not ready"
        }
        return "Local install ID"
    }

    var weeklyInsights: [WeeklyInsight] {
        remoteInsights.isEmpty ? WeeklyInsightEngine().generate(history: history, checkIns: checkIns) : remoteInsights
    }

    var visiblePantryItems: [PantryItem] {
        pantryItems
            .filter { !$0.isArchived }
            .sorted(by: { $0.lastUpdatedAt > $1.lastUpdatedAt })
    }

    var pantrySuggestions: [PantrySuggestion] {
        rootOrchestrator.pantrySuggestions(
            pantryItems: visiblePantryItems,
            patternInsights: patternInsights
        )
    }

    var activeEntitlements: [WellnessEntitlement] {
        entitlementSnapshot.activeEntitlements
    }

    var onboardingPrimaryExitDestination: OnboardingExitDestination {
        hasCompletedOnboarding || !scanEvents.isEmpty || !history.isEmpty ? .checkIn : .scan
    }

    var onboardingSecondaryExitDestination: OnboardingExitDestination {
        onboardingPrimaryExitDestination == .scan ? .checkIn : .scan
    }

    var isUsingLocalHomeFallback: Bool {
        services.backendAPI != nil && hasAttemptedRemoteHomeRefresh && remoteHomePayload == nil
    }

    var isUsingLocalInsightsFallback: Bool {
        services.backendAPI != nil && hasAttemptedRemoteInsightsRefresh && remoteInsights.isEmpty
    }

    var latestRecord: ScanRecord? {
        history.first
    }

    var latestScanEvent: ScanEvent? {
        scanEvents.first
    }

    var latestCheckInEvent: CheckInEvent? {
        checkInEvents.first
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

    var dailyHomePayloadV2: DailyHomePayloadV2 {
        if let remoteHomePayloadV2 {
            return remoteHomePayloadV2
        }

        let legacyPlan = HomeSurfacePlanner().plan(
            payload: dailyHomePayload,
            hasFirstWeekPlan: dailyHomeSurfaceAvailability.hasFirstWeekPlan,
            hasDailyBrief: dailyHomeSurfaceAvailability.hasDailyBrief,
            hasGoals: dailyHomeSurfaceAvailability.hasGoals,
            hasRoutines: dailyHomeSurfaceAvailability.hasRoutines,
            hasPantry: dailyHomeSurfaceAvailability.hasPantry,
            hasSampleReads: dailyHomeSurfaceAvailability.hasSampleReads
        )

        guard featureFlags.homeSurfaceV2 else {
            return DailyHomePayloadV2.legacy(
                payload: dailyHomePayload,
                plan: legacyPlan
            )
        }

        return DailyHomePayloadV2Builder().build(
            payload: dailyHomePayload,
            availability: dailyHomeSurfaceAvailability
        )
    }

    var dailyBrief: DailyBrief {
        rootOrchestrator.composeDailyBrief(
            payload: dailyHomePayload,
            profile: userProfile,
            latestScan: latestScanEvent,
            latestCheckIn: latestCheckInEvent,
            checkInEvents: checkInEvents,
            routines: routines
        )
    }

    func hasAccess(to entitlement: WellnessEntitlement) -> Bool {
        if !featureFlags.entitlementsV2 {
            return true
        }
        return accessPolicy.isUnlocked(entitlement, snapshot: entitlementSnapshot)
    }

    private var dailyHomeSurfaceAvailability: DailyHomeSurfaceAvailability {
        DailyHomeSurfaceAvailability(
            hasFirstWeekPlan: dailyHomePayload.state == .calibrating && firstWeekPlan != nil,
            hasDailyBrief: featureFlags.dailyBrief,
            hasGoals: !activeGoals.isEmpty,
            hasRoutines: !routines.isEmpty,
            hasPantry: featureFlags.pantryMVP && !visiblePantryItems.isEmpty,
            hasSampleReads: !demoScenarioPacks.isEmpty,
            hasUserActivity: !history.isEmpty || !checkIns.isEmpty || !scanEvents.isEmpty || !checkInEvents.isEmpty
        )
    }

    @discardableResult
    func requireAccess(
        to entitlement: WellnessEntitlement,
        surface: PaywallSurface,
        previewLines: [String] = []
    ) -> Bool {
        guard featureFlags.entitlementsV2 else { return true }
        guard !hasAccess(to: entitlement) else { return true }

        if featureFlags.contextualPaywall {
            activePaywall = accessPolicy.paywallContext(
                for: entitlement,
                surface: surface,
                previewLines: previewLines,
                snapshot: entitlementSnapshot
            )
        }
        return false
    }

    func dismissPaywall() {
        activePaywall = nil
    }

    /// Open the paywall sheet for a top-level upgrade (e.g. from Profile), so
    /// the usuaria always sees price, duration, auto-renewal terms, and legal
    /// links before Apple's purchase confirmation runs. Satisfies App Store
    /// Review Guideline 3.1.2(c).
    func presentUpgradePaywall(targetTier: SubscriptionStatus) {
        guard targetTier.rank > subscriptionStatus.rank else { return }
        // Use a canonical entitlement per tier to produce value copy for the
        // sheet. The user may already have other premium features, but this
        // simply selects which paragraph of copy to render.
        let entitlement: WellnessEntitlement
        switch targetTier {
        case .pro:
            entitlement = .pantryMVP
        case .plus:
            entitlement = .patternAgent
        case .free:
            return
        }
        activePaywall = accessPolicy.paywallContext(
            for: entitlement,
            surface: .profile,
            previewLines: [],
            snapshot: entitlementSnapshot
        )
    }

    func purchase(from context: PaywallContext) async {
        subscriptionStatus = await services.subscription.purchase(context.targetTier)
        refreshEntitlementSnapshot()
        persist()
        if hasAccess(to: context.feature) {
            activePaywall = nil
        }
    }

    // `deleteAccount()` lives in `AppModel+AccountDeletion.swift` so this
    // file stays focused on day-to-day mutations. The reset helper below is
    // internal so that extension can call it.

    func resetToFreshState() {
        let snapshot = StoredAppState.fresh()
        let derivedProfile = UserProfile.migrated(from: snapshot.userContext)
        let billingMode: BillingMode = services.configuration.isStoreKitEnabled ? .storeKit : .demo

        selectedTab = .home
        localProfileID = snapshot.localProfileID
        hasCompletedOnboarding = false
        onboardingDraft = OnboardingDraft(profile: derivedProfile)
        userContext = derivedProfile.userContext
        userProfile = derivedProfile
        activeGoals = []
        firstWeekPlan = nil
        history = []
        checkIns = []
        scanEvents = []
        scanVerdicts = []
        scanProductCorrections = []
        checkInEvents = []
        favoriteItems = []
        consentRecords = []
        routines = []
        memoryItems = []
        scanDecisions = []
        experiments = []
        conversationThreads = []
        lastDemoScenarioID = nil
        latestAnalysis = nil
        latestVerdict = nil
        activeComparison = nil
        scanFeedback = nil
        isAnalyzing = false
        subscriptionStatus = .free
        patternInsights = []
        weeklyNarrative = nil
        pantryItems = []
        entitlementSnapshot = accessPolicy.snapshot(
            subscriptionStatus: .free,
            billingMode: billingMode
        )
        activePaywall = nil
        remoteInsights = []
        remoteHomePayload = nil
        remoteHomePayloadV2 = nil
        remoteClientConfig = nil
        backendStatuses = initialBackendStatuses(
            hasBackend: services.backendAPI != nil,
            hasAgentService: services.configuration.hasAgentService
        )
        hasAttemptedRemoteInsightsRefresh = false
        hasAttemptedRemoteHomeRefresh = false
        bootstrapCompleted = false
        pendingStrategistReplyMessageIDs.removeAll()
        coachReplyTask?.cancel()
        coachReplyTask = nil
    }

    var historyTimelineEntries: [HistoryTimelineEntry] {
        let scanEntries: [HistoryTimelineEntry]
        if scanEvents.isEmpty {
            scanEntries = history.map {
                HistoryTimelineEntry(
                    kind: .scan,
                    title: historyScanTitle(for: $0.analysis),
                    summary: $0.analysis.overallSummary,
                    createdAt: $0.createdAt
                )
            }
        } else {
            scanEntries = scanEvents.map {
                HistoryTimelineEntry(
                    kind: .scan,
                    title: historyScanTitle(for: $0),
                    summary: historyScanSummary(for: $0),
                    createdAt: $0.timestamp
                )
            }
        }

        let decisionEntries = scanDecisions.map {
            HistoryTimelineEntry(
                kind: .decision,
                title: $0.kind.title,
                summary: "\($0.productName) • \($0.note)",
                createdAt: $0.createdAt
            )
        }

        let checkInEntries = checkInEvents.map {
            HistoryTimelineEntry(
                kind: .checkIn,
                title: "Body signal",
                summary: bodySignalSummary(for: $0),
                createdAt: $0.timestamp
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

        let memoryEntries = memoryItems
            .filter { meaningfulHistoryMemoryKinds.contains($0.kind) }
            .map {
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
            guard thread.messages.contains(where: { $0.speaker == .user }),
                  let latest = thread.messages.last else { return nil }
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

    func startOnboardingIfNeeded() {
        guard !hasCompletedOnboarding else { return }
        guard onboardingDraft == nil else { return }
        onboardingDraft = OnboardingDraft(profile: userProfile)
        persist()
    }

    @discardableResult
    func resumeOnboarding() -> OnboardingDraft {
        if let onboardingDraft {
            return onboardingDraft
        }

        let draft = OnboardingDraft(profile: userProfile)
        onboardingDraft = draft
        persist()
        return draft
    }

    func updateOnboardingDraft(_ draft: OnboardingDraft) {
        guard !hasCompletedOnboarding else { return }
        var updatedDraft = draft
        updatedDraft.touch()
        onboardingDraft = updatedDraft
        persist()
    }

    func updateOnboardingStep(_ step: OnboardingStep) {
        guard !hasCompletedOnboarding else { return }
        var draft = resumeOnboarding()
        draft.currentStep = step
        updateOnboardingDraft(draft)
    }

    func advanceOnboarding() {
        guard !hasCompletedOnboarding else { return }
        var draft = resumeOnboarding()
        guard let nextStep = draft.currentStep.next else { return }
        draft.currentStep = nextStep
        updateOnboardingDraft(draft)
    }

    func skipOnboardingStep() {
        guard !hasCompletedOnboarding else { return }
        var draft = resumeOnboarding()
        guard draft.currentStep.isSkippable, let nextStep = draft.currentStep.next else { return }
        draft.currentStep = nextStep
        updateOnboardingDraft(draft)
    }

    func discardOnboardingDraft() {
        guard !hasCompletedOnboarding else {
            onboardingDraft = nil
            persist()
            return
        }

        onboardingDraft = OnboardingDraft(profile: userProfile)
        persist()
    }

    func completeOnboarding(with context: UserContext, exitDestination: OnboardingExitDestination? = nil) {
        completeOnboarding(with: UserProfile.migrated(from: context), exitDestination: exitDestination)
    }

    func completeOnboarding(using draft: OnboardingDraft, exitDestination: OnboardingExitDestination) {
        updateOnboardingDraft(draft)
        let profile = draft.formData.makeProfile(createdAt: draft.createdAt)
        completeOnboarding(with: profile, exitDestination: exitDestination)
    }

    func completeOnboarding(with profile: UserProfile, exitDestination: OnboardingExitDestination? = nil) {
        let bootstrap = onboardingPlanner.build(profile: profile)
        userProfile = bootstrap.profile
        userContext = bootstrap.profile.userContext
        hasCompletedOnboarding = true
        onboardingDraft = nil
        activeGoals = bootstrap.activeGoals
        firstWeekPlan = bootstrap.firstWeekPlan
        memoryItems = bootstrap.seededMemory
        conversationThreads = [bootstrap.initialThread]
        upsertConsentRecord(
            ConsentRecord(
                localProfileID: localProfileID,
                policyVersion: "phase1-v1",
                flags: bootstrap.profile.consentFlags,
                createdAt: .now
            )
        )
        refreshPhaseTwoState()
        refreshEntitlementSnapshot()
        if let exitDestination {
            selectedTab = exitDestination.tab
        }
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

    func analyzeMealSnapshot(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        await analyze(
            ScanInput(
                sourceType: .mealPhoto,
                barcode: nil,
                capturedImageRef: nil,
                rawText: trimmed,
                productTypeHint: .food,
                locale: Locale.current.identifier
            )
        )
    }

    func analyzeMenuPhoto(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        await analyze(
            ScanInput(
                sourceType: .menuPhoto,
                barcode: nil,
                capturedImageRef: nil,
                rawText: trimmed,
                productTypeHint: .food,
                locale: Locale.current.identifier
            )
        )
    }

    func runDemoScenario(_ scenario: DemoScenario) async {
        lastDemoScenarioID = scenario.id
        persist()
        await analyze(scenario.scanInput)
    }

    func dismissAnalysis() {
        latestAnalysis = nil
    }

    func requestHealthPermissions() async -> HealthKitAuthorizationReport {
        await services.healthKitService.requestAuthorization(for: userProfile.lilaContext().dataSync)
    }

    func dismissComparison() {
        activeComparison = nil
    }

    func toggleFavorite(for recordID: UUID) {
        guard let index = history.firstIndex(where: { $0.id == recordID }) else { return }
        let analysis = history[index].analysis
        let favoriteID = "favorite-\(recordID.uuidString)"
        let referenceID = favoriteReferenceID(for: analysis, fallbackRecordID: recordID)
        history[index].isFavorite.toggle()
        if history[index].isFavorite {
            upsertFavoriteItem(
                FavoriteItem(
                    id: favoriteID,
                    scanEventID: referenceID,
                    createdAt: .now,
                    title: analysis.resolvedProduct.name,
                    summary: analysis.overallSummary
                )
            )
        } else {
            favoriteItems.removeAll {
                $0.id == favoriteID || $0.scanEventID == recordID.uuidString || $0.scanEventID == referenceID
            }
        }
        refreshPhaseTwoState()
        persist()
        Task {
            if let favorite = favoriteItems.first(where: { $0.id == favoriteID || $0.scanEventID == referenceID }) {
                await syncFavoriteIfNeeded(favorite)
            }
        }
    }

    func addCheckIn(
        energy: Int,
        skin: Int,
        bloatingRelief: Int,
        cravingControl: Int,
        mood: Int,
        note: String,
        satiety: Int = 3,
        readHelpful: Bool? = nil,
        linkedScanIDs: [String]? = nil
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
        let resolvedLinkedScanIDs = linkedScanIDs ?? latestScanEvent.map { [$0.id] } ?? []
        let checkInEvent = checkIn.makeEvent(
            localProfileID: localProfileID,
            linkedScanIDs: resolvedLinkedScanIDs,
            readHelpful: readHelpful,
            satiety: satiety
        )
        checkInEvents.insert(checkInEvent, at: 0)
        let resolvedDecisionIDs = reconcileFollowUpAfterCheckIn(checkInEvent)
        if checkIns.count > 60 {
            checkIns = Array(checkIns.prefix(60))
        }
        if checkInEvents.count > 120 {
            checkInEvents = Array(checkInEvents.prefix(120))
        }

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

        refreshPhaseTwoState()
        persist()
        Task {
            await syncCheckInIfNeeded(checkIn)
            await syncCheckInEventIfNeeded(checkInEvent)
            for resolvedDecisionID in resolvedDecisionIDs {
                if let decision = scanDecisions.first(where: { $0.id == resolvedDecisionID }) {
                    await syncScanDecisionIfNeeded(decision)
                }
            }
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
        refreshEntitlementSnapshot()
        persist()
    }

    func restorePurchases() async {
        subscriptionStatus = await services.subscription.restore()
        refreshEntitlementSnapshot()
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
                ageRange: userProfile.ageRange,
                restaurantFrequency: userProfile.restaurantFrequency,
                nutritionPriorities: userProfile.nutritionPriorities,
                consentFlags: userProfile.consentFlags,
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

        upsertConsentRecord(
            ConsentRecord(
                localProfileID: localProfileID,
                policyVersion: "phase1-v1",
                flags: profile.consentFlags,
                createdAt: .now
            )
        )

        refreshPhaseTwoState()
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
        await refreshClientConfigIfNeeded()
        await syncHistoryIfNeeded()
        refreshEntitlementSnapshot()
        refreshPhaseTwoState()
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
            resolvedAt: kind.keepsLoopOpen ? nil : .now
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

        refreshPhaseTwoState()
        persist()
        Task {
            await syncScanDecisionIfNeeded(decision)
            await syncMemoryIfNeeded()
            await refreshHomeIfNeeded()
        }
    }

    func saveFavorite(from analysis: ScanAnalysis) {
        guard let record = history.first(where: { $0.analysis.id == analysis.id }) else { return }
        let favoriteID = "favorite-\(record.id.uuidString)"
        let referenceID = favoriteReferenceID(for: analysis, fallbackRecordID: record.id)
        if let index = history.firstIndex(where: { $0.id == record.id }) {
            history[index].isFavorite = true
        }
        upsertFavoriteItem(
            FavoriteItem(
                id: favoriteID,
                scanEventID: referenceID,
                createdAt: .now,
                title: analysis.resolvedProduct.name,
                summary: analysis.overallSummary
            )
        )
        refreshPhaseTwoState()
        persist()
        Task {
            if let favorite = favoriteItems.first(where: { $0.id == favoriteID || $0.scanEventID == referenceID }) {
                await syncFavoriteIfNeeded(favorite)
            }
        }
    }

    func saveToPantry(from analysis: ScanAnalysis) {
        let title = analysis.resolvedProduct.name
        let relatedScan = scanEvent(for: analysis)
        let pantryItem = PantryItem(
            id: "pantry-manual-\(relatedScan?.id ?? analysis.id.uuidString)",
            title: title,
            summary: relatedScan?.analysis.whyToday.first ?? analysis.overallSummary,
            relatedProductID: analysis.resolvedProduct.id,
            sourceKind: .manualSave,
            sourceScanID: relatedScan?.id,
            createdAt: .now,
            lastUpdatedAt: .now,
            archivedAt: nil
        )
        upsertPantryItem(pantryItem)
        persist()
    }

    func removePantryItem(_ item: PantryItem) {
        archivePantryItem(item)
        persist()
    }

    func pantryAnalysis(for item: PantryItem) -> ScanAnalysis? {
        if let sourceScanID = item.sourceScanID {
            if let event = scanEvents.first(where: { $0.id == sourceScanID }) {
                return event.legacyAnalysis
            }

            if let recordID = UUID(uuidString: sourceScanID),
               let record = history.first(where: { $0.id == recordID }) {
                return record.analysis
            }
        }

        if let relatedProductID = item.relatedProductID {
            if let event = scanEvents.first(where: {
                ProductGraphIdentity.hasOverlap(
                    [relatedProductID],
                    [$0.legacyAnalysis.resolvedProduct.id, $0.legacyAnalysis.resolvedProduct.stableIdentityKey]
                )
            }) {
                return event.legacyAnalysis
            }

            if let record = history.first(where: {
                ProductGraphIdentity.hasOverlap(
                    [relatedProductID],
                    [$0.analysis.resolvedProduct.id, $0.analysis.resolvedProduct.stableIdentityKey]
                )
            }) {
                return record.analysis
            }
        }

        return history.first(where: {
            $0.analysis.resolvedProduct.name.localizedCaseInsensitiveCompare(item.title) == .orderedSame
        })?.analysis
    }

    func pantryItems(for suggestion: PantrySuggestion) -> [PantryItem] {
        let supportingIDs = Set(suggestion.supportingPantryItemIDs)
        return visiblePantryItems.filter { supportingIDs.contains($0.id) }
    }

    func pantryItemIsInRoutine(_ item: PantryItem) -> Bool {
        if item.sourceKind == .routine {
            return true
        }

        if let relatedProductID = item.relatedProductID,
           routines.contains(where: {
               ProductGraphIdentity.hasOverlap([relatedProductID], [$0.productID])
           }) {
            return true
        }

        if let analysis = pantryAnalysis(for: item),
           routines.contains(where: {
               ProductGraphIdentity.hasOverlap(
                   [$0.productID],
                   [analysis.resolvedProduct.id, analysis.resolvedProduct.stableIdentityKey]
               )
           }) {
            return true
        }

        return routines.contains(where: {
            $0.productName.localizedCaseInsensitiveCompare(item.title) == .orderedSame
        })
    }

    func promotePantryItemToRoutine(_ item: PantryItem) {
        guard !pantryItemIsInRoutine(item) else { return }

        if let analysis = pantryAnalysis(for: item) {
            recordScanDecision(.saveToRoutine, for: analysis)
            return
        }

        guard let relatedProductID = item.relatedProductID else { return }

        scanDecisions.insert(
            ScanDecision(
                createdAt: .now,
                productID: relatedProductID,
                productName: item.title,
                kind: .saveToRoutine,
                note: "Promoted from Pantry to keep a stronger repeat choice easy.",
                relatedGoal: userProfile.userContext.goals.first,
                resolvedAt: nil
            ),
            at: 0
        )
        upsertRoutine(
            RoutineItem(
                productID: relatedProductID,
                productName: item.title,
                cadenceSummary: "Keep as an easy pantry default",
                note: item.summary,
                createdAt: .now
            )
        )
        upsertMemoryItem(
            MemoryItem(
                kind: .staple,
                title: "\(item.title) became a pantry default",
                summary: item.summary,
                relatedProductID: relatedProductID,
                relatedProductName: item.title,
                createdAt: .now,
                lastReferencedAt: .now
            )
        )
        refreshPhaseTwoState()
        persist()
        Task {
            if let decision = scanDecisions.first {
                await syncScanDecisionIfNeeded(decision)
            }
            await syncMemoryIfNeeded()
            await refreshHomeIfNeeded()
        }
    }

    func scanEvent(for analysis: ScanAnalysis) -> ScanEvent? {
        scanEvents.first(where: { $0.legacyAnalysis.id == analysis.id })
    }

    func presentedAnalysisContext(for analysis: ScanAnalysis) -> PresentedScanAnalysisContext {
        guard let sourceEvent = scanEvent(for: analysis) else {
            return PresentedScanAnalysisContext(
                analysis: analysis,
                structuredAnalysis: nil,
                verdict: analysis.lilaVerdict(context: userProfile.lilaContext()),
                correction: nil
            )
        }

        guard
            let correction = scanProductCorrections.first(where: { $0.scanEventID == sourceEvent.id }),
            let correctedContext = materializedCorrectionContext(
                for: sourceEvent,
                correction: correction
            )
        else {
            let structuredAnalysis = sourceEvent.analysis
            let scanContext = sourceEvent.normalizedPayload.scanContext
            let fallbackVerdict = scanVerdicts.first(where: { $0.scanEventID == sourceEvent.id })?.verdict
                ?? structuredAnalysis.lilaVerdict(
                    fallbackAnalysis: analysis,
                    context: userProfile.lilaContext(),
                    scanContext: scanContext
                )
            return PresentedScanAnalysisContext(
                analysis: analysis,
                structuredAnalysis: structuredAnalysis,
                verdict: fallbackVerdict,
                correction: nil
            )
        }

        return correctedContext
    }

    func scanVerdict(for analysis: ScanAnalysis) -> LILADomain.ScanVerdict? {
        presentedAnalysisContext(for: analysis).verdict
    }

    func structuredAnalysis(for analysis: ScanAnalysis) -> AnalysisEnvelope? {
        presentedAnalysisContext(for: analysis).structuredAnalysis
    }

    func supportsManualCorrection(for analysis: ScanAnalysis) -> Bool {
        let semantics = analysis.resolvedProduct.resolvedResolutionSemantics
        return semantics.contains(.provisional)
            || semantics.contains(.directional)
            || semantics.contains(.lowConfidence)
    }

    func manualCorrectionTargets(for analysis: ScanAnalysis) -> [ScanProductCorrectionCandidate] {
        guard let sourceEvent = scanEvent(for: analysis) else { return [] }

        var seenStableProductIDs = Set<String>()
        return scanEvents
            .filter { $0.id != sourceEvent.id }
            .sorted(by: { $0.timestamp > $1.timestamp })
            .compactMap { event in
                let candidateAnalysis = event.legacyAnalysis
                guard isStableCorrectionTarget(candidateAnalysis) else { return nil }

                let stableProductID = candidateAnalysis.resolvedProduct.stableIdentityKey.lowercased()
                guard seenStableProductIDs.insert(stableProductID).inserted else { return nil }

                return ScanProductCorrectionCandidate(
                    targetScanEventID: event.id,
                    targetProductID: candidateAnalysis.resolvedProduct.stableIdentityKey,
                    targetProductName: candidateAnalysis.resolvedProduct.name,
                    sourceTitle: candidateAnalysis.source.title,
                    confidence: candidateAnalysis.confidence
                )
            }
    }

    func applyManualCorrection(for analysis: ScanAnalysis, targetScanEventID: String) {
        guard
            let sourceEvent = scanEvent(for: analysis),
            let targetEvent = scanEvents.first(where: { $0.id == targetScanEventID }),
            isStableCorrectionTarget(targetEvent.legacyAnalysis)
        else {
            return
        }

        let targetAnalysis = targetEvent.legacyAnalysis
        let now = Date()
        let correction = ScanProductCorrection(
            scanEventID: sourceEvent.id,
            targetScanEventID: targetEvent.id,
            targetProductID: targetAnalysis.resolvedProduct.stableIdentityKey,
            targetProductName: targetAnalysis.resolvedProduct.name,
            createdAt: scanProductCorrections.first(where: { $0.scanEventID == sourceEvent.id })?.createdAt ?? now,
            updatedAt: now
        )
        upsertScanProductCorrection(correction)
        refreshLatestVerdict()
        persist()
    }

    func clearManualCorrection(for analysis: ScanAnalysis) {
        guard let sourceEvent = scanEvent(for: analysis) else { return }
        scanProductCorrections.removeAll(where: { $0.scanEventID == sourceEvent.id })
        refreshLatestVerdict()
        persist()
    }

    func leadingPatternInsight(for analysis: ScanAnalysis) -> PatternInsight? {
        guard let event = scanEvent(for: analysis) else {
            return patternInsights.first
        }

        return patternInsights.first(where: { $0.linkedScanIDs.contains(event.id) }) ?? patternInsights.first
    }

    func conversationThread(for entryPoint: StrategistEntryPoint) -> ConversationThread {
        if let index = primaryConversationThreadIndex() {
            return conversationThreads[index]
        }

        return fallbackStrategistThread()
    }

    func isAwaitingStrategistReply(to messageID: ConversationMessage.ID) -> Bool {
        pendingStrategistReplyMessageIDs.contains(messageID)
    }

    func sendStrategistPrompt(
        _ prompt: String,
        entryPoint: StrategistEntryPoint,
        linkedAnalysis: ScanAnalysis? = nil
    ) {
        sendStrategistMessage(prompt, entryPoint: entryPoint, linkedAnalysis: linkedAnalysis)
    }

    func supportedStrategistTab(for action: CoachSuggestedAction) -> AppTab? {
        switch action.type {
        case .scan:
            return .scan
        case .checkIn:
            return .checkIn
        case .viewVerdict, .consultProfessional, .none:
            return nil
        }
    }

    func strategistStarterPrompts(
        for entryPoint: StrategistEntryPoint,
        linkedAnalysis: ScanAnalysis? = nil
    ) -> [String] {
        var prompts = [String]()
        let base = userProfile.userContext.goals.prefix(2).map(\.strategistPrompt)

        if let linkedAnalysis {
            prompts.append("What is the single best next step for \(linkedAnalysis.resolvedProduct.name)?")
            prompts.append("Should I keep, avoid, or retest \(linkedAnalysis.resolvedProduct.name)?")
            if let alternative = linkedAnalysis.alternatives.first {
                prompts.append("Why is \(alternative.productName) the softer swap than \(linkedAnalysis.resolvedProduct.name)?")
            }
        }

        if let weeklyNarrative {
            prompts.append("What decision best protects \(weeklyNarrative.headline.lowercased()) today?")
        }

        if let pattern = patternInsights.first {
            prompts.append("How should I use the \(pattern.signal.title.lowercased()) pattern in my next decision?")
        }

        switch entryPoint {
        case .home:
            prompts.append("What’s the one decision that matters most today?")
        case .scan:
            prompts.append(contentsOf: ["Should this stay in my routine?", "What would be a softer swap?"])
        case .checkIn:
            prompts.append(contentsOf: ["What should I avoid if today already feels off?", "How do I use this body signal well?"])
        case .profile:
            prompts.append(contentsOf: ["What have you learned about me so far?", "What goal should I narrow next?"])
        }

        prompts.append(contentsOf: base)
        return uniquePrompts(prompts)
    }

    func sendStrategistMessage(
        _ text: String,
        entryPoint: StrategistEntryPoint,
        linkedAnalysis: ScanAnalysis? = nil
    ) {
        var threadIndex = ensureConversationThread(for: entryPoint)
        let userMessage = ConversationMessage(
            speaker: .user,
            text: text,
            createdAt: .now
        )
        conversationThreads[threadIndex].messages.append(userMessage)
        conversationThreads[threadIndex].updatedAt = .now
        conversationThreads[threadIndex].title = "Daily strategist"
        conversationThreads[threadIndex].entryPoint = .home
        pendingStrategistReplyMessageIDs.insert(userMessage.id)

        if threadIndex != 0 {
            let primaryThread = conversationThreads.remove(at: threadIndex)
            conversationThreads.insert(primaryThread, at: 0)
            threadIndex = 0
        }

        persist()

        let threadID = conversationThreads[threadIndex].id
        let userMessageID = userMessage.id
        let previousTask = coachReplyTask

        coachReplyTask = Task { @MainActor [weak self] in
            await previousTask?.value
            guard let self else { return }

            let reply = await self.generateCoachReply(
                userMessage: text,
                threadID: threadID,
                userMessageID: userMessageID
            )
            self.insertCoachReply(
                reply,
                threadID: threadID,
                after: userMessageID,
                linkedAnalysis: linkedAnalysis
            )
        }
    }

    private func analyze(_ input: ScanInput) async {
        isAnalyzing = true
        scanFeedback = nil
        defer { isAnalyzing = false }
        let startedAt = Date()

        do {
            let biometrics = await currentBiometricsSnapshotIfAllowed()
            let scanContext = userProfile.scanContext(biometrics: biometrics)
            let analysis = try await services.scanService.analyze(
                input: input,
                userContext: userContext,
                scanContext: scanContext
            )
            latestAnalysis = analysis
            let structuredAnalysis = await preferredStructuredAnalysis(
                for: input,
                legacyAnalysis: analysis,
                scanContext: scanContext
            )
            let event = rootOrchestrator.composeScanEvent(
                input: input,
                legacyAnalysis: analysis,
                structuredAnalysis: structuredAnalysis,
                localProfileID: localProfileID,
                recentScans: scanEvents,
                recentCheckIns: checkInEvents,
                scanContext: scanContext,
                latencyMs: Int(Date().timeIntervalSince(startedAt) * 1000)
            )
            scanEvents.insert(event, at: 0)
            if canUseRemoteAI {
                updateBackendStatus(.scanVerdict, state: .syncPending, detail: "Requesting remote scan verdict.", incrementAttempt: true)
            } else if services.configuration.hasAgentService {
                updateBackendStatus(
                    .scanVerdict,
                    state: .unavailable,
                    detail: "AI processing is off. Using on-device scan verdicts."
                )
            } else {
                updateBackendStatus(.scanVerdict, state: .unavailable, detail: "No agent service configured. Using deterministic local verdicts.")
            }
            let verdict = await generateScanVerdict(
                input: input,
                legacyAnalysis: analysis,
                structuredAnalysis: structuredAnalysis,
                biometrics: biometrics
            )
            if canUseRemoteAI {
                let usedIOSFallback = verdict.reasoningBreakdown.agentInsights.contains {
                    $0.modelUsed.hasPrefix("ios-remote-fallback/")
                }
                if usedIOSFallback {
                    updateBackendStatus(
                        .scanVerdict,
                        state: .fallback,
                        detail: scanVerdictFallbackDetail(verdict),
                        incrementFallback: true
                    )
                } else {
                    let modelUsed = verdict.reasoningBreakdown.agentInsights.first?.modelUsed ?? "agent-service"
                    updateBackendStatus(.scanVerdict, state: .live, detail: "Remote scan verdict applied (\(modelUsed)).")
                }
            }
            latestVerdict = verdict
            scanVerdicts.removeAll(where: { $0.scanEventID == event.id })
            scanVerdicts.insert(
                StoredScanVerdict(scanEventID: event.id, verdict: verdict, createdAt: event.timestamp),
                at: 0
            )
            let recordID = UUID(uuidString: event.id) ?? UUID()
            history.insert(ScanRecord(id: recordID, createdAt: analysis.createdAt, analysis: analysis), at: 0)
            if history.count > 60 {
                history = Array(history.prefix(60))
            }
            if scanEvents.count > 120 {
                scanEvents = Array(scanEvents.prefix(120))
            }
            if scanVerdicts.count > 120 {
                scanVerdicts = Array(scanVerdicts.prefix(120))
            }

            if let planStep = firstWeekPlan?.steps.firstIndex(where: { $0.title.localizedCaseInsensitiveContains("Scan two") }) {
                firstWeekPlan?.steps[planStep].isComplete = scanEvents.count >= 2
            }

            refreshPhaseTwoState()
            persist()
            await services.healthKitService.writeNutritionIfAllowed(
                verdict: verdict,
                preferences: userProfile.lilaContext(biometrics: biometrics).dataSync
            )
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

    private func preferredStructuredAnalysis(
        for input: ScanInput,
        legacyAnalysis: ScanAnalysis,
        scanContext: ScanContext?
    ) async -> AnalysisEnvelope? {
        guard featureFlags.structuredAnalysis, let backendAPI = services.backendAPI else {
            if services.backendAPI == nil {
                updateBackendStatus(.structuredScan, state: .unavailable, detail: "No backend configured. Using deterministic local analysis.")
            }
            return nil
        }

        if remoteClientConfig?.killSwitches.scanDisabled == true {
            updateBackendStatus(
                .structuredScan,
                state: .fallback,
                detail: "Remote structured scan is disabled by client config.",
                incrementAttempt: true,
                incrementFallback: true
            )
            return rootOrchestrator.localStructuredAnalysis(
                input: input,
                legacyAnalysis: legacyAnalysis,
                recentScans: scanEvents,
                recentCheckIns: checkInEvents
            )
        }

        updateBackendStatus(.structuredScan, state: .syncPending, detail: "Requesting remote AnalysisEnvelope.", incrementAttempt: true)
        do {
            let analysis = try await backendAPI.analyzeStructuredScan(
                input: input,
                profile: userProfile,
                recentScans: scanEvents,
                recentCheckIns: checkInEvents,
                scanContext: scanContext
            )
            updateBackendStatus(.structuredScan, state: .live, detail: "Remote AnalysisEnvelope applied.")
            return analysis
        } catch {
            updateBackendStatus(
                .structuredScan,
                state: .fallback,
                detail: backendErrorDetail(prefix: "Structured scan fell back to local analysis.", error: error),
                incrementFallback: true
            )
            return rootOrchestrator.localStructuredAnalysis(
                input: input,
                legacyAnalysis: legacyAnalysis,
                recentScans: scanEvents,
                recentCheckIns: checkInEvents
            )
        }
    }

    private func refreshClientConfigIfNeeded() async {
        guard let backendAPI = services.backendAPI else {
            remoteClientConfig = nil
            updateBackendStatus(.clientConfig, state: .unavailable, detail: "No backend configured in runtime settings.")
            return
        }

        updateBackendStatus(.clientConfig, state: .syncPending, detail: "Fetching runtime client config.", incrementAttempt: true)
        do {
            let config = try await backendAPI.fetchClientConfig()
            remoteClientConfig = config
            updateBackendStatus(
                .clientConfig,
                state: .live,
                detail: "\(config.environment) • \(config.persistenceMode) • auth \(config.firebaseAuthEnforced ? "on" : "off") • app check \(config.appCheckEnforced ? "on" : "off") • agent \(config.agentProviderMode)"
            )
        } catch {
            remoteClientConfig = nil
            updateBackendStatus(
                .clientConfig,
                state: .retryableError,
                detail: backendErrorDetail(prefix: "Client config fetch failed.", error: error)
            )
        }
    }

    private func syncHistoryIfNeeded() async {
        guard let backendAPI = services.backendAPI else {
            updateBackendStatus(.historySync, state: .unavailable, detail: "No backend configured in runtime settings.")
            return
        }

        updateBackendStatus(.historySync, state: .syncPending, detail: "Reconciling local-first history with the backend.", incrementAttempt: true)
        do {
            let response = try await backendAPI.syncHistory(
                scans: scanEvents,
                checkIns: checkInEvents,
                favorites: favoriteItems,
                memoryItems: memoryItems,
                scanDecisions: scanDecisions
            )
            applyHistorySync(response)
            updateBackendStatus(
                .historySync,
                state: .live,
                detail: "Merged \(response.scans.count) scans, \(response.checkIns.count) check-ins, \(response.favorites.count) favorites."
            )
        } catch {
            updateBackendStatus(
                .historySync,
                state: .retryableError,
                detail: backendErrorDetail(prefix: "History sync failed.", error: error)
            )
        }
    }

    private func syncProfileIfNeeded() async {
        guard let backendAPI = services.backendAPI else {
            updateBackendStatus(.profileSync, state: .unavailable, detail: "No backend configured in runtime settings.")
            return
        }

        updateBackendStatus(.profileSync, state: .syncPending, detail: "Syncing onboarding/profile context.", incrementAttempt: true)
        do {
            try await backendAPI.completeOnboarding(
                profile: userProfile,
                activeGoals: activeGoals,
                firstWeekPlan: firstWeekPlan
            )
            updateBackendStatus(.profileSync, state: .live, detail: "Profile and onboarding context synced.")
        } catch {
            updateBackendStatus(
                .profileSync,
                state: .retryableError,
                detail: backendErrorDetail(prefix: "Profile sync failed.", error: error)
            )
        }
    }

    private func syncCheckInIfNeeded(_ checkIn: CheckInEntry) async {
        guard let backendAPI = services.backendAPI else {
            updateBackendStatus(.checkInSync, state: .unavailable, detail: "No backend configured in runtime settings.")
            return
        }

        updateBackendStatus(.checkInSync, state: .syncPending, detail: "Syncing check-in payload.", incrementAttempt: true)
        do {
            try await backendAPI.saveCheckIn(checkIn, userContext: userContext)
            updateBackendStatus(.checkInSync, state: .live, detail: "Check-in synced.")
        } catch {
            updateBackendStatus(
                .checkInSync,
                state: .retryableError,
                detail: backendErrorDetail(prefix: "Check-in sync failed.", error: error)
            )
        }
    }

    private func syncCheckInEventIfNeeded(_ event: CheckInEvent) async {
        guard let backendAPI = services.backendAPI else {
            updateBackendStatus(.checkInSync, state: .unavailable, detail: "No backend configured in runtime settings.")
            return
        }

        updateBackendStatus(.checkInSync, state: .syncPending, detail: "Syncing structured check-in event.", incrementAttempt: true)
        do {
            try await backendAPI.saveCheckInEvent(event)
            updateBackendStatus(.checkInSync, state: .live, detail: "Structured check-in event synced.")
        } catch {
            updateBackendStatus(
                .checkInSync,
                state: .retryableError,
                detail: backendErrorDetail(prefix: "Structured check-in sync failed.", error: error)
            )
        }
    }

    private func syncMemoryIfNeeded() async {
        guard let backendAPI = services.backendAPI else {
            updateBackendStatus(.memorySync, state: .unavailable, detail: "No backend configured in runtime settings.")
            return
        }

        updateBackendStatus(.memorySync, state: .syncPending, detail: "Upserting memory context.", incrementAttempt: true)
        do {
            try await backendAPI.upsertMemoryItems(memoryItems)
            updateBackendStatus(.memorySync, state: .live, detail: "Memory context synced.")
        } catch {
            updateBackendStatus(
                .memorySync,
                state: .retryableError,
                detail: backendErrorDetail(prefix: "Memory sync failed.", error: error)
            )
        }
    }

    private func syncScanDecisionIfNeeded(_ decision: ScanDecision) async {
        guard let backendAPI = services.backendAPI else {
            updateBackendStatus(.decisionSync, state: .unavailable, detail: "No backend configured in runtime settings.")
            return
        }

        updateBackendStatus(.decisionSync, state: .syncPending, detail: "Syncing scan decision.", incrementAttempt: true)
        do {
            try await backendAPI.saveScanDecision(decision)
            updateBackendStatus(.decisionSync, state: .live, detail: "Scan decision synced.")
        } catch {
            updateBackendStatus(
                .decisionSync,
                state: .retryableError,
                detail: backendErrorDetail(prefix: "Scan decision sync failed.", error: error)
            )
        }
    }

    private func syncFavoriteIfNeeded(_ favorite: FavoriteItem) async {
        guard let backendAPI = services.backendAPI else {
            updateBackendStatus(.favoriteSync, state: .unavailable, detail: "No backend configured in runtime settings.")
            return
        }

        updateBackendStatus(.favoriteSync, state: .syncPending, detail: "Syncing favorite.", incrementAttempt: true)
        do {
            try await backendAPI.saveFavoriteItem(favorite)
            updateBackendStatus(.favoriteSync, state: .live, detail: "Favorite synced.")
        } catch {
            updateBackendStatus(
                .favoriteSync,
                state: .retryableError,
                detail: backendErrorDetail(prefix: "Favorite sync failed.", error: error)
            )
        }
    }

    private func refreshInsightsIfNeeded() async {
        hasAttemptedRemoteInsightsRefresh = true
        guard let backendAPI = services.backendAPI else {
            updateBackendStatus(.insights, state: .unavailable, detail: "No backend configured in runtime settings.")
            return
        }

        updateBackendStatus(.insights, state: .syncPending, detail: "Refreshing weekly insights.", incrementAttempt: true)
        do {
            remoteInsights = try await backendAPI.getWeeklyInsights(userContext: userContext)
            updateBackendStatus(.insights, state: .live, detail: "Remote weekly insights applied.")
        } catch {
            remoteInsights = []
            updateBackendStatus(
                .insights,
                state: .fallback,
                detail: backendErrorDetail(prefix: "Insights fell back to local generation.", error: error),
                incrementFallback: true
            )
        }
    }

    private func refreshHomeIfNeeded() async {
        hasAttemptedRemoteHomeRefresh = true
        guard let backendAPI = services.backendAPI else {
            remoteHomePayload = nil
            remoteHomePayloadV2 = nil
            updateBackendStatus(.home, state: .unavailable, detail: "No backend configured in runtime settings.")
            return
        }

        if remoteClientConfig?.killSwitches.homeDisabled == true {
            remoteHomePayload = nil
            remoteHomePayloadV2 = nil
            updateBackendStatus(
                .home,
                state: .fallback,
                detail: "Remote home is disabled by client config.",
                incrementAttempt: true,
                incrementFallback: true
            )
            return
        }

        updateBackendStatus(.home, state: .syncPending, detail: "Refreshing daily home payload.", incrementAttempt: true)
        do {
            let response = try await backendAPI.fetchDailyHome(
                profile: userProfile,
                activeGoals: activeGoals
            )
            remoteHomePayload = response.payload
            remoteHomePayloadV2 = response.payloadV2
            updateBackendStatus(.home, state: .live, detail: "Remote Home payload applied.")
        } catch {
            remoteHomePayload = nil
            remoteHomePayloadV2 = nil
            updateBackendStatus(
                .home,
                state: .fallback,
                detail: backendErrorDetail(prefix: "Home fell back to local composition.", error: error),
                incrementFallback: true
            )
        }
    }

    private func updateBackendStatus(
        _ kind: BackendSurfaceKind,
        state: BackendSurfaceState,
        detail: String,
        incrementAttempt: Bool = false,
        incrementFallback: Bool = false
    ) {
        var status = backendStatuses[kind] ?? BackendSurfaceStatus.initial(
            kind: kind,
            hasBackend: services.backendAPI != nil,
            hasAgentService: services.configuration.hasAgentService
        )
        if incrementAttempt {
            status.attempts += 1
        }
        if incrementFallback {
            status.fallbackCount += 1
        }
        status.state = state
        status.detail = detail
        status.updatedAt = .now
        backendStatuses[kind] = status
    }

    private func backendErrorDetail(prefix: String, error: Error) -> String {
        if let backendError = error as? BackendClientError {
            return "\(prefix) \(backendError.diagnosticSummary)"
        }
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return prefix }
        return "\(prefix) \(message)"
    }

    private func scanVerdictFallbackDetail(_ verdict: LILADomain.ScanVerdict) -> String {
        let prefix = "Remote scan verdict fell back to deterministic on-device generation."
        guard let fallbackInsight = verdict.reasoningBreakdown.agentInsights.first(where: {
            $0.modelUsed.hasPrefix("ios-remote-fallback/")
        }) else {
            return prefix
        }

        let rawReason = fallbackInsight.modelUsed
            .replacingOccurrences(of: "ios-remote-fallback/", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawReason.isEmpty else { return prefix }
        return "\(prefix) \(rawReason)."
    }

    private func applyHistorySync(_ response: HistorySyncResponse) {
        scanEvents = mergeItems(scanEvents, with: response.scans, id: \.id) { $0.timestamp > $1.timestamp }
        checkInEvents = mergeItems(checkInEvents, with: response.checkIns, id: \.id) { $0.timestamp > $1.timestamp }
        favoriteItems = mergeItems(favoriteItems, with: response.favorites, id: \.id) { $0.createdAt > $1.createdAt }
        memoryItems = mergeItems(memoryItems, with: response.memoryItems, id: \.id) { $0.lastReferencedAt > $1.lastReferencedAt }
        scanDecisions = mergeItems(scanDecisions, with: response.scanDecisions, id: \.id) { $0.createdAt > $1.createdAt }
        checkIns = checkInEvents.map(\.legacyEntry).sorted(by: { $0.createdAt > $1.createdAt })
        history = rebuiltHistory(from: scanEvents, favorites: favoriteItems)
        reconcileScanVerdictsIfNeeded()
        refreshPhaseTwoState()
        persist()
    }

    private func rebuiltHistory(from scanEvents: [ScanEvent], favorites: [FavoriteItem]) -> [ScanRecord] {
        let favoriteScanIDs = Set(favorites.map(\.scanEventID))
        return scanEvents.map { event in
            ScanRecord(
                id: UUID(uuidString: event.id) ?? UUID(),
                createdAt: event.legacyAnalysis.createdAt,
                analysis: event.legacyAnalysis,
                isFavorite: favoriteScanIDs.contains(event.id)
            )
        }
        .sorted(by: { $0.createdAt > $1.createdAt })
    }

    private func materializedCorrectionContext(
        for sourceEvent: ScanEvent,
        correction: ScanProductCorrection
    ) -> PresentedScanAnalysisContext? {
        guard
            let targetEvent = scanEvents.first(where: { $0.id == correction.targetScanEventID }),
            isStableCorrectionTarget(targetEvent.legacyAnalysis)
        else {
            return nil
        }

        let sourceAnalysis = sourceEvent.legacyAnalysis
        let targetAnalysis = targetEvent.legacyAnalysis
        let correctedProduct = correctedProduct(
            from: targetAnalysis.resolvedProduct,
            targetConfidence: targetAnalysis.confidence
        )
        let scanContext = sourceEvent.normalizedPayload.scanContext

        var correctedAnalysis = AnalysisEngine().analyze(
            product: correctedProduct,
            userContext: userContext,
            scanContext: scanContext,
            source: sourceAnalysis.source,
            confidence: targetAnalysis.confidence,
            catalog: SampleCatalog.products
        )
        correctedAnalysis.id = sourceAnalysis.id
        correctedAnalysis.createdAt = sourceAnalysis.createdAt

        var correctedEnvelope = correctedAnalysis.makeEnvelope(
            input: correctionScanInput(
                sourceEvent: sourceEvent,
                sourceAnalysis: sourceAnalysis,
                correctedProduct: correctedProduct
            ),
            recentScans: scanEvents.filter { $0.id != sourceEvent.id },
            recentCheckIns: checkInEvents
        )
        correctedEnvelope.analysisID = sourceEvent.analysis.analysisID
        correctedEnvelope.timestamp = sourceEvent.analysis.timestamp
        correctedEnvelope.resolvedProduct = correctedProduct

        let correctedVerdict = correctedEnvelope.lilaVerdict(
            fallbackAnalysis: correctedAnalysis,
            context: userProfile.lilaContext(),
            scanContext: scanContext
        )

        return PresentedScanAnalysisContext(
            analysis: correctedAnalysis,
            structuredAnalysis: correctedEnvelope,
            verdict: correctedVerdict,
            correction: correction
        )
    }

    private func correctedProduct(
        from targetProduct: ProductCandidate,
        targetConfidence: ConfidenceLevel
    ) -> ProductCandidate {
        var correctedProduct = targetProduct
        let explicitSemantics = targetProduct.resolvedResolutionSemantics
        let targetResolution = targetProduct.resolution ?? ProductResolution(
            canonicalProductID: targetProduct.stableIdentityKey,
            source: .userEdited,
            confidence: targetConfidence.numericValue,
            nutritionSnapshot: nil,
            isDirectional: false
        )

        correctedProduct.resolution = ProductResolution(
            canonicalProductID: targetResolution.canonicalProductID ?? targetProduct.stableIdentityKey,
            source: .userEdited,
            confidence: targetResolution.confidence,
            nutritionSnapshot: targetResolution.nutritionSnapshot,
            isDirectional: false
        )
        correctedProduct.resolutionSemantics = explicitSemantics
        correctedProduct.notes = (targetProduct.notes + ["Locally corrected to a recent stable product identity."])
            .reduce(into: [String]()) { partialResult, note in
                guard partialResult.contains(note) == false else { return }
                partialResult.append(note)
            }
        return correctedProduct
    }

    private func correctionScanInput(
        sourceEvent: ScanEvent,
        sourceAnalysis: ScanAnalysis,
        correctedProduct: ProductCandidate
    ) -> ScanInput {
        let fallbackRawText = sourceEvent.normalizedPayload.extractedText
            ?? sourceAnalysis.resolvedProduct.ingredients.map(\.name).joined(separator: ", ")
        return ScanInput(
            sourceType: sourceAnalysis.source,
            barcode: sourceAnalysis.resolvedProduct.barcode ?? correctedProduct.barcode,
            capturedImageRef: nil,
            rawText: fallbackRawText.isEmpty ? nil : fallbackRawText,
            productTypeHint: correctedProduct.productType,
            locale: Locale.current.identifier
        )
    }

    private func isStableCorrectionTarget(_ analysis: ScanAnalysis) -> Bool {
        let semantics = analysis.resolvedProduct.resolvedResolutionSemantics
        return !semantics.contains(.provisional)
            && !semantics.contains(.directional)
            && !semantics.contains(.lowConfidence)
    }

    private func upsertScanProductCorrection(_ correction: ScanProductCorrection) {
        if let index = scanProductCorrections.firstIndex(where: { $0.scanEventID == correction.scanEventID }) {
            scanProductCorrections[index] = correction
        } else {
            scanProductCorrections.insert(correction, at: 0)
        }
        scanProductCorrections.sort(by: { $0.updatedAt > $1.updatedAt })
    }

    private func refreshLatestVerdict() {
        guard let latestEvent = scanEvents.first else {
            latestVerdict = nil
            return
        }

        if
            let correction = scanProductCorrections.first(where: { $0.scanEventID == latestEvent.id }),
            let correctedContext = materializedCorrectionContext(for: latestEvent, correction: correction)
        {
            latestVerdict = correctedContext.verdict
            return
        }

        latestVerdict = scanVerdicts.first(where: { $0.scanEventID == latestEvent.id })?.verdict
            ?? latestEvent.analysis.lilaVerdict(
                fallbackAnalysis: latestEvent.legacyAnalysis,
                context: userProfile.lilaContext(),
                scanContext: latestEvent.normalizedPayload.scanContext
            )
    }

    private func mergeItems<Item, Identifier: Hashable>(
        _ local: [Item],
        with remote: [Item],
        id: KeyPath<Item, Identifier>,
        sort: (Item, Item) -> Bool
    ) -> [Item] {
        var merged: [Identifier: Item] = Dictionary(uniqueKeysWithValues: local.map { ($0[keyPath: id], $0) })
        for item in remote {
            merged[item[keyPath: id]] = item
        }
        return Array(merged.values).sorted(by: sort)
    }

    private func persist() {
        services.store.save(
            StoredAppState(
                schemaVersion: 7,
                localProfileID: localProfileID,
                hasCompletedOnboarding: hasCompletedOnboarding,
                onboardingDraft: onboardingDraft,
                userContext: userContext,
                history: history,
                checkIns: checkIns,
                scanEvents: scanEvents,
                scanVerdicts: scanVerdicts,
                scanProductCorrections: scanProductCorrections,
                checkInEvents: checkInEvents,
                favoriteItems: favoriteItems,
                consentRecords: consentRecords,
                subscriptionStatus: subscriptionStatus,
                lastDemoScenarioID: lastDemoScenarioID,
                userProfile: userProfile,
                activeGoals: activeGoals,
                firstWeekPlan: firstWeekPlan,
                routines: routines,
                memoryItems: memoryItems,
                scanDecisions: scanDecisions,
                experiments: experiments,
                conversationThreads: conversationThreads,
                patternInsights: patternInsights,
                weeklyNarrative: weeklyNarrative,
                pantryItems: pantryItems,
                entitlementSnapshot: entitlementSnapshot
            )
        )
    }

    private var canUseRemoteAI: Bool {
        userProfile.consentFlags.aiProcessing && services.configuration.hasAgentService
    }

    private func currentBiometricsSnapshotIfAllowed() async -> BiometricsSnapshot? {
        guard userProfile.consentFlags.healthDataProcessing else {
            return nil
        }

        return await services.healthKitService.currentSnapshot(for: userProfile)
    }

    private func generateScanVerdict(
        input: ScanInput,
        legacyAnalysis: ScanAnalysis,
        structuredAnalysis: AnalysisEnvelope?,
        biometrics: BiometricsSnapshot?
    ) async -> LILADomain.ScanVerdict {
        let request = ScanVerdictRequest(
            input: input,
            legacyAnalysis: legacyAnalysis,
            structuredAnalysis: structuredAnalysis,
            profile: userProfile,
            recentScans: scanEvents,
            recentCheckIns: checkInEvents,
            biometrics: biometrics
        )

        if userProfile.consentFlags.aiProcessing {
            return await services.scanVerdictAgent.generateVerdict(for: request)
        }

        return await deterministicScanVerdictAgent.generateVerdict(for: request)
    }

    private func reconcileScanVerdictsIfNeeded() {
        let context = userProfile.lilaContext()
        let knownIDs = Set(scanVerdicts.map(\.scanEventID))
        let missingEvents = scanEvents.filter { !knownIDs.contains($0.id) }

        if !missingEvents.isEmpty {
            let synthesized = missingEvents.map { event in
                StoredScanVerdict(
                    scanEventID: event.id,
                    verdict: event.analysis.lilaVerdict(
                        fallbackAnalysis: event.legacyAnalysis,
                        context: context,
                        scanContext: event.normalizedPayload.scanContext
                    ),
                    createdAt: event.timestamp
                )
            }
            scanVerdicts = (scanVerdicts + synthesized).sorted(by: { $0.createdAt > $1.createdAt })
        } else {
            scanVerdicts.sort(by: { $0.createdAt > $1.createdAt })
        }

        if scanVerdicts.count > 120 {
            scanVerdicts = Array(scanVerdicts.prefix(120))
        }
        refreshLatestVerdict()
    }

    private func ensureConversationThread(for _: StrategistEntryPoint) -> Int {
        if let index = primaryConversationThreadIndex() {
            return index
        }

        let thread = fallbackStrategistThread()
        conversationThreads.insert(thread, at: 0)
        return 0
    }

    private func generateCoachReply(
        userMessage: String,
        threadID: ConversationThread.ID,
        userMessageID: ConversationMessage.ID
    ) async -> CoachReply {
        let biometrics = await currentBiometricsSnapshotIfAllowed()
        let thread = conversationThreads.first(where: { $0.id == threadID }) ?? fallbackStrategistThread()

        let request = CoachAgentRequest(
            userMessage: userMessage,
            profile: userProfile,
            biometrics: biometrics,
            latestVerdict: latestVerdict,
            recentVerdicts: Array(scanVerdicts.prefix(5).map(\.verdict)),
            recentCheckIns: Array(checkInEvents.prefix(3)),
            memorySummaries: Array(memoryItems.prefix(5).map(\.summary)),
            patternInsights: Array(patternInsights.prefix(3).map { "\($0.title): \($0.summary)" }),
            threadHistory: coachThreadHistory(for: thread, through: userMessageID)
        )

        if userProfile.consentFlags.aiProcessing {
            return await services.coachAgent.generateReply(for: request)
        }

        return await deterministicCoachAgent.generateReply(for: request)
    }

    private func coachThreadHistory(
        for thread: ConversationThread,
        through userMessageID: ConversationMessage.ID
    ) -> [CoachThreadTurn] {
        let scopedMessages: ArraySlice<ConversationMessage>
        if let endIndex = thread.messages.firstIndex(where: { $0.id == userMessageID }) {
            scopedMessages = thread.messages.prefix(endIndex + 1).suffix(10)
        } else {
            scopedMessages = thread.messages.suffix(10)
        }

        return scopedMessages.map {
            CoachThreadTurn(
                role: $0.speaker == .user ? "user" : "assistant",
                content: $0.coachHistoryText,
                timestamp: $0.createdAt
            )
        }
    }

    private func insertCoachReply(
        _ reply: CoachReply,
        threadID: ConversationThread.ID,
        after userMessageID: ConversationMessage.ID,
        linkedAnalysis: ScanAnalysis?
    ) {
        defer {
            pendingStrategistReplyMessageIDs.remove(userMessageID)
        }

        guard let threadIndex = conversationThreads.firstIndex(where: { $0.id == threadID }) else { return }

        let message = ConversationMessage(
            speaker: .strategist,
            text: reply.message,
            createdAt: reply.createdAt,
            citedMemoryIDs: [],
            coachPayload: ConversationMessageCoachPayload(reply: reply)
        )

        if let userIndex = conversationThreads[threadIndex].messages.firstIndex(where: { $0.id == userMessageID }) {
            conversationThreads[threadIndex].messages.insert(message, at: userIndex + 1)
        } else {
            conversationThreads[threadIndex].messages.append(message)
        }
        conversationThreads[threadIndex].updatedAt = reply.createdAt

        if linkedAnalysis != nil {
            upsertMemoryItem(
                MemoryItem(
                    kind: .strategistTakeaway,
                    title: "Strategist takeaway",
                    summary: reply.message,
                    relatedProductID: linkedAnalysis?.resolvedProduct.id,
                    relatedProductName: linkedAnalysis?.resolvedProduct.name,
                    createdAt: reply.createdAt,
                    lastReferencedAt: reply.createdAt
                )
            )
        }

        persist()
    }

    private func primaryConversationThreadIndex() -> Int? {
        conversationThreads.enumerated().max { lhs, rhs in
            let lhsHasUserMessages = lhs.element.messages.contains(where: { $0.speaker == .user })
            let rhsHasUserMessages = rhs.element.messages.contains(where: { $0.speaker == .user })
            if lhsHasUserMessages != rhsHasUserMessages {
                return !lhsHasUserMessages && rhsHasUserMessages
            }
            return lhs.element.updatedAt < rhs.element.updatedAt
        }?.offset
    }

    private func fallbackStrategistThread() -> ConversationThread {
        let fallback = onboardingPlanner.build(profile: userProfile).initialThread
        return ConversationThread(
            title: "Daily strategist",
            entryPoint: .home,
            createdAt: .now,
            updatedAt: .now,
            messages: fallback.messages
        )
    }

    private func uniquePrompts(_ prompts: [String]) -> [String] {
        var seen = Set<String>()
        var unique = [String]()

        for prompt in prompts {
            guard !prompt.isEmpty, seen.insert(prompt).inserted else { continue }
            unique.append(prompt)
            if unique.count == 4 {
                break
            }
        }

        return unique
    }

    private func reconcileFollowUpAfterCheckIn(_ checkInEvent: CheckInEvent) -> [ScanDecision.ID] {
        guard checkInEvent.linkedScanIDs.isEmpty == false else { return [] }

        let linkedEvents = scanEvents.filter { checkInEvent.linkedScanIDs.contains($0.id) }
        guard linkedEvents.isEmpty == false else { return [] }

        let timestamp = checkInEvent.timestamp
        let linkedProductIDs = Set(linkedEvents.map(\.legacyAnalysis.resolvedProduct.id))
        var resolvedDecisionIDs = [ScanDecision.ID]()

        for index in scanDecisions.indices {
            guard scanDecisions[index].resolvedAt == nil else { continue }
            guard scanDecisions[index].kind.keepsLoopOpen else { continue }
            guard linkedProductIDs.contains(scanDecisions[index].productID) else { continue }

            scanDecisions[index].resolvedAt = timestamp
            resolvedDecisionIDs.append(scanDecisions[index].id)
        }

        for index in experiments.indices {
            guard experiments[index].status == .active else { continue }
            let experimentTitle = experiments[index].title
            let matchesLinkedProduct = linkedEvents.contains { event in
                experimentTitle.localizedCaseInsensitiveContains(event.legacyAnalysis.resolvedProduct.name)
            }
            guard matchesLinkedProduct else { continue }
            experiments[index].status = .learned
            experiments[index].lastUpdatedAt = timestamp
        }

        guard let readHelpful = checkInEvent.readHelpful else {
            return resolvedDecisionIDs
        }

        for linkedEvent in linkedEvents {
            let analysis = linkedEvent.legacyAnalysis
            let productID = analysis.resolvedProduct.id
            let productName = analysis.resolvedProduct.name

            if readHelpful {
                upsertMemoryItem(
                    MemoryItem(
                        kind: .experimentWin,
                        title: "\(productName) held up in real use",
                        summary: "The follow-up check-in supported keeping \(productName) closer to your repeat choices.",
                        relatedProductID: productID,
                        relatedProductName: productName,
                        createdAt: timestamp,
                        lastReferencedAt: timestamp
                    )
                )

                if let routineIndex = routines.firstIndex(where: { $0.productID == productID }) {
                    routines[routineIndex].cadenceSummary = "Confirmed by a recent body-signal check-in"
                    routines[routineIndex].note = "This still looked supportive after a real-world follow-up."
                }
            } else {
                upsertMemoryItem(
                    MemoryItem(
                        kind: .experimentCaution,
                        title: "\(productName) still needs a cleaner repeat",
                        summary: "The follow-up check-in did not confirm this as a reliable default yet.",
                        relatedProductID: productID,
                        relatedProductName: productName,
                        createdAt: timestamp,
                        lastReferencedAt: timestamp
                    )
                )

                upsertExperiment(
                    Experiment(
                        title: "Retest \(productName)",
                        hypothesis: "Use one calmer, cleaner repeat before letting \(productName) earn routine space.",
                        status: .active,
                        relatedGoal: userProfile.userContext.goals.first,
                        createdAt: timestamp,
                        lastUpdatedAt: timestamp
                    )
                )
            }
        }

        return resolvedDecisionIDs
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

    private func upsertFavoriteItem(_ item: FavoriteItem) {
        if let index = favoriteItems.firstIndex(where: { $0.id == item.id || $0.scanEventID == item.scanEventID }) {
            favoriteItems[index] = item
        } else {
            favoriteItems.insert(item, at: 0)
        }
    }

    private func upsertPantryItem(_ item: PantryItem) {
        if let index = pantryItems.firstIndex(where: { $0.dedupeKey == item.dedupeKey }) {
            pantryItems[index] = item
        } else {
            pantryItems.insert(item, at: 0)
        }

        if pantryItems.count > 40 {
            pantryItems = Array(pantryItems.prefix(40))
        }
    }

    private func archivePantryItem(_ item: PantryItem) {
        guard let index = pantryItems.firstIndex(where: { $0.id == item.id || $0.dedupeKey == item.dedupeKey }) else { return }
        pantryItems[index].archivedAt = .now
        pantryItems[index].lastUpdatedAt = .now
    }

    private func favoriteReferenceID(for analysis: ScanAnalysis, fallbackRecordID: UUID) -> String {
        scanEvent(for: analysis)?.id ?? fallbackRecordID.uuidString
    }

    private func upsertConsentRecord(_ record: ConsentRecord) {
        if let index = consentRecords.firstIndex(where: { $0.policyVersion == record.policyVersion }) {
            consentRecords[index] = record
        } else {
            consentRecords.insert(record, at: 0)
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

    private func refreshEntitlementSnapshot(now: Date = .now) {
        let billingMode: BillingMode = services.configuration.isStoreKitEnabled ? .storeKit : .demo
        entitlementSnapshot = accessPolicy.snapshot(
            subscriptionStatus: subscriptionStatus,
            billingMode: billingMode,
            now: now
        )
    }

    private func refreshPhaseTwoState() {
        let artifacts = rootOrchestrator.refreshPhaseTwoArtifacts(
            scanEvents: scanEvents,
            checkInEvents: checkInEvents,
            favoriteItems: favoriteItems,
            routines: routines,
            existingPantryItems: pantryItems
        )
        patternInsights = artifacts.patternInsights
        weeklyNarrative = artifacts.weeklyNarrative
        pantryItems = artifacts.pantryItems
    }

    private func bodySignalSummary(for checkIn: CheckInEntry) -> String {
        "Energy \(checkIn.energy)/5 • Skin \(checkIn.skin)/5 • Bloating \(checkIn.bloatingRelief)/5 • Cravings \(checkIn.cravingControl)/5 • Mood \(checkIn.mood)/5"
    }

    private func bodySignalSummary(for checkIn: CheckInEvent) -> String {
        "Energy \(checkIn.energy)/5 • Skin \(checkIn.skin)/5 • Bloating \(checkIn.bloating)/5 • Cravings \(checkIn.cravings)/5 • Mood \(checkIn.mood)/5 • Satiety \(checkIn.satiety)/5"
    }

    private var meaningfulHistoryMemoryKinds: Set<MemoryItemKind> {
        [.staple, .avoid, .checkInPattern, .scanDecision, .experimentWin, .experimentCaution]
    }

    private func historyScanTitle(for event: ScanEvent) -> String {
        switch event.analysis.entityType {
        case .meal:
            return "Meal Snapshot"
        case .menuItem:
            return "Menu Scanner"
        default:
            return event.legacyAnalysis.resolvedProduct.name
        }
    }

    private func historyScanTitle(for analysis: ScanAnalysis) -> String {
        switch analysis.source {
        case .mealPhoto:
            return "Meal Snapshot"
        case .menuPhoto:
            return "Menu Scanner"
        default:
            return analysis.resolvedProduct.name
        }
    }

    private func historyScanSummary(for event: ScanEvent) -> String {
        "\(historyVerdictTitle(for: event.analysis.verdict)) • \(event.analysis.whyToday.first ?? event.legacyAnalysis.overallSummary)"
    }

    private func historyVerdictTitle(for verdict: AnalysisVerdict) -> String {
        switch verdict {
        case .good:
            return "Strong fit"
        case .adjust:
            return "Adjustable fit"
        case .avoid:
            return "Lower-fit choice"
        case .needsMoreInfo:
            return "Needs more input"
        }
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
