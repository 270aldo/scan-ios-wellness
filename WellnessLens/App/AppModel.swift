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
        case .home: "Home"
        case .scan: "Scan"
        case .history: "History"
        case .checkIn: "Check-In"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .scan: "barcode.viewfinder"
        case .history: "clock.arrow.circlepath"
        case .checkIn: "heart.text.square.fill"
        case .profile: "person.crop.circle"
        }
    }
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
    var history: [ScanRecord]
    var checkIns: [CheckInEntry]
    var lastDemoScenarioID: String?
    var latestAnalysis: ScanAnalysis?
    var activeComparison: ProductComparison?
    var scanFeedback: ScanFeedback?
    var isAnalyzing = false
    var subscriptionStatus: SubscriptionStatus
    var remoteInsights: [WeeklyInsight] = []
    var bootstrapCompleted = false

    init(services: AppServices? = nil) {
        let resolvedServices = services ?? AppServices.makePreviewServices()
        self.services = resolvedServices
        let snapshot = resolvedServices.store.load()
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        userContext = snapshot.userContext
        history = snapshot.history.sorted(by: { $0.createdAt > $1.createdAt })
        checkIns = snapshot.checkIns.sorted(by: { $0.createdAt > $1.createdAt })
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

    func completeOnboarding(with context: UserContext) {
        userContext = context
        hasCompletedOnboarding = true
        persist()
        Task {
            await pushUserContextIfNeeded()
            await refreshInsightsIfNeeded()
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

    func addCheckIn(energy: Int, skin: Int, bloatingRelief: Int, cravingControl: Int, mood: Int, note: String) {
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
        persist()
        Task {
            await syncCheckInIfNeeded(checkIn)
            await refreshInsightsIfNeeded()
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
        userContext = context
        persist()
        Task {
            await pushUserContextIfNeeded()
            await refreshInsightsIfNeeded()
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
    }

    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "wellnesslens" else { return }
        if url.host == "tab", let component = url.pathComponents.dropFirst().first, let tab = AppTab(rawValue: component) {
            selectedTab = tab
        }
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
            persist()
            await refreshInsightsIfNeeded()
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

    private func pushUserContextIfNeeded() async {
        guard let backendAPI = services.backendAPI else { return }
        _ = try? await backendAPI.getWeeklyInsights(userContext: userContext)
    }

    private func syncCheckInIfNeeded(_ checkIn: CheckInEntry) async {
        guard let backendAPI = services.backendAPI else { return }
        try? await backendAPI.saveCheckIn(checkIn, userContext: userContext)
    }

    private func refreshInsightsIfNeeded() async {
        guard let backendAPI = services.backendAPI else { return }
        do {
            remoteInsights = try await backendAPI.getWeeklyInsights(userContext: userContext)
        } catch {
            remoteInsights = []
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
                lastDemoScenarioID: lastDemoScenarioID
            )
        )
    }
}
