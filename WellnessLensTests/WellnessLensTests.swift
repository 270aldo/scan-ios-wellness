import XCTest
@testable import WellnessLens

final class WellnessLensTests: XCTestCase {
    private struct LegacyStoredAppState: Codable {
        var hasCompletedOnboarding: Bool
        var userContext: UserContext
        var history: [ScanRecord]
        var checkIns: [CheckInEntry]
        var subscriptionStatus: SubscriptionStatus
        var lastDemoScenarioID: String?
        var userProfile: UserProfile?
        var activeGoals: [ActiveGoal]
        var firstWeekPlan: FirstWeekPlan?
        var routines: [RoutineItem]
        var memoryItems: [MemoryItem]
        var scanDecisions: [ScanDecision]
        var experiments: [Experiment]
        var conversationThreads: [ConversationThread]
    }

    private final class InMemoryStore: AppDataStore {
        var snapshot: StoredAppState

        init(snapshot: StoredAppState = .fresh()) {
            self.snapshot = snapshot
        }

        func load() -> StoredAppState {
            snapshot
        }

        func save(_ state: StoredAppState) {
            snapshot = state
        }
    }

    private struct StubScanService: ScanService {
        let featuredProducts: [ProductCandidate]
        let analysis: ScanAnalysis

        init(analysis: ScanAnalysis) {
            self.analysis = analysis
            featuredProducts = Array(SampleCatalog.products.prefix(5))
        }

        func analyze(input: ScanInput, userContext: UserContext) async throws -> ScanAnalysis {
            analysis
        }
    }

    private final class MockBackendAPI: WellnessBackendAPI, @unchecked Sendable {
        enum MockError: Error {
            case structuredUnavailable
        }

        var structuredAnalysisResult: Result<AnalysisEnvelope, Error>
        private(set) var analyzeStructuredScanCalls = 0

        init(structuredAnalysisResult: Result<AnalysisEnvelope, Error>) {
            self.structuredAnalysisResult = structuredAnalysisResult
        }

        func analyzeProduct(input: ScanInput, userContext: UserContext) async throws -> ScanAnalysis {
            throw MockError.structuredUnavailable
        }

        func analyzeStructuredScan(
            input: ScanInput,
            profile: UserProfile,
            recentScans: [ScanEvent],
            recentCheckIns: [CheckInEvent]
        ) async throws -> AnalysisEnvelope {
            analyzeStructuredScanCalls += 1
            return try structuredAnalysisResult.get()
        }

        func resolveScan(input: ScanInput) async throws -> ResolveScanResponse {
            throw MockError.structuredUnavailable
        }

        func compareProducts(left: ScanAnalysis, right: ScanAnalysis) async throws -> ProductComparison {
            throw MockError.structuredUnavailable
        }

        func saveCheckIn(_ checkIn: CheckInEntry, userContext: UserContext) async throws {}

        func saveCheckInEvent(_ event: CheckInEvent) async throws {}

        func completeOnboarding(
            profile: UserProfile,
            activeGoals: [ActiveGoal],
            firstWeekPlan: FirstWeekPlan?
        ) async throws {}

        func getWeeklyInsights(userContext: UserContext) async throws -> [WeeklyInsight] {
            []
        }

        func fetchDailyHome(profile: UserProfile, activeGoals: [ActiveGoal]) async throws -> DailyHomeResponse {
            DailyHomeResponse(
                payload: DailyHomePayload(
                    state: .calibrating,
                    todayFocus: TodayFocus(title: "Calibrate", summary: "Start with signal."),
                    bodySignal: CheckInSignal(title: "No fresh body signal yet", summary: "Add one signal.", tone: .neutral),
                    nextAction: Recommendation(
                        id: "scan-staple",
                        kind: .scanStaple,
                        title: "Scan a staple",
                        summary: "Start with a real decision.",
                        cta: "Open scan",
                        relatedProductID: nil,
                        relatedGoal: nil
                    ),
                    recommendedSwap: nil,
                    openLoops: [],
                    strategistNote: StrategistNote(title: "Note", summary: "One note."),
                    recentWins: []
                ),
                payloadV2: nil
            )
        }

        func fetchDailyBrief(profile: UserProfile, activeGoals: [ActiveGoal]) async throws -> DailyBrief {
            DailyBrief(
                headline: "Headline",
                riskHeadline: "Risk",
                nutritionPriority: "Priority",
                cta: DailyBriefAction(kind: .scanBreakfast, title: "Scan", subtitle: "Scan something real."),
                notificationCopy: "Notification"
            )
        }

        func fetchHistoryEvents() async throws -> HistoryEventsResponse {
            HistoryEventsResponse(scans: [], checkIns: [], favorites: [])
        }

        func listAlternatives(for analysis: ScanAnalysis, userContext: UserContext) async throws -> [AlternativeSuggestion] {
            []
        }

        func saveScanDecision(_ decision: ScanDecision) async throws {}

        func saveFavoriteItem(_ favorite: FavoriteItem) async throws {}

        func upsertMemoryItems(_ memoryItems: [MemoryItem]) async throws {}
    }

    private func makeAnalysis(
        barcode: String,
        source: ScanSource = .manualBarcode,
        confidence: ConfidenceLevel = .high
    ) -> ScanAnalysis {
        let product = SampleCatalog.products.first(where: { $0.barcode == barcode }) ?? SampleCatalog.products[0]
        return AnalysisEngine().analyze(
            product: product,
            userContext: .starter,
            source: source,
            confidence: confidence,
            catalog: SampleCatalog.products
        )
    }

    private func makeEnvelope(
        verdict: AnalysisVerdict,
        overallScore: Int,
        entityType: AnalysisEntityType = .product
    ) -> AnalysisEnvelope {
        AnalysisEnvelope(
            analysisID: UUID().uuidString,
            timestamp: .now,
            inputType: .barcode,
            entityType: entityType,
            verdict: verdict,
            overallScore: overallScore,
            lensScores: StructuredLensScores(skin: 80, hormones: 72, gut: 78, energy: 84, bodyComp: 76),
            whyToday: ["Primary context for today.", "Secondary context."],
            greenFlags: ["Green flag"],
            redFlags: ["Red flag"],
            recommendedActions: ["First recommended action.", "Second recommended action."],
            swapSuggestions: [],
            followUpPrompt: "Did this match how the choice felt?",
            confidence: 0.82,
            medicalSafety: MedicalSafety(isMedicalAdvice: false, disclaimerNeeded: true, riskLevel: .low),
            patternContext: PatternContext(usedHistory: true, relevantPattern: "Recent pattern")
        )
    }

    @MainActor
    private func makeServices(
        store: InMemoryStore = InMemoryStore(),
        subscriptionStatus: SubscriptionStatus = .free,
        featureFlags: WellnessFeatureFlags = WellnessFeatureFlags(),
        scanService: ScanService? = nil,
        backendAPI: WellnessBackendAPI? = nil
    ) -> AppServices {
        store.snapshot.subscriptionStatus = subscriptionStatus

        return AppServices(
            configuration: RuntimeConfiguration(
                backendBaseURL: nil,
                isFirebaseEnabled: false,
                isStoreKitEnabled: false,
                useDemoData: true,
                useAppCheckDebugProvider: false,
                plusProductID: nil,
                proProductID: nil
            ),
            featureFlags: featureFlags,
            store: store,
            scanService: scanService ?? DemoScanService(),
            subscription: DemoSubscriptionController(status: subscriptionStatus),
            labelOCRService: LabelOCRService(),
            backendAPI: backendAPI,
            identityProvider: LocalInstallIdentityProvider()
        )
    }

    func testDemoScenarioCatalogShipsThreePacks() {
        XCTAssertEqual(DemoScenarioCatalog.packs.count, 3)
        XCTAssertEqual(DemoScenarioCatalog.packs.map(\.kind), [.food, .supplement, .skincarePersonalCare])
        XCTAssertTrue(DemoScenarioCatalog.packs.allSatisfy { !$0.scenarios.isEmpty })
    }

    func testEnergyDrinkScoresPoorlyForEnergyAndHormones() async throws {
        let service = DemoScanService()
        let result = try await service.analyze(
            input: ScanInput(
                sourceType: .manualBarcode,
                barcode: "850000002",
                capturedImageRef: nil,
                rawText: nil,
                productTypeHint: nil,
                locale: "en_US"
            ),
            userContext: .starter
        )

        let energyScore = result.lensScores.first(where: { $0.lens == .energyMood })?.score ?? 0
        let hormoneScore = result.lensScores.first(where: { $0.lens == .hormoneBalance })?.score ?? 0

        XCTAssertLessThan(energyScore, 55)
        XCTAssertLessThan(hormoneScore, 55)
        XCTAssertFalse(result.alternatives.isEmpty)
    }

    func testBarrierSerumScoresWellForGlowSkin() async throws {
        let service = DemoScanService()
        let result = try await service.analyze(
            input: ScanInput(
                sourceType: .manualBarcode,
                barcode: "850000006",
                capturedImageRef: nil,
                rawText: nil,
                productTypeHint: nil,
                locale: "en_US"
            ),
            userContext: .starter
        )

        let glowScore = result.lensScores.first(where: { $0.lens == .glowSkin })?.score ?? 0
        XCTAssertGreaterThan(glowScore, 80)
        XCTAssertTrue(result.topReasons.contains(where: { $0.impact == .positive }))
    }

    func testSkincareLabelScenarioResolvesToGlowFriendlyRead() async throws {
        let service = DemoScanService()
        let scenario = try XCTUnwrap(DemoScenarioCatalog.scenario(id: "topical-serum-label"))
        let result = try await service.analyze(
            input: scenario.scanInput,
            userContext: .starter
        )

        let glowScore = result.lensScores.first(where: { $0.lens == .glowSkin })?.score ?? 0
        XCTAssertGreaterThan(glowScore, 75)
        XCTAssertEqual(result.source, .manualLabel)
    }

    func testWeeklyInsightEngineHighlightsSoftGutWindow() async throws {
        let service = DemoScanService()
        let result = try await service.analyze(
            input: ScanInput(
                sourceType: .manualBarcode,
                barcode: "850000002",
                capturedImageRef: nil,
                rawText: nil,
                productTypeHint: nil,
                locale: "en_US"
            ),
            userContext: .starter
        )

        let history = [ScanRecord(createdAt: .now, analysis: result)]
        let checkIns = [
            CheckInEntry(createdAt: .now, energy: 2, skin: 3, bloatingRelief: 2, cravingControl: 2, mood: 3, note: "Rough week")
        ]
        let insights = WeeklyInsightEngine().generate(history: history, checkIns: checkIns)

        XCTAssertFalse(insights.isEmpty)
        XCTAssertTrue(insights.contains(where: { $0.title.localizedCaseInsensitiveContains("gut") || $0.summary.localizedCaseInsensitiveContains("energy") }))
    }

    func testRootOrchestratorProducesStructuredAnalysisEnvelope() async throws {
        let service = DemoScanService()
        let input = ScanInput(
            sourceType: .manualBarcode,
            barcode: "850000001",
            capturedImageRef: nil,
            rawText: nil,
            productTypeHint: nil,
            locale: "en_US"
        )
        let analysis = try await service.analyze(input: input, userContext: .starter)
        let event = RootOrchestrator().composeScanEvent(
            input: input,
            legacyAnalysis: analysis,
            localProfileID: "local-user",
            recentScans: [],
            recentCheckIns: [],
            latencyMs: 120
        )

        XCTAssertEqual(event.inputType, .barcode)
        XCTAssertEqual(event.analysis.entityType, .product)
        XCTAssertGreaterThan(event.analysis.overallScore, 0)
        XCTAssertTrue(event.analysis.medicalSafety.disclaimerNeeded)
        XCTAssertFalse(event.analysis.recommendedActions.isEmpty)
    }

    func testMealSnapshotMapsToMealEntity() async throws {
        let service = DemoScanService()
        let input = ScanInput(
            sourceType: .mealPhoto,
            barcode: nil,
            capturedImageRef: nil,
            rawText: "salmon, rice, avocado",
            productTypeHint: .food,
            locale: "en_US"
        )
        let analysis = try await service.analyze(input: input, userContext: .starter)
        let event = RootOrchestrator().composeScanEvent(
            input: input,
            legacyAnalysis: analysis,
            localProfileID: "local-user",
            recentScans: [],
            recentCheckIns: [],
            latencyMs: 180
        )

        XCTAssertEqual(event.inputType, .mealPhoto)
        XCTAssertEqual(event.analysis.entityType, .meal)
        XCTAssertEqual(event.normalizedPayload.entityName, "Meal Snapshot")
    }

    func testSafetyClaimsGuardSanitizesMedicalLanguage() {
        let envelope = AnalysisEnvelope(
            analysisID: UUID().uuidString,
            timestamp: .now,
            inputType: .manual,
            entityType: .product,
            verdict: .adjust,
            overallScore: 62,
            lensScores: StructuredLensScores(skin: 61, hormones: 63, gut: 58, energy: 60, bodyComp: 68),
            whyToday: ["This may diagnose the issue."],
            greenFlags: ["Supports treatment"],
            redFlags: ["Could cure symptoms"],
            recommendedActions: ["Treat this as a medical advice flow."],
            swapSuggestions: [SwapSuggestion(title: "Cure choice", reason: "Reverse symptoms fast.", priority: .high)],
            followUpPrompt: "Could this diagnose what happened?",
            confidence: 0.72,
            medicalSafety: MedicalSafety(isMedicalAdvice: true, disclaimerNeeded: false, riskLevel: .low),
            patternContext: PatternContext(usedHistory: false, relevantPattern: "Treat this aggressively.")
        )

        let reviewed = SafetyClaimsGuard().review(envelope)

        XCTAssertFalse(reviewed.medicalSafety.isMedicalAdvice)
        XCTAssertTrue(reviewed.medicalSafety.disclaimerNeeded)
        XCTAssertFalse(reviewed.whyToday.joined(separator: " ").localizedCaseInsensitiveContains("diagnose"))
        XCTAssertFalse(reviewed.redFlags.joined(separator: " ").localizedCaseInsensitiveContains("cure"))
        XCTAssertFalse(reviewed.recommendedActions.joined(separator: " ").localizedCaseInsensitiveContains("medical advice"))
    }

    func testStoredAppStateMigratesLegacyHistoryIntoEvents() throws {
        let legacyAnalysis = ScanAnalysis(
            createdAt: .now,
            resolvedProduct: SampleCatalog.products[0],
            source: .manualBarcode,
            productType: .food,
            lensScores: [
                LensScore(lens: .glowSkin, score: 70, summary: "Solid fit"),
                LensScore(lens: .hormoneBalance, score: 72, summary: "Solid fit"),
                LensScore(lens: .gutComfort, score: 82, summary: "Strong fit"),
                LensScore(lens: .energyMood, score: 78, summary: "Solid fit"),
                LensScore(lens: .bodyCompositionStrength, score: 80, summary: "Strong fit")
            ],
            overallSummary: "Good legacy result",
            topReasons: [],
            warnings: [],
            alternatives: [],
            confidence: .medium,
            disclaimer: "Legacy disclaimer"
        )

        let legacy = LegacyStoredAppState(
            hasCompletedOnboarding: true,
            userContext: .starter,
            history: [ScanRecord(createdAt: .now, analysis: legacyAnalysis, isFavorite: true)],
            checkIns: [CheckInEntry(createdAt: .now, energy: 4, skin: 3, bloatingRelief: 4, cravingControl: 3, mood: 4, note: "Legacy check-in")],
            subscriptionStatus: .free,
            lastDemoScenarioID: nil,
            userProfile: .starter,
            activeGoals: [],
            firstWeekPlan: nil,
            routines: [],
            memoryItems: [],
            scanDecisions: [],
            experiments: [],
            conversationThreads: []
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(legacy)
        let state = try JSONDecoder().decode(StoredAppState.self, from: data)

        XCTAssertEqual(state.schemaVersion, 1)
        XCTAssertEqual(state.scanEvents.count, 1)
        XCTAssertEqual(state.checkInEvents.count, 1)
        XCTAssertEqual(state.favoriteItems.count, 1)
        XCTAssertEqual(state.scanEvents[0].analysis.inputType, .barcode)
        XCTAssertTrue(state.patternInsights.isEmpty)
        XCTAssertNil(state.weeklyNarrative)
        XCTAssertTrue(state.pantryItems.isEmpty)
        XCTAssertEqual(state.entitlementSnapshot.tier, .free)
    }

    func testPatternAgentEngineHighlightsLowFitEnergyPattern() async throws {
        let service = DemoScanService()
        let input = ScanInput(
            sourceType: .manualBarcode,
            barcode: "850000002",
            capturedImageRef: nil,
            rawText: nil,
            productTypeHint: nil,
            locale: "en_US"
        )
        let analysis = try await service.analyze(input: input, userContext: .starter)
        let orchestrator = RootOrchestrator()
        let firstEvent = orchestrator.composeScanEvent(
            input: input,
            legacyAnalysis: analysis,
            localProfileID: "local-user",
            recentScans: [],
            recentCheckIns: [],
            latencyMs: 120
        )
        let secondEvent = orchestrator.composeScanEvent(
            input: input,
            legacyAnalysis: analysis,
            localProfileID: "local-user",
            recentScans: [firstEvent],
            recentCheckIns: [],
            latencyMs: 118
        )

        let firstCheckIn = CheckInEntry(
            createdAt: .now,
            energy: 2,
            skin: 3,
            bloatingRelief: 3,
            cravingControl: 2,
            mood: 2,
            note: "Energy dropped"
        ).makeEvent(localProfileID: "local-user", linkedScanIDs: [firstEvent.id], readHelpful: false, satiety: 2)

        let secondCheckIn = CheckInEntry(
            createdAt: .now,
            energy: 2,
            skin: 3,
            bloatingRelief: 3,
            cravingControl: 2,
            mood: 2,
            note: "Same pattern"
        ).makeEvent(localProfileID: "local-user", linkedScanIDs: [secondEvent.id], readHelpful: false, satiety: 2)

        let patterns = PatternAgentEngine().derive(
            scanEvents: [secondEvent, firstEvent],
            checkInEvents: [secondCheckIn, firstCheckIn]
        )

        XCTAssertTrue(patterns.contains(where: { $0.signal == .energy }))
    }

    func testWeeklyNarrativeEngineReturnsNilWithoutEnoughSignal() {
        let narrative = WeeklyInsightNarrativeEngine().compose(
            patterns: [],
            scanEvents: [],
            checkInEvents: []
        )

        XCTAssertNil(narrative)
    }

    func testMenuPhotoMapsToMenuEntity() async throws {
        let service = DemoScanService()
        let input = ScanInput(
            sourceType: .menuPhoto,
            barcode: nil,
            capturedImageRef: nil,
            rawText: "burger, fries, soda",
            productTypeHint: .food,
            locale: "en_US"
        )
        let analysis = try await service.analyze(input: input, userContext: .starter)
        let event = RootOrchestrator().composeScanEvent(
            input: input,
            legacyAnalysis: analysis,
            localProfileID: "local-user",
            recentScans: [],
            recentCheckIns: [],
            latencyMs: 160
        )

        XCTAssertEqual(event.inputType, .menuPhoto)
        XCTAssertEqual(event.analysis.entityType, .menuItem)
        XCTAssertEqual(event.normalizedPayload.entityName, "Menu Choice")
    }

    func testAccessPolicyUnlocksExpectedEntitlementsByTier() {
        let policy = AccessPolicy()
        let free = policy.snapshot(subscriptionStatus: .free, billingMode: .demo)
        let plus = policy.snapshot(subscriptionStatus: .plus, billingMode: .demo)
        let pro = policy.snapshot(subscriptionStatus: .pro, billingMode: .demo)

        XCTAssertFalse(policy.isUnlocked(.patternAgent, snapshot: free))
        XCTAssertTrue(policy.isUnlocked(.patternAgent, snapshot: plus))
        XCTAssertFalse(policy.isUnlocked(.pantryMVP, snapshot: plus))
        XCTAssertTrue(policy.isUnlocked(.pantryMVP, snapshot: pro))
    }

    func testSubscriptionStatusOnlyExposesRemainingUpgradeTargets() {
        XCTAssertEqual(SubscriptionStatus.free.upgradeTargets, [.plus, .pro])
        XCTAssertEqual(SubscriptionStatus.plus.upgradeTargets, [.pro])
        XCTAssertTrue(SubscriptionStatus.pro.upgradeTargets.isEmpty)
    }

    func testPantryPresentationCopySwitchesFromLockedToUnlockedLanguage() {
        XCTAssertEqual(
            PantryPresentationCopy.supportingMessage(isUnlocked: false, hasSuggestion: false),
            "Preview only. Pantry actions and suggestions unlock with Pro."
        )
        XCTAssertEqual(
            PantryPresentationCopy.supportingMessage(isUnlocked: true, hasSuggestion: false),
            "Suggestions will appear after a few more supportive repeat choices."
        )
        XCTAssertNil(PantryPresentationCopy.supportingMessage(isUnlocked: true, hasSuggestion: true))
    }

    func testHomeSurfacePlannerPrefersFirstWeekPlanDuringCalibration() {
        let payload = DailyHomePayload(
            state: .calibrating,
            todayFocus: TodayFocus(title: "Calibrate", summary: "Start with signal."),
            bodySignal: CheckInSignal(title: "No fresh body signal yet", summary: "Add one signal.", tone: .neutral),
            nextAction: Recommendation(
                id: "scan-staple",
                kind: .scanStaple,
                title: "Scan a staple",
                summary: "Start with a real decision.",
                cta: "Open scan",
                relatedProductID: nil,
                relatedGoal: nil
            ),
            recommendedSwap: AlternativeSuggestion(
                id: "swap",
                productName: "Swap",
                productID: "swap",
                whyBetter: "Cleaner fit",
                improvedLenses: [.energyMood]
            ),
            openLoops: [OpenLoop(title: "Loop", summary: "Stay with this.")],
            strategistNote: StrategistNote(title: "Note", summary: "One note."),
            recentWins: [RecentWin(title: "Win", summary: "This worked.")]
        )

        let plan = HomeSurfacePlanner().plan(
            payload: payload,
            hasFirstWeekPlan: true,
            hasDailyBrief: true,
            hasGoals: true,
            hasRoutines: true,
            hasPantry: true,
            hasSampleReads: true
        )

        XCTAssertEqual(plan.primaryModule, HomeSurfaceModule.firstWeekPlan)
        XCTAssertFalse(plan.secondaryModules.contains(HomeSurfaceModule.firstWeekPlan))
        XCTAssertEqual(plan.secondaryModules.first, HomeSurfaceModule.dailyBrief)
    }

    func testHomeSurfacePlannerPrefersRecommendedSwapOverDailyBriefWhenAvailable() {
        let payload = DailyHomePayload(
            state: .active,
            todayFocus: TodayFocus(title: "Steadier energy", summary: "Keep the day even."),
            bodySignal: CheckInSignal(title: "Energy still looks soft", summary: "Read the next choice through that lens.", tone: .caution),
            nextAction: Recommendation(
                id: "swap",
                kind: .swapProduct,
                title: "Test a swap",
                summary: "Try the softer option.",
                cta: "Review swap",
                relatedProductID: "swap",
                relatedGoal: nil
            ),
            recommendedSwap: AlternativeSuggestion(
                id: "swap",
                productName: "Swap",
                productID: "swap",
                whyBetter: "Cleaner fit",
                improvedLenses: [.energyMood]
            ),
            openLoops: [],
            strategistNote: StrategistNote(title: "Note", summary: "One note."),
            recentWins: []
        )

        let plan = HomeSurfacePlanner().plan(
            payload: payload,
            hasFirstWeekPlan: false,
            hasDailyBrief: true,
            hasGoals: true,
            hasRoutines: false,
            hasPantry: false,
            hasSampleReads: true
        )

        XCTAssertEqual(plan.primaryModule, HomeSurfaceModule.recommendedSwap)
        XCTAssertEqual(Array(plan.secondaryModules.prefix(2)), [HomeSurfaceModule.dailyBrief, HomeSurfaceModule.activeGoals])
    }

    func testDailyHomePayloadV2TrimsRedundantNarrativeAndDemoContent() {
        let payload = DailyHomePayload(
            state: .calibrating,
            todayFocus: TodayFocus(title: "Calibrate", summary: "Start with signal."),
            bodySignal: CheckInSignal(title: "No fresh body signal yet", summary: "Add one signal.", tone: .neutral),
            nextAction: Recommendation(
                id: "scan-staple",
                kind: .scanStaple,
                title: "Scan a staple",
                summary: "Start with a real decision.",
                cta: "Open scan",
                relatedProductID: nil,
                relatedGoal: nil
            ),
            recommendedSwap: AlternativeSuggestion(
                id: "swap",
                productName: "Swap",
                productID: "swap",
                whyBetter: "Cleaner fit",
                improvedLenses: [.energyMood]
            ),
            openLoops: [OpenLoop(title: "Loop", summary: "Stay with this.")],
            strategistNote: StrategistNote(title: "Note", summary: "One note."),
            recentWins: [RecentWin(title: "Win", summary: "This worked.")]
        )

        let contract = DailyHomePayloadV2Builder().build(
            payload: payload,
            availability: DailyHomeSurfaceAvailability(
                hasFirstWeekPlan: true,
                hasDailyBrief: true,
                hasGoals: true,
                hasRoutines: true,
                hasPantry: true,
                hasSampleReads: true,
                hasUserActivity: true
            )
        )

        XCTAssertEqual(contract.primaryModule, HomeSurfaceModule.firstWeekPlan)
        XCTAssertEqual(contract.secondaryModules, [.dailyBrief, .activeGoals, .recommendedSwap])
        XCTAssertTrue(contract.deferredModules.contains(.openLoops))
        XCTAssertTrue(contract.suppressedModules.contains {
            $0.module == .strategistNote && $0.reason == .redundantNarrative
        })
        XCTAssertTrue(contract.suppressedModules.contains {
            $0.module == .routineMemory && $0.reason == .redundantMemory
        })
        XCTAssertTrue(contract.suppressedModules.contains {
            $0.module == .sampleReads && $0.reason == .demoOnly
        })
    }

    func testDailyHomePayloadV2KeepsSampleReadsOnlyWhenSignalIsStillEmpty() {
        let payload = DailyHomePayload(
            state: .calibrating,
            todayFocus: TodayFocus(title: "Calibrate", summary: "Start with signal."),
            bodySignal: CheckInSignal(title: "No fresh body signal yet", summary: "Add one signal.", tone: .neutral),
            nextAction: Recommendation(
                id: "scan-staple",
                kind: .scanStaple,
                title: "Scan a staple",
                summary: "Start with a real decision.",
                cta: "Open scan",
                relatedProductID: nil,
                relatedGoal: nil
            ),
            recommendedSwap: nil,
            openLoops: [],
            strategistNote: StrategistNote(title: "Note", summary: "One note."),
            recentWins: []
        )

        let contract = DailyHomePayloadV2Builder().build(
            payload: payload,
            availability: DailyHomeSurfaceAvailability(
                hasFirstWeekPlan: true,
                hasDailyBrief: false,
                hasGoals: false,
                hasRoutines: false,
                hasPantry: false,
                hasSampleReads: true,
                hasUserActivity: false
            )
        )

        XCTAssertEqual(contract.primaryModule, HomeSurfaceModule.firstWeekPlan)
        XCTAssertTrue(contract.secondaryModules.contains(.sampleReads))
        XCTAssertFalse(contract.suppressedModules.contains { $0.module == .sampleReads })
    }

    func testComposeDailyBriefPrioritizesPendingScanFeedback() async throws {
        let input = ScanInput(
            sourceType: .manualBarcode,
            barcode: "850000001",
            capturedImageRef: nil,
            rawText: nil,
            productTypeHint: nil,
            locale: "en_US"
        )
        let analysis = try await DemoScanService().analyze(input: input, userContext: .starter)
        let scanEvent = RootOrchestrator().composeScanEvent(
            input: input,
            legacyAnalysis: analysis,
            localProfileID: "local-user",
            recentScans: [],
            recentCheckIns: [],
            latencyMs: 110
        )
        let payload = DailyHomePayload(
            state: .active,
            todayFocus: TodayFocus(title: "Steady energy", summary: "Protect the day."),
            bodySignal: CheckInSignal(title: "Signal", summary: "Summary", tone: .neutral),
            nextAction: Recommendation(
                id: "scan",
                kind: .scanStaple,
                title: "Scan",
                summary: "Scan something real.",
                cta: "Open scan",
                relatedProductID: nil,
                relatedGoal: nil
            ),
            recommendedSwap: nil,
            openLoops: [],
            strategistNote: StrategistNote(title: "Note", summary: "One note."),
            recentWins: []
        )

        let brief = RootOrchestrator().composeDailyBrief(
            payload: payload,
            profile: .starter,
            latestScan: scanEvent,
            latestCheckIn: nil,
            checkInEvents: [],
            routines: []
        )

        XCTAssertEqual(brief.cta.kind, .updateFeedback)
        XCTAssertEqual(brief.cta.title, "Close the last loop")
        XCTAssertTrue(brief.cta.subtitle.contains(analysis.resolvedProduct.name))
    }

    func testComposeDailyBriefUsesRoutineBenchmarkWhenLatestSignalIsSoft() async throws {
        let input = ScanInput(
            sourceType: .manualBarcode,
            barcode: "850000001",
            capturedImageRef: nil,
            rawText: nil,
            productTypeHint: nil,
            locale: "en_US"
        )
        let analysis = try await DemoScanService().analyze(input: input, userContext: .starter)
        let scanEvent = RootOrchestrator().composeScanEvent(
            input: input,
            legacyAnalysis: analysis,
            localProfileID: "local-user",
            recentScans: [],
            recentCheckIns: [],
            latencyMs: 110
        )
        let latestCheckIn = CheckInEntry(
            createdAt: .now,
            energy: 2,
            skin: 3,
            bloatingRelief: 2,
            cravingControl: 3,
            mood: 3,
            note: "Need a steadier default."
        ).makeEvent(localProfileID: "local-user", linkedScanIDs: [scanEvent.id], readHelpful: true, satiety: 3)
        let routine = RoutineItem(
            productID: analysis.resolvedProduct.id,
            productName: analysis.resolvedProduct.name,
            cadenceSummary: "Repeat this first",
            note: "Saved after a supportive read.",
            createdAt: .now
        )
        let payload = DailyHomePayload(
            state: .active,
            todayFocus: TodayFocus(title: "Steady energy", summary: "Protect the day."),
            bodySignal: CheckInSignal(title: "Signal", summary: "Summary", tone: .caution),
            nextAction: Recommendation(
                id: "scan",
                kind: .scanStaple,
                title: "Scan",
                summary: "Scan something real.",
                cta: "Open scan",
                relatedProductID: nil,
                relatedGoal: nil
            ),
            recommendedSwap: nil,
            openLoops: [],
            strategistNote: StrategistNote(title: "Note", summary: "One note."),
            recentWins: []
        )

        let brief = RootOrchestrator().composeDailyBrief(
            payload: payload,
            profile: .starter,
            latestScan: scanEvent,
            latestCheckIn: latestCheckIn,
            checkInEvents: [latestCheckIn],
            routines: [routine]
        )

        XCTAssertEqual(brief.cta.kind, .scanBreakfast)
        XCTAssertEqual(brief.cta.title, "Scan your safest default")
        XCTAssertTrue(brief.cta.subtitle.contains(routine.productName))
    }

    func testHomeComposerOpenLoopsOnlyShowPendingFollowUps() {
        let keepDecision = ScanDecision(
            createdAt: .now,
            productID: "keep-product",
            productName: "Balanced Protein Yogurt",
            kind: .saveToRoutine,
            note: "Keep this around.",
            relatedGoal: nil,
            resolvedAt: nil
        )
        let avoidDecision = ScanDecision(
            createdAt: .now.addingTimeInterval(-60),
            productID: "avoid-product",
            productName: "Sugar Bomb Bar",
            kind: .avoidForNow,
            note: "Avoid for now.",
            relatedGoal: nil,
            resolvedAt: nil
        )

        let payload = HomeComposer().compose(
            profile: .starter,
            activeGoals: [],
            firstWeekPlan: nil,
            history: [],
            checkIns: [],
            decisions: [keepDecision, avoidDecision],
            memoryItems: [],
            experiments: []
        )

        XCTAssertEqual(payload.openLoops.count, 1)
        XCTAssertEqual(payload.openLoops[0].title, "Confirm the routine slot")
        XCTAssertTrue(payload.openLoops[0].summary.contains("Balanced Protein Yogurt"))
    }

    @MainActor
    func testAddCheckInResolvesLinkedRoutineFollowUpAndRefreshesMemory() async throws {
        let input = ScanInput(
            sourceType: .manualBarcode,
            barcode: "850000001",
            capturedImageRef: nil,
            rawText: nil,
            productTypeHint: nil,
            locale: "en_US"
        )
        let analysis = try await DemoScanService().analyze(input: input, userContext: .starter)
        let scanEvent = RootOrchestrator().composeScanEvent(
            input: input,
            legacyAnalysis: analysis,
            localProfileID: "local-user",
            recentScans: [],
            recentCheckIns: [],
            latencyMs: 120
        )

        var snapshot = StoredAppState.fresh()
        snapshot.hasCompletedOnboarding = true
        snapshot.scanEvents = [scanEvent]
        snapshot.scanDecisions = [
            ScanDecision(
                createdAt: .now,
                productID: analysis.resolvedProduct.id,
                productName: analysis.resolvedProduct.name,
                kind: .saveToRoutine,
                note: "Saved after a supportive read.",
                relatedGoal: .steadyEnergy,
                resolvedAt: nil
            )
        ]
        snapshot.routines = [
            RoutineItem(
                productID: analysis.resolvedProduct.id,
                productName: analysis.resolvedProduct.name,
                cadenceSummary: "Keep as a likely repeat choice",
                note: "Saved after a supportive read.",
                createdAt: .now
            )
        ]

        let store = InMemoryStore(snapshot: snapshot)
        let model = AppModel(services: makeServices(store: store))

        model.addCheckIn(
            energy: 4,
            skin: 3,
            bloatingRelief: 4,
            cravingControl: 3,
            mood: 4,
            note: "",
            satiety: 4,
            readHelpful: true,
            linkedScanIDs: [scanEvent.id]
        )

        XCTAssertNotNil(model.scanDecisions.first?.resolvedAt)
        XCTAssertEqual(model.routines.first?.cadenceSummary, "Confirmed by a recent body-signal check-in")
        XCTAssertTrue(model.memoryItems.contains(where: {
            $0.title == "\(analysis.resolvedProduct.name) held up in real use"
        }))
    }

    func testAnalysisPresentationPlanPrefersRoutineForGoodVerdict() {
        let analysis = makeAnalysis(barcode: "850000001")
        let structured = makeEnvelope(verdict: .good, overallScore: 86)
        let plan = AnalysisPresentationPlan.build(analysis: analysis, structured: structured)

        XCTAssertEqual(plan.primaryAction, .saveToRoutine)
        XCTAssertEqual(plan.primaryButtonTitle, "Keep this in routine")
        XCTAssertEqual(plan.secondaryAction, .askStrategist)
        XCTAssertEqual(plan.verdictTitle, "Strong fit for today")
    }

    func testAnalysisPresentationPlanPrefersSwapForAvoidVerdictWhenAlternativeExists() {
        let analysis = makeAnalysis(barcode: "850000002")
        XCTAssertFalse(analysis.alternatives.isEmpty)

        let structured = makeEnvelope(verdict: .avoid, overallScore: 41)
        let plan = AnalysisPresentationPlan.build(analysis: analysis, structured: structured)

        XCTAssertEqual(plan.primaryAction, .swapInstead)
        XCTAssertEqual(plan.secondaryAction, .avoidForNow)
        XCTAssertEqual(plan.swapPreviewTitle, analysis.alternatives.first?.productName)
        XCTAssertEqual(plan.verdictTitle, "Swap before repeating")
    }

    func testAnalysisPresentationPlanEscalatesNeedsMoreInfo() {
        let analysis = makeAnalysis(barcode: "850000003", confidence: .low)
        let structured = makeEnvelope(verdict: .needsMoreInfo, overallScore: 46)
        let plan = AnalysisPresentationPlan.build(analysis: analysis, structured: structured)

        XCTAssertEqual(plan.primaryAction, .askStrategist)
        XCTAssertEqual(plan.primaryButtonTitle, "Ask strategist")
        XCTAssertEqual(plan.secondaryAction, .trackAgain)
        XCTAssertEqual(plan.verdictTitle, "Needs a cleaner read")
    }

    func testAnalysisPresentationPlanUsesMealSnapshotTitleForMealSource() {
        let analysis = makeAnalysis(barcode: "850000001", source: .mealPhoto)
        let plan = AnalysisPresentationPlan.build(analysis: analysis, structured: nil)

        XCTAssertEqual(plan.displayTitle, "Meal Snapshot")
        XCTAssertEqual(plan.heroBadgeTitle, "Meal Snapshot")
    }

    func testHistoryPresentationPlanPrefersCompareWhenTwoReadsSelected() {
        let plan = HistoryPresentationPlan.build(
            readCount: 4,
            decisionCount: 2,
            signalCount: 2,
            anchorCount: 1,
            selectedCount: 2,
            latestReadSummary: "Latest read summary.",
            latestDecisionNote: "Latest decision note.",
            latestPatternTitle: "Pattern title",
            latestWeeklyHeadline: "Weekly headline"
        )

        XCTAssertEqual(plan.primaryAction, .compareSelected)
        XCTAssertEqual(plan.primaryActionTitle, "Compare selected reads")
        XCTAssertEqual(plan.badgeTitle, "Compare ready")
    }

    func testHistoryPresentationPlanStartsScanWhenNoRealMemoryExists() {
        let plan = HistoryPresentationPlan.build(
            readCount: 0,
            decisionCount: 0,
            signalCount: 0,
            anchorCount: 0,
            selectedCount: 0,
            latestReadSummary: nil,
            latestDecisionNote: nil,
            latestPatternTitle: nil,
            latestWeeklyHeadline: nil
        )

        XCTAssertEqual(plan.primaryAction, .startScan)
        XCTAssertEqual(plan.primaryActionTitle, "Scan something real")
        XCTAssertEqual(plan.badgeTitle, "Start memory")
    }

    @MainActor
    func testHistoryTimelineEntriesIgnoreBootstrapNoiseAndFavoriteDuplicates() {
        var snapshot = StoredAppState.fresh()
        snapshot.hasCompletedOnboarding = true
        snapshot.favoriteItems = [
            FavoriteItem(
                id: "favorite-1",
                scanEventID: "scan-1",
                createdAt: .now,
                title: "Favorite",
                summary: "Saved separately as an anchor."
            )
        ]
        let store = InMemoryStore(snapshot: snapshot)
        let model = AppModel(services: makeServices(store: store))

        XCTAssertTrue(model.historyTimelineEntries.isEmpty)
    }

    @MainActor
    func testHistoryTimelineEntriesFallbackToLegacyHistoryWhenStructuredEventsMissing() {
        var snapshot = StoredAppState.fresh()
        let analysis = makeAnalysis(barcode: "850000001")
        snapshot.history = [
            ScanRecord(createdAt: .now, analysis: analysis, isFavorite: false)
        ]
        let store = InMemoryStore(snapshot: snapshot)
        let model = AppModel(services: makeServices(store: store))

        XCTAssertEqual(model.historyTimelineEntries.count, 1)
        XCTAssertEqual(model.historyTimelineEntries[0].kind, .scan)
        XCTAssertEqual(model.historyTimelineEntries[0].title, analysis.resolvedProduct.name)
        XCTAssertEqual(model.historyTimelineEntries[0].summary, analysis.overallSummary)
    }

    func testStrategistResponseEngineUsesStructuredReplyForLinkedRead() {
        let analysis = makeAnalysis(barcode: "850000002")
        let context = ConversationTurnContext(
            activeGoalTitles: ["Steady energy"],
            recentSignals: ["Energy 2/5"],
            recentProducts: [analysis.resolvedProduct.name],
            openLoopSummaries: ["Retest this at lunch."],
            memorySummaries: ["You do better with calmer repeats."],
            latestDecisionSummary: "Keep the next decision simple.",
            latestReadSummary: analysis.overallSummary,
            latestPatternTitle: "Routine anchor",
            latestPatternSummary: "Repeat choices are acting like anchors.",
            weeklyNarrativeHeadline: "Your week is starting to show a cleaner pattern",
            weeklyNarrativeSummary: "Scans and body signals are starting to agree.",
            weeklyNextExperiment: "Try the softer swap at lunch."
        )

        let reply = StrategistResponseEngine().respond(
            to: "Should I swap this?",
            profile: .starter,
            entryPoint: .scan,
            context: context,
            linkedAnalysis: analysis
        )

        XCTAssertTrue(reply.text.contains("Best next step:"))
        XCTAssertTrue(reply.text.contains("Why now:"))
        XCTAssertTrue(reply.text.contains("Watch for:"))
        XCTAssertTrue(reply.text.contains("Ask next:"))
        XCTAssertTrue(reply.text.contains(analysis.resolvedProduct.name))
    }

    @MainActor
    func testStrategistStarterPromptsIncludeLinkedReadContext() {
        let model = AppModel(services: makeServices())
        let analysis = makeAnalysis(barcode: "850000002")

        let prompts = model.strategistStarterPrompts(for: .scan, linkedAnalysis: analysis)

        XCTAssertLessThanOrEqual(prompts.count, 4)
        XCTAssertTrue(prompts.contains(where: { $0.contains(analysis.resolvedProduct.name) }))
        XCTAssertTrue(prompts.contains(where: { $0.localizedCaseInsensitiveContains("swap") }))
    }

    @MainActor
    func testStrategistUsesSharedThreadAcrossEntryPoints() {
        let model = AppModel(services: makeServices())

        model.sendStrategistMessage("What matters most today?", entryPoint: .home)
        let firstCount = model.conversationThread(for: .home).messages.count

        model.sendStrategistMessage("Should this stay in my routine?", entryPoint: .scan)

        XCTAssertEqual(model.conversationThreads.count, 1)
        XCTAssertEqual(model.conversationThread(for: .home).messages.count, firstCount + 2)
        XCTAssertEqual(model.conversationThread(for: .scan).messages.count, firstCount + 2)
        XCTAssertEqual(model.conversationThread(for: .scan).title, "Daily strategist")
    }

    func testComposeScanEventUsesStructuredOverrideAndPreservesLegacyAnalysis() async throws {
        let input = ScanInput(
            sourceType: .manualBarcode,
            barcode: "850000001",
            capturedImageRef: nil,
            rawText: nil,
            productTypeHint: nil,
            locale: "en_US"
        )
        let legacyAnalysis = try await DemoScanService().analyze(input: input, userContext: .starter)
        let remoteEnvelope = AnalysisEnvelope(
            analysisID: "remote-structured-analysis",
            timestamp: .now,
            inputType: .barcode,
            entityType: .product,
            verdict: .adjust,
            overallScore: 61,
            lensScores: StructuredLensScores(skin: 62, hormones: 64, gut: 58, energy: 60, bodyComp: 61),
            whyToday: ["This may diagnose the issue."],
            greenFlags: ["Supports treatment"],
            redFlags: ["Could cure symptoms"],
            recommendedActions: ["Treat this as a medical advice flow."],
            swapSuggestions: [SwapSuggestion(title: "Cure choice", reason: "Reverse symptoms fast.", priority: .high)],
            followUpPrompt: "Could this diagnose what happened?",
            confidence: 0.78,
            medicalSafety: MedicalSafety(isMedicalAdvice: true, disclaimerNeeded: false, riskLevel: .low),
            patternContext: PatternContext(usedHistory: false, relevantPattern: "Treat this aggressively.")
        )

        let event = RootOrchestrator().composeScanEvent(
            input: input,
            legacyAnalysis: legacyAnalysis,
            structuredAnalysis: remoteEnvelope,
            localProfileID: "local-user",
            recentScans: [],
            recentCheckIns: [],
            latencyMs: 90
        )

        XCTAssertEqual(event.legacyAnalysis, legacyAnalysis)
        XCTAssertEqual(event.analysis.analysisID, "remote-structured-analysis")
        XCTAssertFalse(event.analysis.whyToday.joined(separator: " ").localizedCaseInsensitiveContains("diagnose"))
        XCTAssertFalse(event.analysis.recommendedActions.joined(separator: " ").localizedCaseInsensitiveContains("medical advice"))
    }

    @MainActor
    func testAppModelRequireAccessForMenuScannerPresentsContextualPaywallOnFree() {
        let model = AppModel(services: makeServices())

        let granted = model.requireAccess(
            to: .menuScanner,
            surface: .menuScanner,
            previewLines: ["Preview line"]
        )

        XCTAssertFalse(granted)
        XCTAssertEqual(model.activePaywall?.feature, .menuScanner)
        XCTAssertEqual(model.activePaywall?.targetTier, .plus)
        XCTAssertEqual(model.activePaywall?.surface, .menuScanner)
    }

    @MainActor
    func testAppModelRequireAccessForMenuScannerAllowsPlusWithoutPaywall() {
        let model = AppModel(services: makeServices(subscriptionStatus: .plus))

        let granted = model.requireAccess(
            to: .menuScanner,
            surface: .menuScanner,
            previewLines: ["Preview line"]
        )

        XCTAssertTrue(granted)
        XCTAssertNil(model.activePaywall)
    }

    @MainActor
    func testAppModelFallsBackToLegacyWeeklyInsightsWhenNarrativeUnavailable() {
        let model = AppModel(services: makeServices())

        XCTAssertNil(model.weeklyNarrative)
        XCTAssertFalse(model.weeklyInsights.isEmpty)
    }

    @MainActor
    func testAppModelPrefersRemoteStructuredAnalysisWhenAvailable() async throws {
        let input = ScanInput(
            sourceType: .manualBarcode,
            barcode: "850000001",
            capturedImageRef: nil,
            rawText: nil,
            productTypeHint: nil,
            locale: "en_US"
        )
        let legacyAnalysis = try await DemoScanService().analyze(input: input, userContext: .starter)
        let remoteEnvelope = AnalysisEnvelope(
            analysisID: "remote-preferred-analysis",
            timestamp: .now,
            inputType: .barcode,
            entityType: .product,
            verdict: .good,
            overallScore: 88,
            lensScores: StructuredLensScores(skin: 84, hormones: 85, gut: 92, energy: 89, bodyComp: 90),
            whyToday: ["Remote structured reason."],
            greenFlags: ["Remote green flag"],
            redFlags: ["Remote caution"],
            recommendedActions: ["Remote action"],
            swapSuggestions: [],
            followUpPrompt: "Remote follow-up",
            confidence: 0.91,
            medicalSafety: MedicalSafety(isMedicalAdvice: false, disclaimerNeeded: true, riskLevel: .low),
            patternContext: PatternContext(usedHistory: true, relevantPattern: "Remote pattern")
        )
        let backend = MockBackendAPI(structuredAnalysisResult: .success(remoteEnvelope))
        let services = makeServices(
            scanService: StubScanService(analysis: legacyAnalysis),
            backendAPI: backend
        )
        let model = AppModel(services: services)

        await model.analyzeBarcode("850000001")

        let event = try XCTUnwrap(model.scanEvents.first)
        XCTAssertEqual(backend.analyzeStructuredScanCalls, 1)
        XCTAssertEqual(event.analysis.analysisID, "remote-preferred-analysis")
        XCTAssertEqual(event.analysis.followUpPrompt, "Remote follow-up")
        XCTAssertEqual(event.legacyAnalysis, legacyAnalysis)
    }

    @MainActor
    func testAppModelFallsBackToLocalStructuredAnalysisWhenRemoteFails() async throws {
        let input = ScanInput(
            sourceType: .manualBarcode,
            barcode: "850000001",
            capturedImageRef: nil,
            rawText: nil,
            productTypeHint: nil,
            locale: "en_US"
        )
        let legacyAnalysis = try await DemoScanService().analyze(input: input, userContext: .starter)
        let backend = MockBackendAPI(structuredAnalysisResult: .failure(MockBackendAPI.MockError.structuredUnavailable))
        let expectedEnvelope = SafetyClaimsGuard().review(
            RootOrchestrator().localStructuredAnalysis(
                input: input,
                legacyAnalysis: legacyAnalysis,
                recentScans: [],
                recentCheckIns: []
            )
        )
        let services = makeServices(
            scanService: StubScanService(analysis: legacyAnalysis),
            backendAPI: backend
        )
        let model = AppModel(services: services)

        await model.analyzeBarcode("850000001")

        let event = try XCTUnwrap(model.scanEvents.first)
        XCTAssertEqual(backend.analyzeStructuredScanCalls, 1)
        XCTAssertEqual(event.analysis.followUpPrompt, expectedEnvelope.followUpPrompt)
        XCTAssertEqual(event.analysis.overallScore, expectedEnvelope.overallScore)
        XCTAssertEqual(event.legacyAnalysis, legacyAnalysis)
    }

    @MainActor
    func testPantrySaveRemoveAndRoutineFlowsPreservePhaseOneState() async throws {
        let store = InMemoryStore(snapshot: .fresh())
        let model = AppModel(services: makeServices(store: store, subscriptionStatus: .pro))

        await model.analyzeBarcode("850000001")
        let analysis = try XCTUnwrap(model.latestAnalysis)
        let historyCount = model.history.count
        let scanEventCount = model.scanEvents.count

        model.saveFavorite(from: analysis)
        model.recordScanDecision(.saveToRoutine, for: analysis)
        model.saveToPantry(from: analysis)

        XCTAssertEqual(model.history.count, historyCount)
        XCTAssertEqual(model.scanEvents.count, scanEventCount)
        XCTAssertEqual(model.favoriteItems.count, 1)
        XCTAssertEqual(model.routines.count, 1)
        XCTAssertTrue(model.pantryItems.contains(where: { $0.sourceKind == .manualSave && !$0.isArchived }))

        let pantryItem = try XCTUnwrap(model.visiblePantryItems.first)
        model.removePantryItem(pantryItem)

        XCTAssertEqual(model.history.count, historyCount)
        XCTAssertEqual(model.favoriteItems.count, 1)
        XCTAssertEqual(model.routines.count, 1)
        XCTAssertFalse(model.visiblePantryItems.contains(where: { $0.dedupeKey == pantryItem.dedupeKey }))
    }

    func testPantrySurfacePlanUsesUnlockPreviewWhenLocked() {
        let plan = PantrySurfacePlan.build(
            isUnlocked: false,
            itemCount: 2,
            hasSuggestion: false,
            hasOpenableAnchor: true
        )

        XCTAssertEqual(plan.badgeTitle, "Pro preview")
        XCTAssertEqual(plan.primaryActionTitle, "Unlock pantry")
        XCTAssertEqual(plan.secondaryActionTitle, "Open scan")
    }

    @MainActor
    func testPantryAnalysisLookupFallsBackToHistoryRecordID() async throws {
        let model = AppModel(services: makeServices(subscriptionStatus: .pro))
        await model.analyzeBarcode("850000001")

        let analysis = try XCTUnwrap(model.latestAnalysis)
        let record = try XCTUnwrap(model.history.first(where: { $0.analysis.id == analysis.id }))
        let pantryItem = PantryItem(
            id: "pantry-favorite-preview",
            title: analysis.resolvedProduct.name,
            summary: analysis.overallSummary,
            relatedProductID: analysis.resolvedProduct.id,
            sourceKind: .favorite,
            sourceScanID: record.id.uuidString,
            createdAt: .now,
            lastUpdatedAt: .now,
            archivedAt: nil
        )

        let linked = try XCTUnwrap(model.pantryAnalysis(for: pantryItem))
        XCTAssertEqual(linked.id, analysis.id)
    }

    @MainActor
    func testPromotePantryItemToRoutineCreatesDefaultWithoutLinkedAnalysis() {
        let model = AppModel(services: makeServices(subscriptionStatus: .pro))
        let pantryItem = PantryItem(
            id: "pantry-manual-product-anchor",
            title: "Anchor Yogurt",
            summary: "Stable breakfast default.",
            relatedProductID: "product-anchor",
            sourceKind: .manualSave,
            sourceScanID: nil,
            createdAt: .now,
            lastUpdatedAt: .now,
            archivedAt: nil
        )

        model.pantryItems = [pantryItem]
        model.promotePantryItemToRoutine(pantryItem)

        XCTAssertTrue(model.routines.contains(where: { $0.productID == "product-anchor" }))
        XCTAssertTrue(model.memoryItems.contains(where: { $0.relatedProductID == "product-anchor" }))
        XCTAssertTrue(model.scanDecisions.contains(where: { $0.productID == "product-anchor" && $0.kind == .saveToRoutine }))
    }

    @MainActor
    func testSaveFavoriteUsesLinkedScanEventIDWhenAvailable() async throws {
        let model = AppModel(services: makeServices(subscriptionStatus: .pro))
        await model.analyzeBarcode("850000001")

        let analysis = try XCTUnwrap(model.latestAnalysis)
        let event = try XCTUnwrap(model.scanEvents.first(where: { $0.legacyAnalysis.id == analysis.id }))

        model.saveFavorite(from: analysis)

        let favorite = try XCTUnwrap(model.favoriteItems.first)
        XCTAssertEqual(favorite.scanEventID, event.id)
    }
}
