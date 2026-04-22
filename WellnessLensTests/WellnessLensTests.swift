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

    private struct StubHealthKitService: HealthKitServicing {
        var report: HealthKitAuthorizationReport
        var snapshot: BiometricsSnapshot?

        func requestAuthorization(for preferences: LILADomain.DataSyncPreferences) async -> HealthKitAuthorizationReport {
            report
        }

        func currentSnapshot(for profile: UserProfile) async -> BiometricsSnapshot? {
            snapshot
        }

        func writeNutritionIfAllowed(verdict: LILADomain.ScanVerdict, preferences: LILADomain.DataSyncPreferences) async {}
    }

    private struct StubCoachAgent: CoachAgentServing {
        var reply: CoachReply

        func generateReply(for request: CoachAgentRequest) async -> CoachReply {
            reply
        }
    }

    private struct DelayedStubCoachAgent: CoachAgentServing {
        var reply: CoachReply
        var delayNanoseconds: UInt64 = 80_000_000

        func generateReply(for request: CoachAgentRequest) async -> CoachReply {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            return reply
        }
    }

    private actor StubIdentityProvider: IdentityProviding {
        let authorization: String?
        let installIDValue: String

        init(authorization: String? = nil, installIDValue: String = "install-test") {
            self.authorization = authorization
            self.installIDValue = installIDValue
        }

        func prepare() async {}

        func installID() async -> String {
            installIDValue
        }

        func authorizationHeader() async -> String? {
            authorization
        }
    }

    private struct StubAppCheckProvider: AppCheckTokenProviding {
        let tokenValue: String?

        init(tokenValue: String? = nil) {
            self.tokenValue = tokenValue
        }

        func token() async -> String? {
            tokenValue
        }
    }

    private final class RequestHandlerBox: @unchecked Sendable {
        private let lock = NSLock()
        private var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

        func set(_ handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?) {
            lock.lock()
            defer { lock.unlock() }
            self.handler = handler
        }

        func get() -> ((URLRequest) throws -> (HTTPURLResponse, Data))? {
            lock.lock()
            defer { lock.unlock() }
            return handler
        }
    }

    private final class URLProtocolStub: URLProtocol {
        private static let requestHandlerBox = RequestHandlerBox()

        static func setRequestHandler(_ handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?) {
            requestHandlerBox.set(handler)
        }

        override class func canInit(with request: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            guard let handler = Self.requestHandlerBox.get() else {
                XCTFail("URLProtocolStub.requestHandler not set")
                return
            }

            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    private final class MockBackendAPI: WellnessBackendAPI, @unchecked Sendable {
        enum MockError: Error {
            case structuredUnavailable
        }

        var structuredAnalysisResult: Result<AnalysisEnvelope, Error>
        private(set) var analyzeStructuredScanCalls = 0
        private(set) var completedOnboardingCalls = 0
        private(set) var completedOnboardingProfile: UserProfile?
        private(set) var completedOnboardingGoals: [ActiveGoal] = []
        private(set) var completedOnboardingPlan: FirstWeekPlan?

        init(structuredAnalysisResult: Result<AnalysisEnvelope, Error>) {
            self.structuredAnalysisResult = structuredAnalysisResult
        }

        func fetchClientConfig() async throws -> ClientConfigResponse {
            ClientConfigResponse(
                environment: "test",
                minimumSupportedVersion: "1.0",
                minimumSupportedBuild: 1,
                copyVersion: "test-copy",
                persistenceMode: "firestore",
                firebaseAuthEnforced: true,
                appCheckEnforced: true,
                agentProviderMode: "vertex",
                flags: WellnessFeatureFlags(),
                killSwitches: ClientKillSwitches(scanDisabled: false, strategistDisabled: false, homeDisabled: false),
                updatedAt: .now
            )
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
        ) async throws {
            completedOnboardingCalls += 1
            completedOnboardingProfile = profile
            completedOnboardingGoals = activeGoals
            completedOnboardingPlan = firstWeekPlan
        }

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

        func syncHistory(
            scans: [ScanEvent],
            checkIns: [CheckInEvent],
            favorites: [FavoriteItem],
            memoryItems: [MemoryItem],
            scanDecisions: [ScanDecision]
        ) async throws -> HistorySyncResponse {
            HistorySyncResponse(
                installID: "test-install",
                scans: scans,
                checkIns: checkIns,
                favorites: favorites,
                memoryItems: memoryItems,
                scanDecisions: scanDecisions,
                serverTimestamp: .now
            )
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

    private func makeVerdict(
        fit: LILADomain.FitLevel = .goodFit,
        source: LILADomain.ScanSource = .manualBarcode,
        watchoutCount: Int = 2
    ) -> LILADomain.ScanVerdict {
        var verdict = makeAnalysis(barcode: "850000001").lilaVerdict(context: UserContext.starter.lilaContext())
        verdict.fit = fit
        verdict.scanSource = source
        verdict.confidence = LILADomain.Confidence.medium
        verdict.headline = "Custom verdict headline."
        verdict.primaryReason = "Primary reason customized for the verdict surface."
        verdict.watchouts = Array(0..<watchoutCount).map { index in
            LILADomain.Watchout(
                title: "Watchout \(index + 1)",
                detail: "Detail \(index + 1)",
                severity: index == 0 ? .important : .moderate,
                personalRelevance: index == 0 ? .personal : .general
            )
        }
        verdict.betterSwap = LILADomain.Alternative(
            productName: "Softer swap",
            whyBetter: "it lowers sugar friction and keeps the read steadier",
            improvedLenses: [.energyAndMood]
        )
        verdict.trackPrompt = LILADomain.FollowUpPrompt(
            triggerAfterHours: 3,
            questionText: "Did this feel steadier a few hours later?",
            targetLens: .energyAndMood,
            expectedResponseType: .openText
        )
        return verdict
    }

    private func makeCoachReply(
        message: String = "Respuesta del coach.",
        followUpQuestion: String? = nil,
        tone: CoachTone = .warmDirect,
        safetyFlags: [CoachSafetyFlag] = [],
        referencedVerdictSummary: String? = nil,
        referencedPatterns: [String] = [],
        suggestedActions: [CoachSuggestedAction] = [],
        voiceTags: [CoachVoiceTag]? = nil,
        voiceDirective: String? = nil,
        spokenVersion: String? = nil
    ) -> CoachReply {
        CoachReply(
            replyId: UUID().uuidString,
            createdAt: .now,
            message: message,
            tone: tone,
            referencedVerdictId: nil,
            referencedVerdictSummary: referencedVerdictSummary,
            referencedPatterns: referencedPatterns,
            suggestedActions: suggestedActions,
            followUpQuestion: followUpQuestion,
            safetyFlags: safetyFlags,
            evidenceTier: .emerging,
            disclaimer: "Nácar ofrece guía direccional de wellness, no diagnóstico ni tratamiento médico.",
            voiceTags: voiceTags,
            voiceDirective: voiceDirective,
            spokenVersion: spokenVersion
        )
    }

    private func makeCoachRequest(userMessage: String) -> CoachAgentRequest {
        CoachAgentRequest(
            userMessage: userMessage,
            profile: .starter,
            biometrics: nil,
            latestVerdict: nil,
            recentVerdicts: [],
            recentCheckIns: [],
            memorySummaries: [],
            patternInsights: [],
            threadHistory: []
        )
    }

    private func makeRemoteReadyAnalysis(source: ScanSource = .manualBarcode) -> ScanAnalysis {
        var analysis = makeAnalysis(barcode: "850000001", source: source)
        analysis.resolvedProduct.name = "Balanced Protein Yogurt"
        analysis.resolvedProduct.brand = "Good Farm"
        analysis.resolvedProduct.barcode = "7501031311309"
        analysis.resolvedProduct.resolution = ProductResolution(
            canonicalProductID: "off:7501031311309",
            source: .openFoodFacts,
            confidence: 0.91,
            nutritionSnapshot: NutritionSnapshot(
                energyKcalPer100g: 96,
                proteinGPer100g: 11,
                carbsGPer100g: 4,
                fatGPer100g: 3,
                sugarsGPer100g: 4,
                fiberGPer100g: 0,
                sodiumMgPer100g: 80,
                caffeineMgPer100g: nil,
                novaGroup: 3
            ),
            isDirectional: false
        )
        return analysis
    }

    private func makeRemoteScanVerdictRequest(source: ScanSource = .manualBarcode) -> ScanVerdictRequest {
        let analysis = makeRemoteReadyAnalysis(source: source)
        let input = ScanInput(
            sourceType: source,
            barcode: source == .labelPhoto ? nil : analysis.resolvedProduct.barcode,
            capturedImageRef: nil,
            rawText: source == .labelPhoto ? "milk, cultures" : nil,
            productTypeHint: .food,
            locale: "en_US"
        )
        return ScanVerdictRequest(
            input: input,
            legacyAnalysis: analysis,
            structuredAnalysis: nil,
            profile: .starter,
            recentScans: [],
            recentCheckIns: [],
            biometrics: nil
        )
    }

    private func makeRemoteScanVerdictPayload() -> Data {
        Data(
            #"""
            {
              "verdict": {
                "fit": "goodFit",
                "confidence": "high",
                "headline": "Remote verdict headline.",
                "primaryReason": "Remote primary reason.",
                "lensScores": [
                  { "lens": "glowAndSkin", "score": 72, "trend": "neutral", "summary": "Glow stable.", "contextApplied": [] },
                  { "lens": "hormoneBalance", "score": 70, "trend": "neutral", "summary": "Hormones steady.", "contextApplied": [] },
                  { "lens": "gutComfort", "score": 78, "trend": "rising", "summary": "Gut looks supported.", "contextApplied": [] },
                  { "lens": "energyAndMood", "score": 82, "trend": "rising", "summary": "Energy reads supportive.", "contextApplied": [] },
                  { "lens": "bodyCompositionAndStrength", "score": 76, "trend": "neutral", "summary": "Protein helps here.", "contextApplied": [] }
                ],
                "watchouts": [],
                "betterSwap": null,
                "trackPrompt": {
                  "triggerAfterHours": 3,
                  "questionText": "Check in later?",
                  "targetLens": "energyAndMood",
                  "expectedResponseType": "openText"
                },
                "evidenceTier": "high",
                "reasoningBreakdown": {
                  "deterministicFactors": [
                    { "rule": "Remote rule", "delta": 6, "affectedLens": "energyAndMood" }
                  ],
                  "agentInsights": [
                    { "insight": "Remote insight", "modelUsed": "agent-service/test", "confidenceScore": 0.91 }
                  ],
                  "userHistoryFactors": [],
                  "totalAdjustments": 1
                },
                "disclaimer": "Remote disclaimer",
                "sources": [
                  { "title": "Balanced Protein Yogurt", "organization": "Open Food Facts", "tier": "high" }
                ]
              }
            }
            """#.utf8
        )
    }

    private func requestBodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                return nil
            }
            if read == 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }

    func testLILAGreatFitHeadlineUsesSpanishFallbackCopy() {
        var analysis = makeAnalysis(barcode: "850000001")
        analysis.resolvedProduct.name = "Yogurt griego"
        analysis.lensScores = analysis.lensScores.map { lensScore in
            LensScore(lens: lensScore.lens, score: 92, summary: lensScore.summary)
        }

        let verdict = analysis.lilaVerdict(context: UserContext.starter.lilaContext())

        XCTAssertTrue(verdict.headline.contains("sí suma"))
        XCTAssertFalse(verdict.headline.localizedCaseInsensitiveContains("strong fit"))
    }

    func testLILASkipHeadlineLowercasesProductName() {
        var analysis = makeAnalysis(barcode: "850000001")
        analysis.resolvedProduct.name = "Bebida Energética"
        analysis.lensScores = analysis.lensScores.map { lensScore in
            LensScore(lens: lensScore.lens, score: 32, summary: lensScore.summary)
        }

        let verdict = analysis.lilaVerdict(context: UserContext.starter.lilaContext())

        XCTAssertTrue(verdict.headline.hasPrefix("Mejor no "))
        XCTAssertTrue(verdict.headline.contains("bebida energética"))
    }

    func testLILAFallbackHeadlinesDoNotContainEnglishFragments() {
        let forbidden = ["strong fit", "supportive", "occasional choice", "not the best fit", "bit more detail"]
        let verdicts: [LILADomain.ScanVerdict] = [
            {
                var analysis = makeAnalysis(barcode: "850000001")
                analysis.resolvedProduct.name = "Producto"
                analysis.lensScores = analysis.lensScores.map { LensScore(lens: $0.lens, score: 92, summary: $0.summary) }
                return analysis.lilaVerdict(context: UserContext.starter.lilaContext())
            }(),
            {
                var analysis = makeAnalysis(barcode: "850000001")
                analysis.resolvedProduct.name = "Producto"
                analysis.lensScores = analysis.lensScores.map { LensScore(lens: $0.lens, score: 74, summary: $0.summary) }
                return analysis.lilaVerdict(context: UserContext.starter.lilaContext())
            }(),
            {
                var analysis = makeAnalysis(barcode: "850000001")
                analysis.resolvedProduct.name = "Producto"
                analysis.lensScores = analysis.lensScores.map { LensScore(lens: $0.lens, score: 56, summary: $0.summary) }
                return analysis.lilaVerdict(context: UserContext.starter.lilaContext())
            }(),
            {
                var analysis = makeAnalysis(barcode: "850000001")
                analysis.resolvedProduct.name = "Producto"
                analysis.lensScores = analysis.lensScores.map { LensScore(lens: $0.lens, score: 28, summary: $0.summary) }
                return analysis.lilaVerdict(context: UserContext.starter.lilaContext())
            }(),
            AnalysisEnvelope(
                analysisID: UUID().uuidString,
                timestamp: .now,
                inputType: .barcode,
                entityType: .product,
                verdict: .needsMoreInfo,
                overallScore: 0,
                lensScores: StructuredLensScores(skin: 0, hormones: 0, gut: 0, energy: 0, bodyComp: 0),
                whyToday: [],
                greenFlags: [],
                redFlags: [],
                recommendedActions: [],
                swapSuggestions: [],
                followUpPrompt: "",
                confidence: 0.2,
                medicalSafety: MedicalSafety(isMedicalAdvice: false, disclaimerNeeded: true, riskLevel: .low),
                patternContext: PatternContext(usedHistory: false, relevantPattern: nil)
            ).lilaVerdict(
                fallbackAnalysis: nil,
                context: UserContext.starter.lilaContext()
            )
        ]

        for verdict in verdicts {
            let headline = verdict.headline.lowercased()
            for fragment in forbidden {
                XCTAssertFalse(
                    headline.contains(fragment),
                    "Headline contains English fragment '\(fragment)': \(verdict.headline)"
                )
            }
        }
    }

    func testDeterministicCoachAgentRespondsToOpenMessage() async {
        let agent = DeterministicCoachAgent()

        let reply = await agent.generateReply(for: makeCoachRequest(userMessage: "Hola"))

        XCTAssertFalse(reply.message.isEmpty)
        XCTAssertTrue(reply.disclaimer.contains("Nácar"))
    }

    func testDeterministicCoachAgentTriggersEDGuardrail() async {
        let agent = DeterministicCoachAgent()

        let reply = await agent.generateReply(for: makeCoachRequest(userMessage: "Me salto la cena para compensar lo de hoy"))

        XCTAssertTrue(reply.safetyFlags.contains(.edGuardrail))
        XCTAssertEqual(reply.tone, .supportive)
    }

    func testDeterministicCoachAgentTriggersCrisisSignal() async {
        let agent = DeterministicCoachAgent()

        let reply = await agent.generateReply(for: makeCoachRequest(userMessage: "Ya no puedo más, no quiero estar aquí"))

        XCTAssertTrue(reply.safetyFlags.contains(.crisisSignal))
    }

    func testRemoteCoachAgentFallsBackOnNetworkFailure() async {
        let agent = RemoteCoachAgent(
            endpoint: URL(string: "http://127.0.0.1:1/v1/coach/reply")!,
            timeoutSeconds: 0.1,
            identityProvider: StubIdentityProvider(),
            appCheckProvider: StubAppCheckProvider()
        )

        let reply = await agent.generateReply(for: makeCoachRequest(userMessage: "Hola"))

        XCTAssertFalse(reply.message.isEmpty)
        XCTAssertTrue(reply.disclaimer.contains("Nácar"))
    }

    func testRemoteCoachAgentSendsAuthAndAppCheckHeaders() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(makeCoachReply(message: "Remota"))

        URLProtocolStub.setRequestHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"), "app-check-token")
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, payload)
        }

        let agent = RemoteCoachAgent(
            endpoint: URL(string: "https://example.com/v1/coach/reply")!,
            session: session,
            identityProvider: StubIdentityProvider(authorization: "Bearer test-token"),
            appCheckProvider: StubAppCheckProvider(tokenValue: "app-check-token")
        )

        let reply = await agent.generateReply(for: makeCoachRequest(userMessage: "Hola"))

        XCTAssertEqual(reply.message, "Remota")
        URLProtocolStub.setRequestHandler(nil)
    }

    func testRemoteScanVerdictAgentFallsBackOnNetworkFailure() async {
        let agent = RemoteScanVerdictAgent(
            endpoint: URL(string: "http://127.0.0.1:1/v1/scan/verdict")!,
            timeoutSeconds: 0.1,
            identityProvider: StubIdentityProvider(),
            appCheckProvider: StubAppCheckProvider()
        )

        let verdict = await agent.generateVerdict(for: makeRemoteScanVerdictRequest())

        XCTAssertFalse(verdict.headline.isEmpty)
        XCTAssertTrue(verdict.reasoningBreakdown.agentInsights.first?.modelUsed.hasPrefix("ios-remote-fallback/") == true)
    }

    func testRemoteScanVerdictAgentSendsAuthAndResolvedProductMetadata() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)
        let payload = makeRemoteScanVerdictPayload()

        URLProtocolStub.setRequestHandler { [self] request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"), "app-check-token")

            let body = try XCTUnwrap(self.requestBodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["productName"] as? String, "Balanced Protein Yogurt")
            XCTAssertEqual(json["source"] as? String, "barcode")

            let resolvedProduct = try XCTUnwrap(json["resolved_product"] as? [String: Any])
            XCTAssertEqual(resolvedProduct["source"] as? String, "openFoodFacts")
            XCTAssertEqual(resolvedProduct["barcode"] as? String, "7501031311309")
            XCTAssertEqual(resolvedProduct["is_directional"] as? Bool, false)

            let nutritionSnapshot = try XCTUnwrap(resolvedProduct["nutrition_snapshot"] as? [String: Any])
            XCTAssertEqual(nutritionSnapshot["protein_g_per_100g"] as? Double, 11)

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, payload)
        }

        let agent = RemoteScanVerdictAgent(
            endpoint: URL(string: "https://example.com/v1/scan/verdict")!,
            session: session,
            identityProvider: StubIdentityProvider(authorization: "Bearer test-token"),
            appCheckProvider: StubAppCheckProvider(tokenValue: "app-check-token")
        )

        let verdict = await agent.generateVerdict(for: makeRemoteScanVerdictRequest())

        XCTAssertEqual(verdict.headline, "Remote verdict headline.")
        XCTAssertEqual(verdict.reasoningBreakdown.agentInsights.first?.modelUsed, "agent-service/test")
        XCTAssertEqual(verdict.resolvedProduct.resolutionSource, .openFoodFacts)
        URLProtocolStub.setRequestHandler(nil)
    }

    func testRemoteScanVerdictAgentCapturesHTTPFallbackReason() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        URLProtocolStub.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let payload = Data(#"{"detail":"Missing Authorization header."}"#.utf8)
            return (response, payload)
        }

        let agent = RemoteScanVerdictAgent(
            endpoint: URL(string: "https://example.com/v1/scan/verdict")!,
            session: session,
            identityProvider: StubIdentityProvider(),
            appCheckProvider: StubAppCheckProvider()
        )

        let verdict = await agent.generateVerdict(for: makeRemoteScanVerdictRequest())

        XCTAssertTrue(verdict.reasoningBreakdown.agentInsights.first?.modelUsed.contains("http-401") == true)
        URLProtocolStub.setRequestHandler(nil)
    }

    @MainActor
    func testSendStrategistMessageUsesCoachReplyAndPreservesStructuredPayload() async {
        let store = InMemoryStore()
        let coachReply = makeCoachReply(
            message: "Esta es la respuesta principal.",
            followUpQuestion: "¿Quieres que lo revisemos mañana?",
            safetyFlags: [.pregnancyGuardrail],
            referencedVerdictSummary: "Último verdict: úsalo con más contexto.",
            referencedPatterns: ["Sleep has been noisier this week."],
            suggestedActions: [
                CoachSuggestedAction(type: .scan, label: "Scan something real", deepLinkHint: "scan"),
                CoachSuggestedAction(type: .checkIn, label: "Log a body signal", deepLinkHint: "check_in")
            ],
            voiceTags: [.calm, .warm],
            voiceDirective: "gentle-opening",
            spokenVersion: "Esta es la versión hablada."
        )
        let model = AppModel(
            services: makeServices(
                store: store,
                coachAgent: StubCoachAgent(reply: coachReply)
            )
        )

        let initialMessages = model.conversationThread(for: .home).messages.count
        model.sendStrategistMessage("Hola coach", entryPoint: .home)
        await waitForConversationMessageCount(
            initialMessages + 2,
            in: model,
            entryPoint: .home
        )

        let thread = model.conversationThread(for: .home)
        let recentMessages = Array(thread.messages.suffix(2))

        XCTAssertEqual(recentMessages.map(\.speaker), [.user, .strategist])
        XCTAssertEqual(recentMessages.last?.text, "Esta es la respuesta principal.")
        XCTAssertEqual(recentMessages.last?.coachPayload?.followUpQuestion, "¿Quieres que lo revisemos mañana?")
        XCTAssertEqual(recentMessages.last?.coachPayload?.referencedVerdictSummary, "Último verdict: úsalo con más contexto.")
        XCTAssertEqual(recentMessages.last?.coachPayload?.referencedPatterns, ["Sleep has been noisier this week."])
        XCTAssertEqual(recentMessages.last?.coachPayload?.suggestedActions.map(\.type), [.scan, .checkIn])
        XCTAssertEqual(recentMessages.last?.coachPayload?.voiceTags, [.calm, .warm])
        XCTAssertEqual(recentMessages.last?.coachPayload?.voiceDirective, "gentle-opening")
        XCTAssertEqual(recentMessages.last?.coachPayload?.spokenVersion, "Esta es la versión hablada.")
        XCTAssertEqual(
            recentMessages.last?.coachHistoryText,
            "Esta es la respuesta principal.\n\n¿Quieres que lo revisemos mañana?"
        )
    }

    @MainActor
    func testSendStrategistMessageTracksPendingReplyState() async {
        let coachReply = makeCoachReply(message: "Respuesta retardada.", followUpQuestion: "¿Seguimos mañana?")
        let model = AppModel(
            services: makeServices(
                coachAgent: DelayedStubCoachAgent(reply: coachReply)
            )
        )

        let initialMessages = model.conversationThread(for: .home).messages.count
        model.sendStrategistMessage("Hola coach", entryPoint: .home)

        let userMessageID = model.conversationThread(for: .home).messages.last?.id
        XCTAssertNotNil(userMessageID)
        if let userMessageID {
            XCTAssertTrue(model.isAwaitingStrategistReply(to: userMessageID))
        }

        await waitForConversationMessageCount(
            initialMessages + 2,
            in: model,
            entryPoint: .home
        )

        if let userMessageID {
            XCTAssertFalse(model.isAwaitingStrategistReply(to: userMessageID))
        }
    }

    @MainActor
    private func makeServices(
        store: InMemoryStore = InMemoryStore(),
        subscriptionStatus: SubscriptionStatus = .free,
        featureFlags: WellnessFeatureFlags = WellnessFeatureFlags(),
        scanService: ScanService? = nil,
        backendAPI: WellnessBackendAPI? = nil,
        healthKitService: HealthKitServicing = NoopHealthKitService(),
        scanVerdictAgent: ScanVerdictServing = DeterministicScanVerdictAgent(),
        coachAgent: any CoachAgentServing = DeterministicCoachAgent()
    ) -> AppServices {
        store.snapshot.subscriptionStatus = subscriptionStatus

        return AppServices(
            configuration: RuntimeConfiguration(
                backendBaseURL: nil,
                agentServiceBaseURL: nil,
                isFirebaseEnabled: false,
                firebaseOptionsPlistName: nil,
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
            identityProvider: LocalInstallIdentityProvider(),
            scanVerdictAgent: scanVerdictAgent,
            coachAgent: coachAgent,
            healthKitService: healthKitService
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
        XCTAssertEqual(state.scanVerdicts.count, 1)
        XCTAssertEqual(state.checkInEvents.count, 1)
        XCTAssertEqual(state.favoriteItems.count, 1)
        XCTAssertEqual(state.scanEvents[0].analysis.inputType, .barcode)
        XCTAssertTrue(state.patternInsights.isEmpty)
        XCTAssertNil(state.weeklyNarrative)
        XCTAssertTrue(state.pantryItems.isEmpty)
        XCTAssertEqual(state.entitlementSnapshot.tier, .free)
    }

    func testStoredAppStateRoundTripsOnboardingDraft() throws {
        var state = StoredAppState.fresh()
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        state.onboardingDraft = OnboardingDraft(
            currentStep: .consent,
            formData: .starter,
            createdAt: createdAt,
            lastUpdatedAt: updatedAt
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(StoredAppState.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 7)
        XCTAssertEqual(decoded.onboardingDraft?.currentStep, .consent)
        XCTAssertEqual(decoded.onboardingDraft?.formData, .starter)
        XCTAssertEqual(decoded.onboardingDraft?.createdAt, createdAt)
        XCTAssertEqual(decoded.onboardingDraft?.lastUpdatedAt, updatedAt)
    }

    func testStoredAppStateRoundTripsConversationMessageWithoutCoachPayload() throws {
        var state = StoredAppState.fresh()
        let createdAt = Date(timeIntervalSince1970: 321)
        state.conversationThreads = [
            ConversationThread(
                title: "Daily strategist",
                entryPoint: .home,
                createdAt: createdAt,
                updatedAt: createdAt,
                messages: [
                    ConversationMessage(
                        speaker: .strategist,
                        text: "Legacy message",
                        createdAt: createdAt
                    )
                ]
            )
        ]

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(StoredAppState.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 7)
        XCTAssertNil(decoded.conversationThreads.first?.messages.first?.coachPayload)
    }

    func testLILAVerdictAdapterRoundTripsWithEnvelopeFallback() async throws {
        let analysis = makeAnalysis(barcode: "850000001")
        let context = UserProfile.starter.lilaContext()

        let verdict = analysis.lilaVerdict(context: context)
        let envelope = verdict.analysisEnvelope()
        let rebuilt = envelope.lilaVerdict(fallbackAnalysis: analysis, context: context)

        XCTAssertEqual(envelope.analysisID, verdict.id.uuidString)
        XCTAssertEqual(rebuilt.resolvedProduct.name, analysis.resolvedProduct.name)
        XCTAssertEqual(rebuilt.scanSource, verdict.scanSource)
        XCTAssertEqual(rebuilt.overallScore, verdict.overallScore)
    }

    func testNoopHealthKitServiceFallsBackGracefully() async {
        let report = await NoopHealthKitService().requestAuthorization(for: .init(healthKitEnabled: true))
        let snapshot = await NoopHealthKitService().currentSnapshot(for: .starter)

        XCTAssertFalse(report.healthDataAvailable)
        XCTAssertEqual(report.cycle, .unavailable)
        XCTAssertNil(snapshot)
    }

    func testStoredAppStateClearsOnboardingDraftWhenAlreadyCompleted() throws {
        var state = StoredAppState.fresh()
        state.hasCompletedOnboarding = true
        state.onboardingDraft = OnboardingDraft(currentStep: .summary)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(StoredAppState.self, from: data)

        XCTAssertTrue(decoded.hasCompletedOnboarding)
        XCTAssertNil(decoded.onboardingDraft)
    }

    @MainActor
    func testAppModelOnboardingDraftPersistsAndCompletesToRequestedDestination() async throws {
        let store = InMemoryStore()
        let backend = MockBackendAPI(structuredAnalysisResult: .failure(MockBackendAPI.MockError.structuredUnavailable))
        let model = AppModel(services: makeServices(store: store, backendAPI: backend))

        var draft = model.resumeOnboarding()
        draft.currentStep = .routine
        draft.formData.goals = [.steadyEnergy]
        draft.formData.frictions = [.bloating]
        model.updateOnboardingDraft(draft)

        XCTAssertEqual(model.onboardingDraft?.currentStep, .routine)
        XCTAssertEqual(store.snapshot.onboardingDraft?.currentStep, .routine)

        model.skipOnboardingStep()
        XCTAssertEqual(model.onboardingDraft?.currentStep, .priorities)
        XCTAssertEqual(store.snapshot.onboardingDraft?.currentStep, .priorities)

        let completionDraft = try XCTUnwrap(model.onboardingDraft)
        model.completeOnboarding(using: completionDraft, exitDestination: .scan)

        XCTAssertTrue(model.hasCompletedOnboarding)
        XCTAssertNil(model.onboardingDraft)
        XCTAssertNil(store.snapshot.onboardingDraft)
        XCTAssertEqual(model.selectedTab, .scan)
        XCTAssertFalse(model.activeGoals.isEmpty)
        XCTAssertNotNil(model.firstWeekPlan)
        XCTAssertFalse(model.memoryItems.isEmpty)
        XCTAssertEqual(model.consentRecords.last?.flags, model.userProfile.consentFlags)

        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(backend.completedOnboardingCalls, 1)
        XCTAssertEqual(backend.completedOnboardingProfile?.userContext.goals, [.steadyEnergy])
        XCTAssertFalse(backend.completedOnboardingGoals.isEmpty)
        XCTAssertNotNil(backend.completedOnboardingPlan)
    }

    @MainActor
    func testOnboardingExitDestinationPrefersCheckInAfterRealScan() {
        let freshModel = AppModel(services: makeServices(store: InMemoryStore()))
        XCTAssertEqual(freshModel.onboardingPrimaryExitDestination, .scan)
        XCTAssertEqual(freshModel.onboardingSecondaryExitDestination, .checkIn)

        var snapshot = StoredAppState.fresh()
        snapshot.history = [ScanRecord(createdAt: .now, analysis: makeAnalysis(barcode: "850000001"))]
        let returningModel = AppModel(services: makeServices(store: InMemoryStore(snapshot: snapshot)))

        XCTAssertEqual(returningModel.onboardingPrimaryExitDestination, .checkIn)
        XCTAssertEqual(returningModel.onboardingSecondaryExitDestination, .scan)
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

    @MainActor
    func testFollowUpCheckInClosesExperimentByStableProductIdentity() async throws {
        let analysis = makeRemoteReadyAnalysis()
        let model = AppModel(
            services: makeServices(
                scanService: StubScanService(analysis: analysis)
            )
        )

        await model.analyzeBarcode("850000001")
        let event = try XCTUnwrap(model.scanEvents.first)
        model.experiments = [
            Experiment(
                title: "Retest legacy title",
                hypothesis: "Confirm the stronger packaged-food identity path.",
                status: .active,
                relatedProductID: analysis.resolvedProduct.stableIdentityKey,
                relatedGoal: .steadyEnergy,
                createdAt: .now,
                lastUpdatedAt: .now
            )
        ]

        model.addCheckIn(
            energy: 4,
            skin: 3,
            bloatingRelief: 4,
            cravingControl: 3,
            mood: 4,
            note: "",
            satiety: 4,
            readHelpful: true,
            linkedScanIDs: [event.id]
        )

        XCTAssertEqual(model.experiments.first?.status, .learned)
    }

    @MainActor
    func testFollowUpCheckInKeepsLegacyExperimentTitleFallbackWithoutRelatedProductID() async throws {
        let analysis = makeAnalysis(barcode: "850000001")
        let model = AppModel(
            services: makeServices(
                scanService: StubScanService(analysis: analysis)
            )
        )

        await model.analyzeBarcode("850000001")
        let event = try XCTUnwrap(model.scanEvents.first)
        model.experiments = [
            Experiment(
                title: "Retest \(analysis.resolvedProduct.name)",
                hypothesis: "Fallback title matching should stay backward compatible.",
                status: .active,
                relatedGoal: .steadyEnergy,
                createdAt: .now,
                lastUpdatedAt: .now
            )
        ]

        model.addCheckIn(
            energy: 4,
            skin: 3,
            bloatingRelief: 4,
            cravingControl: 3,
            mood: 4,
            note: "",
            satiety: 4,
            readHelpful: true,
            linkedScanIDs: [event.id]
        )

        XCTAssertEqual(model.experiments.first?.status, .learned)
    }

    func testProductReferenceOverlapBridgesStableAndCanonicalAliases() throws {
        let analysis = makeRemoteReadyAnalysis()
        let scanReference = analysis.productReference()
        let routineReference = RoutineItem(
            productID: analysis.resolvedProduct.id,
            productName: analysis.resolvedProduct.name,
            cadenceSummary: "Keep as a likely repeat choice",
            note: "Canonical provider-backed routine.",
            createdAt: .now
        ).productReference

        XCTAssertEqual(scanReference.graphID, analysis.resolvedProduct.stableIdentityKey)
        XCTAssertTrue(scanReference.aliases.contains(analysis.resolvedProduct.id))
        XCTAssertTrue(scanReference.aliases.contains(analysis.resolvedProduct.stableIdentityKey))
        XCTAssertTrue(scanReference.overlaps(with: try XCTUnwrap(routineReference)))
    }

    func testScanEventProductReferenceCarriesEventAliasesAlongsideResolvedIdentity() throws {
        let analysis = makeRemoteReadyAnalysis()
        let input = ScanInput(
            sourceType: .manualBarcode,
            barcode: analysis.resolvedProduct.barcode,
            capturedImageRef: nil,
            rawText: nil,
            productTypeHint: .food,
            locale: "en_US"
        )
        let event = RootOrchestrator().composeScanEvent(
            input: input,
            legacyAnalysis: analysis,
            structuredAnalysis: nil,
            localProfileID: "local-user",
            recentScans: [],
            recentCheckIns: [],
            latencyMs: 90
        )

        XCTAssertEqual(event.productReference.graphID, event.preferredRelatedProductID)
        XCTAssertTrue(event.productReference.aliases.contains(event.id))
        XCTAssertTrue(event.productReference.aliases.contains("scan:\(event.id)"))
        XCTAssertTrue(event.productReference.aliases.contains(analysis.resolvedProduct.id))
    }

    func testProductResolutionSemanticsDeriveFromDecodedLegacyPayloadWithoutExplicitField() throws {
        let payload = Data(
            #"""
            {
              "id": "off:7501031311309",
              "name": "Greek Yogurt",
              "brand": "Good Farm",
              "productType": "food",
              "barcode": "7501031311309",
              "headline": "Exact packaged-food match from Open Food Facts.",
              "ingredients": [{ "name": "Milk" }],
              "claims": [],
              "tags": [],
              "alternativeIDs": [],
              "notes": [],
              "lookupTokens": ["greek", "yogurt"],
              "resolution": {
                "canonical_product_id": "off:7501031311309",
                "source": "openFoodFacts",
                "confidence": 0.42,
                "nutrition_snapshot": null,
                "is_directional": false
              }
            }
            """#.utf8
        )

        let product = try JSONDecoder().decode(ProductCandidate.self, from: payload)

        XCTAssertNil(product.resolutionSemantics)
        XCTAssertEqual(
            product.resolvedResolutionSemantics,
            [.canonical, .providerBacked, .lowConfidence]
        )
    }

    func testProductGraphKeyPrefersExplicitProvisionalSemanticOverLegacyFallbacks() {
        var analysis = makeAnalysis(barcode: "850000001", source: .labelPhoto)
        analysis.resolvedProduct.id = "product-manual"
        analysis.resolvedProduct.resolution = nil
        analysis.resolvedProduct.resolutionSemantics = [.provisional]

        XCTAssertEqual(analysis.productGraphKey(scanEventID: "scan-semantic"), "scan:scan-semantic")
        XCTAssertEqual(analysis.productReference(scanEventID: "scan-semantic").graphID, "scan:scan-semantic")
    }

    func testLILAVerdictResolvedProductPreservesExplicitResolutionSemantics() {
        var analysis = makeRemoteReadyAnalysis()
        analysis.resolvedProduct.resolutionSemantics = [.canonical, .providerBacked]

        let verdict = analysis.lilaVerdict(context: UserContext.starter.lilaContext())

        XCTAssertEqual(verdict.resolvedProduct.resolutionSemantics, [.canonical, .providerBacked])
        XCTAssertEqual(verdict.resolvedProduct.resolvedResolutionSemantics, [.canonical, .providerBacked])
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

    func testScanVerdictSurfaceContentPrefersVerdictHierarchyAndTrimsWatchouts() {
        let verdict = makeVerdict(fit: .occasional, watchoutCount: 3)
        let content = ScanVerdictSurfaceContent.build(verdict: verdict)

        XCTAssertEqual(content.productName, verdict.resolvedProduct.name)
        XCTAssertEqual(content.fitTitle, "Occasional")
        XCTAssertEqual(content.headline, "Custom verdict headline.")
        XCTAssertEqual(content.primaryReason, "Primary reason customized for the verdict surface.")
        XCTAssertEqual(content.confidenceTitle, "Medium confidence")
        XCTAssertEqual(content.sourceTitle, "Manual barcode")
        XCTAssertEqual(content.watchouts.count, 2)
        XCTAssertEqual(content.betterSwapTitle, "Softer swap")
        XCTAssertEqual(content.followUpPrompt, "Did this feel steadier a few hours later?")
    }

    func testScanVerdictSurfaceContentMarksDirectionalLabelRead() {
        var verdict = makeVerdict(fit: .unclear, source: .labelPhoto, watchoutCount: 1)
        verdict.resolvedProduct.name = "Directional label read"
        verdict.resolvedProduct.resolutionSource = .agentInferred

        let content = ScanVerdictSurfaceContent.build(verdict: verdict)

        XCTAssertEqual(content.sourceTitle, "Label photo")
        XCTAssertEqual(content.readStateTitle, "Directional label read")
        XCTAssertEqual(content.provenanceTitle, "Directional inference")
        XCTAssertTrue(content.metadataSummary.contains("Directional label read"))
        XCTAssertNotNil(content.guidanceNote)
    }

    @MainActor
    func testAppModelSynthesizesScanVerdictLookupForLegacyScanEvent() async throws {
        let input = ScanInput(
            sourceType: .manualBarcode,
            barcode: "850000001",
            capturedImageRef: nil,
            rawText: nil,
            productTypeHint: nil,
            locale: "en_US"
        )
        let analysis = try await DemoScanService().analyze(input: input, userContext: .starter)
        let event = RootOrchestrator().composeScanEvent(
            input: input,
            legacyAnalysis: analysis,
            structuredAnalysis: nil,
            localProfileID: UUID().uuidString,
            recentScans: [],
            recentCheckIns: [],
            latencyMs: 120
        )
        let store = InMemoryStore(snapshot: .fresh())
        store.snapshot.scanEvents = [event]

        let model = AppModel(services: makeServices(store: store))
        let verdict = try XCTUnwrap(model.scanVerdict(for: analysis))

        XCTAssertEqual(model.scanVerdicts.count, 1)
        XCTAssertEqual(model.scanVerdicts.first?.scanEventID, event.id)
        XCTAssertEqual(verdict.resolvedProduct.name, analysis.resolvedProduct.name)
        XCTAssertEqual(model.latestVerdict?.id, verdict.id)
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
    func testStrategistUsesSharedThreadAcrossEntryPoints() async {
        let model = AppModel(services: makeServices())

        model.sendStrategistMessage("What matters most today?", entryPoint: .home)
        let initialCount = model.conversationThread(for: .home).messages.count
        await waitForConversationMessageCount(
            initialCount + 1,
            in: model,
            entryPoint: .home
        )
        let firstCount = model.conversationThread(for: .home).messages.count

        model.sendStrategistMessage("Should this stay in my routine?", entryPoint: .scan)
        await waitForConversationMessageCount(
            firstCount + 2,
            in: model,
            entryPoint: .home
        )

        XCTAssertEqual(model.conversationThreads.count, 1)
        XCTAssertEqual(model.conversationThread(for: .home).messages.count, firstCount + 2)
        XCTAssertEqual(model.conversationThread(for: .scan).messages.count, firstCount + 2)
        XCTAssertEqual(model.conversationThread(for: .scan).title, "Daily strategist")
    }

    @MainActor
    private func waitForConversationMessageCount(
        _ expectedCount: Int,
        in model: AppModel,
        entryPoint: StrategistEntryPoint,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<50 {
            if model.conversationThread(for: entryPoint).messages.count >= expectedCount {
                return
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTFail(
            "Expected at least \(expectedCount) messages for \(entryPoint)",
            file: file,
            line: line
        )
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
    func testAppModelPersistsLatestLILAVerdictAfterAnalyze() async throws {
        let store = InMemoryStore(snapshot: .fresh())
        let biometrics = BiometricsSnapshot(
            capturedAt: .now,
            cycleState: .init(lastPeriodStart: .now, source: .manualEntry),
            trainingLoad: .init(workoutsCount: 2, activeEnergyBurnedKcal: 430, durationMinutes: 90, lastWorkoutEndedAt: .now),
            sleepHours: 7.2,
            hrvMilliseconds: 41,
            restingHeartRate: 57,
            wristTemperatureDeltaCelsius: nil
        )
        let services = makeServices(
            store: store,
            healthKitService: StubHealthKitService(
                report: HealthKitAuthorizationReport(
                    healthDataAvailable: true,
                    cycle: .sharingAuthorized,
                    workouts: .sharingAuthorized,
                    recovery: .sharingAuthorized,
                    sleep: .sharingAuthorized,
                    nutritionWriteBack: .notDetermined
                ),
                snapshot: biometrics
            )
        )
        let model = AppModel(services: services)

        await model.analyzeBarcode("850000001")

        XCTAssertNotNil(model.latestVerdict)
        XCTAssertEqual(model.scanVerdicts.count, 1)
        XCTAssertEqual(store.snapshot.scanVerdicts.count, 1)
        XCTAssertEqual(store.snapshot.scanVerdicts.first?.scanEventID, model.scanEvents.first?.id)
        XCTAssertEqual(model.latestVerdict?.reasoningBreakdown.userHistoryFactors.count, 1)
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
    func testPantryAnalysisUsesStableRelatedProductIdentityBeforeTitleFallback() async throws {
        let analysis = makeRemoteReadyAnalysis()
        let model = AppModel(
            services: makeServices(
                subscriptionStatus: .pro,
                scanService: StubScanService(analysis: analysis)
            )
        )

        await model.analyzeBarcode("850000001")

        let pantryItem = PantryItem(
            id: "pantry-canonical",
            title: "Different shelf title",
            summary: analysis.overallSummary,
            relatedProductID: analysis.resolvedProduct.stableIdentityKey,
            sourceKind: .manualSave,
            sourceScanID: nil,
            createdAt: .now,
            lastUpdatedAt: .now,
            archivedAt: nil
        )

        let linked = try XCTUnwrap(model.pantryAnalysis(for: pantryItem))
        XCTAssertEqual(linked.id, analysis.id)
    }

    @MainActor
    func testPantryRoutineMembershipUsesResolvedProductAliasesBeforeTitleFallback() async throws {
        let analysis = makeRemoteReadyAnalysis()
        let model = AppModel(
            services: makeServices(
                subscriptionStatus: .pro,
                scanService: StubScanService(analysis: analysis)
            )
        )

        await model.analyzeBarcode("850000001")
        let event = try XCTUnwrap(model.scanEvents.first)
        model.routines = [
            RoutineItem(
                productID: analysis.resolvedProduct.id,
                productName: analysis.resolvedProduct.name,
                cadenceSummary: "Keep as a likely repeat choice",
                note: "Saved after a supportive read.",
                createdAt: .now
            )
        ]

        let pantryItem = PantryItem(
            id: "pantry-routine-canonical",
            title: "Mismatched pantry title",
            summary: analysis.overallSummary,
            relatedProductID: analysis.resolvedProduct.stableIdentityKey,
            sourceKind: .manualSave,
            sourceScanID: event.id,
            createdAt: .now,
            lastUpdatedAt: .now,
            archivedAt: nil
        )

        XCTAssertTrue(model.pantryItemIsInRoutine(pantryItem))
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
