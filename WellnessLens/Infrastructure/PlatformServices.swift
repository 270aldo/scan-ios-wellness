@preconcurrency import AppIntents
import AVFoundation
import Foundation
import SwiftUI
import UIKit
@preconcurrency import Vision

struct StoredAppState: Codable {
    var schemaVersion: Int
    var localProfileID: String
    var hasCompletedOnboarding: Bool
    var onboardingDraft: OnboardingDraft?
    var userContext: UserContext
    var history: [ScanRecord]
    var checkIns: [CheckInEntry]
    var scanEvents: [ScanEvent]
    var scanVerdicts: [StoredScanVerdict]
    var checkInEvents: [CheckInEvent]
    var favoriteItems: [FavoriteItem]
    var consentRecords: [ConsentRecord]
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
    var patternInsights: [PatternInsight]
    var weeklyNarrative: WeeklyInsightNarrative?
    var pantryItems: [PantryItem]
    var entitlementSnapshot: EntitlementSnapshot

    static func fresh() -> StoredAppState {
        StoredAppState(
            schemaVersion: 6,
            localProfileID: UUID().uuidString,
            hasCompletedOnboarding: false,
            onboardingDraft: nil,
            userContext: .starter,
            history: [],
            checkIns: [],
            scanEvents: [],
            scanVerdicts: [],
            checkInEvents: [],
            favoriteItems: [],
            consentRecords: [],
            subscriptionStatus: .free,
            lastDemoScenarioID: nil,
            userProfile: nil,
            activeGoals: [],
            firstWeekPlan: nil,
            routines: [],
            memoryItems: [],
            scanDecisions: [],
            experiments: [],
            conversationThreads: [],
            patternInsights: [],
            weeklyNarrative: nil,
            pantryItems: [],
            entitlementSnapshot: AccessPolicy().snapshot(
                subscriptionStatus: .free,
                billingMode: .demo,
                now: .distantPast
            )
        )
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case localProfileID
        case hasCompletedOnboarding
        case onboardingDraft
        case userContext
        case history
        case checkIns
        case scanEvents
        case scanVerdicts
        case checkInEvents
        case favoriteItems
        case consentRecords
        case subscriptionStatus
        case lastDemoScenarioID
        case userProfile
        case activeGoals
        case firstWeekPlan
        case routines
        case memoryItems
        case scanDecisions
        case experiments
        case conversationThreads
        case patternInsights
        case weeklyNarrative
        case pantryItems
        case entitlementSnapshot
    }

    init(
        schemaVersion: Int,
        localProfileID: String,
        hasCompletedOnboarding: Bool,
        onboardingDraft: OnboardingDraft?,
        userContext: UserContext,
        history: [ScanRecord],
        checkIns: [CheckInEntry],
        scanEvents: [ScanEvent],
        scanVerdicts: [StoredScanVerdict],
        checkInEvents: [CheckInEvent],
        favoriteItems: [FavoriteItem],
        consentRecords: [ConsentRecord],
        subscriptionStatus: SubscriptionStatus,
        lastDemoScenarioID: String?,
        userProfile: UserProfile?,
        activeGoals: [ActiveGoal],
        firstWeekPlan: FirstWeekPlan?,
        routines: [RoutineItem],
        memoryItems: [MemoryItem],
        scanDecisions: [ScanDecision],
        experiments: [Experiment],
        conversationThreads: [ConversationThread],
        patternInsights: [PatternInsight],
        weeklyNarrative: WeeklyInsightNarrative?,
        pantryItems: [PantryItem],
        entitlementSnapshot: EntitlementSnapshot
    ) {
        self.schemaVersion = schemaVersion
        self.localProfileID = localProfileID
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.onboardingDraft = onboardingDraft
        self.userContext = userContext
        self.history = history
        self.checkIns = checkIns
        self.scanEvents = scanEvents
        self.scanVerdicts = scanVerdicts
        self.checkInEvents = checkInEvents
        self.favoriteItems = favoriteItems
        self.consentRecords = consentRecords
        self.subscriptionStatus = subscriptionStatus
        self.lastDemoScenarioID = lastDemoScenarioID
        self.userProfile = userProfile
        self.activeGoals = activeGoals
        self.firstWeekPlan = firstWeekPlan
        self.routines = routines
        self.memoryItems = memoryItems
        self.scanDecisions = scanDecisions
        self.experiments = experiments
        self.conversationThreads = conversationThreads
        self.patternInsights = patternInsights
        self.weeklyNarrative = weeklyNarrative
        self.pantryItems = pantryItems
        self.entitlementSnapshot = entitlementSnapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let decodedLocalProfileID = try container.decodeIfPresent(String.self, forKey: .localProfileID) ?? UUID().uuidString
        localProfileID = decodedLocalProfileID
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        onboardingDraft = try container.decodeIfPresent(OnboardingDraft.self, forKey: .onboardingDraft)
        userContext = try container.decodeIfPresent(UserContext.self, forKey: .userContext) ?? .starter
        let decodedHistory = try container.decodeIfPresent([ScanRecord].self, forKey: .history) ?? []
        let decodedCheckIns = try container.decodeIfPresent([CheckInEntry].self, forKey: .checkIns) ?? []
        history = decodedHistory
        checkIns = decodedCheckIns
        let decodedScanEvents = try container.decodeIfPresent([ScanEvent].self, forKey: .scanEvents) ?? []
        let decodedScanVerdicts = try container.decodeIfPresent([StoredScanVerdict].self, forKey: .scanVerdicts) ?? []
        let decodedCheckInEvents = try container.decodeIfPresent([CheckInEvent].self, forKey: .checkInEvents) ?? []
        favoriteItems = try container.decodeIfPresent([FavoriteItem].self, forKey: .favoriteItems) ?? []
        consentRecords = try container.decodeIfPresent([ConsentRecord].self, forKey: .consentRecords) ?? []
        subscriptionStatus = try container.decodeIfPresent(SubscriptionStatus.self, forKey: .subscriptionStatus) ?? .free
        lastDemoScenarioID = try container.decodeIfPresent(String.self, forKey: .lastDemoScenarioID)
        userProfile = try container.decodeIfPresent(UserProfile.self, forKey: .userProfile)
        let profileForVerdicts = userProfile ?? UserProfile.migrated(from: userContext)
        activeGoals = try container.decodeIfPresent([ActiveGoal].self, forKey: .activeGoals) ?? []
        firstWeekPlan = try container.decodeIfPresent(FirstWeekPlan.self, forKey: .firstWeekPlan)
        routines = try container.decodeIfPresent([RoutineItem].self, forKey: .routines) ?? []
        memoryItems = try container.decodeIfPresent([MemoryItem].self, forKey: .memoryItems) ?? []
        scanDecisions = try container.decodeIfPresent([ScanDecision].self, forKey: .scanDecisions) ?? []
        experiments = try container.decodeIfPresent([Experiment].self, forKey: .experiments) ?? []
        conversationThreads = try container.decodeIfPresent([ConversationThread].self, forKey: .conversationThreads) ?? []
        patternInsights = try container.decodeIfPresent([PatternInsight].self, forKey: .patternInsights) ?? []
        weeklyNarrative = try container.decodeIfPresent(WeeklyInsightNarrative.self, forKey: .weeklyNarrative)
        pantryItems = try container.decodeIfPresent([PantryItem].self, forKey: .pantryItems) ?? []
        entitlementSnapshot = try container.decodeIfPresent(EntitlementSnapshot.self, forKey: .entitlementSnapshot)
            ?? AccessPolicy().snapshot(subscriptionStatus: subscriptionStatus, billingMode: .demo, now: .distantPast)

        if decodedScanEvents.isEmpty {
            scanEvents = decodedHistory.map { record in
                let input = ScanInput(
                    sourceType: record.analysis.source,
                    barcode: record.analysis.resolvedProduct.barcode,
                    capturedImageRef: nil,
                    rawText: record.analysis.resolvedProduct.ingredients.map(\.name).joined(separator: ", "),
                    productTypeHint: record.analysis.productType,
                    locale: Locale.current.identifier
                )
                let envelope = record.analysis.makeEnvelope(input: input, recentScans: [], recentCheckIns: [])
                let normalizedPayload = NormalizedScanPayload(
                    source: record.analysis.source.analysisInputType,
                    entityName: record.analysis.resolvedProduct.name,
                    brand: record.analysis.resolvedProduct.brand,
                    productType: record.analysis.productType,
                    ingredients: record.analysis.resolvedProduct.ingredients.map(\.name),
                    claims: record.analysis.resolvedProduct.claims,
                    extractedText: input.rawText,
                    inferredTags: record.analysis.resolvedProduct.tags.map(\.rawValue)
                )
                return ScanEvent(
                    id: record.id.uuidString,
                    timestamp: record.createdAt,
                    localProfileID: decodedLocalProfileID,
                    inputType: record.analysis.source.analysisInputType,
                    normalizedPayload: normalizedPayload,
                    analysis: envelope,
                    legacyAnalysis: record.analysis,
                    sourceAgents: ["DeterministicScoringEngine", "MigrationBootstrap"],
                    latencyMs: 0
                )
            }
        } else {
            scanEvents = decodedScanEvents
        }

        if decodedScanVerdicts.isEmpty {
            let context = profileForVerdicts.lilaContext()
            scanVerdicts = scanEvents.map { event in
                let verdict = event.analysis.lilaVerdict(
                    fallbackAnalysis: event.legacyAnalysis,
                    context: context
                )
                return StoredScanVerdict(
                    scanEventID: event.id,
                    verdict: verdict,
                    createdAt: event.timestamp
                )
            }
        } else {
            scanVerdicts = decodedScanVerdicts
        }

        if decodedCheckInEvents.isEmpty {
            checkInEvents = decodedCheckIns.map { entry in
                entry.makeEvent(localProfileID: decodedLocalProfileID, linkedScanIDs: [], readHelpful: nil, satiety: 3)
            }
        } else {
            checkInEvents = decodedCheckInEvents
        }

        if favoriteItems.isEmpty {
            favoriteItems = history.filter(\.isFavorite).map {
                FavoriteItem(
                    id: UUID().uuidString,
                    scanEventID: $0.id.uuidString,
                    createdAt: $0.createdAt,
                    title: $0.analysis.resolvedProduct.name,
                    summary: $0.analysis.overallSummary
                )
            }
        }

        if consentRecords.isEmpty, let userProfile {
            consentRecords = [
                ConsentRecord(
                    localProfileID: decodedLocalProfileID,
                    policyVersion: "phase1-v1",
                    flags: userProfile.consentFlags,
                    createdAt: userProfile.createdAt
                )
            ]
        }

        if hasCompletedOnboarding {
            onboardingDraft = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(localProfileID, forKey: .localProfileID)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encodeIfPresent(onboardingDraft, forKey: .onboardingDraft)
        try container.encode(userContext, forKey: .userContext)
        try container.encode(history, forKey: .history)
        try container.encode(checkIns, forKey: .checkIns)
        try container.encode(scanEvents, forKey: .scanEvents)
        try container.encode(scanVerdicts, forKey: .scanVerdicts)
        try container.encode(checkInEvents, forKey: .checkInEvents)
        try container.encode(favoriteItems, forKey: .favoriteItems)
        try container.encode(consentRecords, forKey: .consentRecords)
        try container.encode(subscriptionStatus, forKey: .subscriptionStatus)
        try container.encode(lastDemoScenarioID, forKey: .lastDemoScenarioID)
        try container.encode(userProfile, forKey: .userProfile)
        try container.encode(activeGoals, forKey: .activeGoals)
        try container.encode(firstWeekPlan, forKey: .firstWeekPlan)
        try container.encode(routines, forKey: .routines)
        try container.encode(memoryItems, forKey: .memoryItems)
        try container.encode(scanDecisions, forKey: .scanDecisions)
        try container.encode(experiments, forKey: .experiments)
        try container.encode(conversationThreads, forKey: .conversationThreads)
        try container.encode(patternInsights, forKey: .patternInsights)
        try container.encode(weeklyNarrative, forKey: .weeklyNarrative)
        try container.encode(pantryItems, forKey: .pantryItems)
        try container.encode(entitlementSnapshot, forKey: .entitlementSnapshot)
    }
}

protocol AppDataStore {
    func load() -> StoredAppState
    func save(_ state: StoredAppState)
}

@MainActor
protocol SubscriptionClient: AnyObject {
    var status: SubscriptionStatus { get }
    func purchase(_ target: SubscriptionStatus) async -> SubscriptionStatus
    func restore() async -> SubscriptionStatus
}

protocol ScanService: Sendable {
    var featuredProducts: [ProductCandidate] { get }
    func analyze(input: ScanInput, userContext: UserContext) async throws -> ScanAnalysis
}

enum ScanServiceError: LocalizedError {
    case emptyInput
    case unresolvedScan

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            "Add a barcode, ingredient label, meal snapshot, or demo product before analyzing."
        case .unresolvedScan:
            "We could not confidently resolve this item yet. Try a cleaner label photo, a meal note, or a barcode."
        }
    }
}

final class LocalAppDataStore: AppDataStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String = "WellnessLensState.json") {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleDirectory = supportDirectory.appendingPathComponent("WellnessLens", isDirectory: true)
        try? FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)
        fileURL = bundleDirectory.appendingPathComponent(filename)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> StoredAppState {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .fresh()
        }
        return (try? decoder.decode(StoredAppState.self, from: data)) ?? .fresh()
    }

    func save(_ state: StoredAppState) {
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

@MainActor
final class DemoSubscriptionController: SubscriptionClient {
    private(set) var status: SubscriptionStatus

    init(status: SubscriptionStatus = .free) {
        self.status = status
    }

    func purchase(_ target: SubscriptionStatus) async -> SubscriptionStatus {
        status = target
        return status
    }

    func restore() async -> SubscriptionStatus {
        status
    }
}

final class DemoScanService: ScanService, @unchecked Sendable {
    let featuredProducts: [ProductCandidate]
    private let analysisEngine = AnalysisEngine()
    private let catalog: [ProductCandidate]

    init(catalog: [ProductCandidate] = SampleCatalog.products) {
        self.catalog = catalog
        self.featuredProducts = Array(catalog.prefix(5))
    }

    func analyze(input: ScanInput, userContext: UserContext) async throws -> ScanAnalysis {
        guard input.barcode?.isEmpty == false || input.rawText?.isEmpty == false else {
            throw ScanServiceError.emptyInput
        }

        let resolution = resolveProduct(from: input)
        guard let product = resolution.product else {
            throw ScanServiceError.unresolvedScan
        }

        return analysisEngine.analyze(
            product: product,
            userContext: userContext,
            source: input.sourceType,
            confidence: resolution.confidence,
            catalog: catalog
        )
    }

    private func resolveProduct(from input: ScanInput) -> (product: ProductCandidate?, confidence: ConfidenceLevel) {
        if let barcode = input.barcode?.trimmingCharacters(in: .whitespacesAndNewlines), !barcode.isEmpty {
            if let exact = catalog.first(where: { $0.barcode == barcode }) {
                return (exact, .high)
            }
        }

        if let rawText = input.rawText?.lowercased(), !rawText.isEmpty {
            let bestMatch = catalog
                .map { product in
                    let score = product.lookupTokens.reduce(into: 0) { partial, token in
                        if rawText.contains(token.lowercased()) {
                            partial += 1
                        }
                    }
                    return (product, score)
                }
                .max(by: { $0.1 < $1.1 })

            if let bestMatch, bestMatch.1 >= 2 {
                return (bestMatch.0, .medium)
            }

            let inferredTags = inferTags(from: rawText)
            if !inferredTags.isEmpty {
            let inferredProduct = ProductCandidate(
                id: "custom-\(UUID().uuidString)",
                name: {
                    switch input.sourceType {
                    case .mealPhoto:
                        "Meal Snapshot"
                    case .menuPhoto:
                        "Menu Choice"
                    default:
                        "Custom Label Scan"
                    }
                }(),
                brand: "Manual analysis",
                productType: input.productTypeHint ?? .food,
                barcode: nil,
                headline: {
                    switch input.sourceType {
                    case .mealPhoto:
                        "Resolved from a meal snapshot. Best used as a directional wellness read."
                    case .menuPhoto:
                        "Resolved from a menu photo. Best used as a directional restaurant read."
                    default:
                        "Resolved from your label text. Best used as a directional read."
                    }
                }(),
                ingredients: rawText.split(separator: ",").prefix(5).map { Ingredient(name: $0.trimmingCharacters(in: .whitespacesAndNewlines).capitalized) },
                claims: [{
                    switch input.sourceType {
                    case .mealPhoto:
                        "Resolved from meal snapshot"
                    case .menuPhoto:
                        "Resolved from menu photo"
                    default:
                        "Resolved from OCR / manual label input"
                    }
                }()],
                tags: inferredTags,
                alternativeIDs: [],
                notes: ["This product was inferred from text, so keep the confidence lower."],
                lookupTokens: []
            )
                return (inferredProduct, .low)
            }
        }

        return (nil, .low)
    }

    private func inferTags(from rawText: String) -> [IngredientTag] {
        var tags: Set<IngredientTag> = []
        let mappings: [(String, IngredientTag)] = [
            ("protein", .proteinDense),
            ("whey", .proteinDense),
            ("probiotic", .probiotic),
            ("lactobacillus", .probiotic),
            ("fiber", .fiberSupport),
            ("oat", .fiberSupport),
            ("caffeine", .stimulant),
            ("sugar", .sugarSpike),
            ("collagen", .collagen),
            ("niacinamide", .niacinamide),
            ("peptide", .peptide),
            ("hyaluronic", .hyaluronicAcid),
            ("retinol", .retinoid),
            ("fragrance", .fragrance),
            ("alcohol denat", .alcoholDrying),
            ("sulfate", .harshSurfactants),
            ("zinc oxide", .mineralSPF),
            ("green tea", .antioxidantBlend),
            ("polysorbate", .emulsifierHeavy),
            ("erythritol", .sugarAlcohol),
            ("salmon", .proteinDense),
            ("chicken", .proteinDense),
            ("egg", .proteinDense),
            ("lentil", .fiberSupport),
            ("beans", .fiberSupport),
            ("rice", .sugarSpike),
            ("fries", .ultraProcessed),
            ("burger", .ultraProcessed),
            ("soda", .sugarSpike),
            ("salad", .fiberSupport),
            ("avocado", .omegaSupport)
        ]

        for (keyword, tag) in mappings where rawText.contains(keyword) {
            tags.insert(tag)
        }
        return Array(tags)
    }
}

struct WellnessFeatureFlags: Codable, Hashable {
    var newOnboarding = true
    var newHome = true
    var homeSurfaceV2 = true
    var strategist = true
    var dailyBrief = true
    var structuredAnalysis = true
    var mealSnapshot = true
    var safetyGuard = true
    var patternAgent = true
    var weeklyInsightV2 = true
    var menuScanner = true
    var pantryMVP = true
    var contextualPaywall = true
    var entitlementsV2 = true
}

struct AppServices {
    var configuration: RuntimeConfiguration
    var firebaseBootstrapState: FirebaseBootstrap.State = .disabled
    var featureFlags: WellnessFeatureFlags
    var store: AppDataStore
    var scanService: ScanService
    var subscription: SubscriptionClient
    var labelOCRService: LabelOCRService
    var backendAPI: WellnessBackendAPI?
    var identityProvider: IdentityProviding
    var scanVerdictAgent: ScanVerdictServing = DeterministicScanVerdictAgent()
    var coachAgent: any CoachAgentServing = DeterministicCoachAgent()
    var healthKitService: HealthKitServicing = NoopHealthKitService()

    @MainActor
    static func makePreviewServices() -> AppServices {
        let configuration = RuntimeConfiguration.load()
        let firebaseBootstrapState = FirebaseBootstrap.configureIfNeeded(using: configuration)
        let firebaseRuntimeReady = firebaseBootstrapState == .configured

        let store = LocalAppDataStore()
        let snapshot = store.load()
        let identityProvider: IdentityProviding = {
            #if canImport(FirebaseAuth)
            if configuration.isFirebaseEnabled, firebaseRuntimeReady {
                return FirebaseIdentityProvider()
            }
            #endif
            return LocalInstallIdentityProvider()
        }()

        let appCheckProvider: AppCheckTokenProviding = {
            #if canImport(FirebaseAppCheck)
            if configuration.isFirebaseEnabled, firebaseRuntimeReady {
                return FirebaseAppCheckTokenProvider()
            }
            #endif
            return NoAppCheckTokenProvider()
        }()

        let backendAPI: WellnessBackendAPI? = configuration.backendBaseURL.map {
            HTTPWellnessBackendAPI(
                baseURL: $0,
                identityProvider: identityProvider,
                appCheckProvider: appCheckProvider
            )
        }

        let scanService: ScanService
        if configuration.useDemoData || backendAPI == nil {
            scanService = DemoScanService()
        } else {
            scanService = CloudScanService(backendAPI: backendAPI!)
        }

        let subscription: SubscriptionClient
        if configuration.isStoreKitEnabled {
            subscription = StoreKitSubscriptionController(configuration: configuration)
        } else {
            subscription = DemoSubscriptionController(status: snapshot.subscriptionStatus)
        }

        let scanVerdictAgent: ScanVerdictServing = configuration.agentServiceBaseURL.map {
            RemoteScanVerdictAgent(
                endpoint: $0.appending(path: "v1/scan/verdict"),
                identityProvider: identityProvider,
                appCheckProvider: appCheckProvider
            )
        } ?? DeterministicScanVerdictAgent()

        let coachAgent: any CoachAgentServing = configuration.agentServiceBaseURL.map {
            RemoteCoachAgent(
                endpoint: $0.appending(path: "v1/coach/reply"),
                identityProvider: identityProvider,
                appCheckProvider: appCheckProvider
            )
        } ?? DeterministicCoachAgent()

        return AppServices(
            configuration: configuration,
            firebaseBootstrapState: firebaseBootstrapState,
            featureFlags: WellnessFeatureFlags(),
            store: store,
            scanService: scanService,
            subscription: subscription,
            labelOCRService: LabelOCRService(),
            backendAPI: backendAPI,
            identityProvider: identityProvider,
            scanVerdictAgent: scanVerdictAgent,
            coachAgent: coachAgent,
            healthKitService: {
                #if canImport(HealthKit)
                return HealthKitService()
                #else
                return NoopHealthKitService()
                #endif
            }()
        )
    }
}

actor LabelOCRService {
    func recognizeText(from imageData: Data) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let lines = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .filter { !$0.isEmpty } ?? []

                continuation.resume(returning: lines.joined(separator: ", "))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let handler = VNImageRequestHandler(data: imageData, options: [:])
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum IntentRoute: String {
    case scan
    case history
    case insights

    var tab: AppTab {
        switch self {
        case .scan: .scan
        case .history: .history
        case .insights: .checkIn
        }
    }
}

enum IntentBridge {
    private static let key = "WellnessLens.IntentRoute"

    static func queue(_ route: IntentRoute) {
        UserDefaults.standard.set(route.rawValue, forKey: key)
    }

    static func consume() -> IntentRoute? {
        guard let rawValue = UserDefaults.standard.string(forKey: key),
              let route = IntentRoute(rawValue: rawValue) else {
            return nil
        }
        UserDefaults.standard.removeObject(forKey: key)
        return route
    }
}

enum AppShortcutDestination: String, AppEnum {
    case scan
    case history
    case insights

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Destination")
    static let caseDisplayRepresentations: [AppShortcutDestination: DisplayRepresentation] = [
        .scan: "Scan",
        .history: "History",
        .insights: "Insights"
    ]

    var route: IntentRoute {
        switch self {
        case .scan: .scan
        case .history: .history
        case .insights: .insights
        }
    }
}

struct OpenWellnessDestinationIntent: AppIntent {
    static let title: LocalizedStringResource = "Open WellnessLens"
    static let description = IntentDescription("Jump directly to scan, history, or your weekly insight stack.")
    static let openAppWhenRun = true

    @Parameter(title: "Destination")
    var destination: AppShortcutDestination

    init() {}

    init(destination: AppShortcutDestination) {
        self.destination = destination
    }

    func perform() async throws -> some IntentResult {
        IntentBridge.queue(destination.route)
        return .result()
    }
}

struct WellnessLensShortcuts: AppShortcutsProvider {
    static let appShortcuts: [AppShortcut] = [
        AppShortcut(
            intent: OpenWellnessDestinationIntent(destination: .scan),
            phrases: ["Open \(.applicationName) scan", "Scan a product in \(.applicationName)"],
            shortTitle: "Open Scan",
            systemImageName: "barcode.viewfinder"
        ),
        AppShortcut(
            intent: OpenWellnessDestinationIntent(destination: .history),
            phrases: ["Open \(.applicationName) history", "Show my saved scans in \(.applicationName)"],
            shortTitle: "Open History",
            systemImageName: "clock.arrow.circlepath"
        ),
        AppShortcut(
            intent: OpenWellnessDestinationIntent(destination: .insights),
            phrases: ["Open \(.applicationName) insights", "Show my weekly insight in \(.applicationName)"],
            shortTitle: "Open Insights",
            systemImageName: "waveform.path.ecg"
        )
    ]
}

enum ScannerPermissionState: Equatable {
    case unknown
    case ready
    case cameraDenied
    case photoLibraryDenied
    case unavailable(String)

    var title: String {
        switch self {
        case .unknown, .ready:
            ""
        case .cameraDenied:
            "Camera access is off"
        case .photoLibraryDenied:
            "Photo access is off"
        case .unavailable:
            "Scanner unavailable"
        }
    }

    var message: String {
        switch self {
        case .unknown, .ready:
            ""
        case .cameraDenied:
            "Use a label photo or enter a barcode manually instead of live camera scanning."
        case .photoLibraryDenied:
            "Type label text or analyze a barcode manually until photo access is available."
        case let .unavailable(message):
            message
        }
    }

    var symbol: String {
        switch self {
        case .unknown, .ready:
            "checkmark.circle"
        case .cameraDenied:
            "camera.fill.badge.xmark"
        case .photoLibraryDenied:
            "photo.badge.exclamationmark"
        case .unavailable:
            "exclamationmark.triangle.fill"
        }
    }
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCodeScanned: @MainActor (String) -> Void
    let onUnavailable: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned, onUnavailable: onUnavailable)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.metadataDelegate = context.coordinator
        controller.onUnavailable = context.coordinator.reportUnavailable
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onCodeScanned: @MainActor (String) -> Void
        private let onUnavailable: @MainActor (String) -> Void

        init(
            onCodeScanned: @escaping @MainActor (String) -> Void,
            onUnavailable: @escaping @MainActor (String) -> Void
        ) {
            self.onCodeScanned = onCodeScanned
            self.onUnavailable = onUnavailable
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let codeObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = codeObject.stringValue else {
                return
            }

            let onCodeScanned = self.onCodeScanned
            Task { @MainActor in
                onCodeScanned(code)
            }
        }

        func reportUnavailable(_ message: String) {
            let onUnavailable = self.onUnavailable
            Task { @MainActor in
                onUnavailable(message)
            }
        }
    }
}

final class ScannerViewController: UIViewController {
    var metadataDelegate: AVCaptureMetadataOutputObjectsDelegate?
    var onUnavailable: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.setupSession() : self?.reportUnavailable("Camera access is needed for live barcode scanning.")
                }
            }
        default:
            reportUnavailable("Camera access is unavailable here. Use manual barcode entry or a label photo.")
        }
    }

    private func setupSession() {
        guard let captureDevice = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            reportUnavailable("Live camera scanning is unavailable on this device.")
            return
        }

        session.beginConfiguration()

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(metadataDelegate, queue: .main)
            output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]
        }

        session.commitConfiguration()

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer

        session.startRunning()
    }

    private func showMessage(_ message: String) {
        view.addSubview(messageLabel)
        messageLabel.text = message
        NSLayoutConstraint.activate([
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func reportUnavailable(_ message: String) {
        if let onUnavailable {
            onUnavailable(message)
        } else {
            showMessage(message)
        }
    }
}
