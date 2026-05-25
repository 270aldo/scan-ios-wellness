import Foundation
import StoreKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

struct AnalyzeProductRequest: Codable {
    let input: ScanInput
    let userContext: UserContext
    let scanContext: ScanContext?
    let installID: String
}

struct AnalyzeProductResponse: Codable {
    let analysis: ScanAnalysis
}

struct AnalyzeStructuredScanRequest: Codable {
    let input: ScanInput
    let profile: UserProfile
    let recentScans: [ScanEvent]
    let recentCheckIns: [CheckInEvent]
    let scanContext: ScanContext?
    let installID: String
}

struct AnalyzeStructuredScanResponse: Codable {
    let analysis: AnalysisEnvelope
}

struct ResolveScanRequest: Codable {
    let input: ScanInput
    let installID: String
}

struct ResolveScanResponse: Codable {
    let resolvedProduct: ProductCandidate
    let confidence: ConfidenceLevel
}

struct CompareProductsRequest: Codable {
    let left: ScanAnalysis
    let right: ScanAnalysis
    let installID: String
}

struct SaveCheckInRequest: Codable {
    let checkIn: CheckInEntry
    let userContext: UserContext
    let installID: String
}

struct SaveCheckInEventRequest: Codable {
    let event: CheckInEvent
    let installID: String
}

struct WeeklyInsightsRequest: Codable {
    let userContext: UserContext
    let installID: String
}

struct WeeklyInsightsResponse: Codable {
    let insights: [WeeklyInsight]
}

struct CompleteOnboardingRequest: Codable {
    let profile: UserProfile
    let activeGoals: [ActiveGoal]
    let firstWeekPlan: FirstWeekPlan?
    let installID: String
}

struct SaveScanDecisionRequest: Codable {
    let decision: ScanDecision
    let installID: String
}

struct UpsertMemoryRequest: Codable {
    let memoryItems: [MemoryItem]
    let installID: String
}

struct DailyHomeRequest: Codable {
    let profile: UserProfile
    let activeGoals: [ActiveGoal]
    let installID: String
}

struct DailyHomeResponse: Codable {
    let payload: DailyHomePayload
    let payloadV2: DailyHomePayloadV2?
}

struct ClientKillSwitches: Codable {
    let scanDisabled: Bool
    let strategistDisabled: Bool
    let homeDisabled: Bool
}

struct ClientConfigResponse: Codable {
    let environment: String
    let minimumSupportedVersion: String
    let minimumSupportedBuild: Int
    let copyVersion: String
    let persistenceMode: String
    let firebaseAuthEnforced: Bool
    let appCheckEnforced: Bool
    let agentProviderMode: String
    let flags: WellnessFeatureFlags
    let killSwitches: ClientKillSwitches
    let updatedAt: Date
}

struct DailyBriefResponse: Codable {
    let brief: DailyBrief
}

struct AlternativesRequest: Codable {
    let analysis: ScanAnalysis
    let userContext: UserContext
    let installID: String
}

struct AlternativesResponse: Codable {
    let alternatives: [AlternativeSuggestion]
}

struct HistoryEventsResponse: Codable {
    let scans: [ScanEvent]
    let checkIns: [CheckInEvent]
    let favorites: [FavoriteItem]
}

struct HistorySyncRequest: Codable {
    let installID: String
    let scans: [ScanEvent]
    let checkIns: [CheckInEvent]
    let favorites: [FavoriteItem]
    let memoryItems: [MemoryItem]
    let scanDecisions: [ScanDecision]
}

struct HistorySyncResponse: Codable {
    let installID: String
    let scans: [ScanEvent]
    let checkIns: [CheckInEvent]
    let favorites: [FavoriteItem]
    let memoryItems: [MemoryItem]
    let scanDecisions: [ScanDecision]
    let serverTimestamp: Date
}

struct SaveFavoriteItemRequest: Codable {
    let favorite: FavoriteItem
    let installID: String
}

/// Mirrors `backend-api/app/contracts.py::SubscriptionReportRequest`.
///
/// Sent after StoreKit 2 confirms a verified transaction so the backend can
/// keep a server-side audit trail of entitlements. iOS remains the
/// authoritative entitlement check until server-side signature verification
/// lands; this is strictly an additive audit path.
struct SubscriptionReportRequest: Codable {
    let installID: String
    let productID: String
    let originalTransactionID: String
    let transactionID: String
    let purchasedAt: Date
    let expiresAt: Date?
    let revokedAt: Date?
    let tier: String
    let rawTransactionJWS: String?
}

protocol IdentityProviding: Sendable {
    func prepare() async
    func installID() async -> String
    func authorizationHeader() async -> String?
    /// Revoke the current identity so that the next session starts fresh.
    /// Must be safe to call even when no identity has been established yet.
    func deleteAccount() async
}

protocol AppCheckTokenProviding: Sendable {
    func token() async -> String?
}

protocol WellnessBackendAPI: Sendable {
    func fetchClientConfig() async throws -> ClientConfigResponse
    func analyzeProduct(input: ScanInput, userContext: UserContext, scanContext: ScanContext?) async throws -> ScanAnalysis
    func analyzeStructuredScan(input: ScanInput, profile: UserProfile, recentScans: [ScanEvent], recentCheckIns: [CheckInEvent], scanContext: ScanContext?) async throws -> AnalysisEnvelope
    func resolveScan(input: ScanInput) async throws -> ResolveScanResponse
    func compareProducts(left: ScanAnalysis, right: ScanAnalysis) async throws -> ProductComparison
    func saveCheckIn(_ checkIn: CheckInEntry, userContext: UserContext) async throws
    func saveCheckInEvent(_ event: CheckInEvent) async throws
    func completeOnboarding(profile: UserProfile, activeGoals: [ActiveGoal], firstWeekPlan: FirstWeekPlan?) async throws
    func getWeeklyInsights(userContext: UserContext) async throws -> [WeeklyInsight]
    func fetchDailyHome(profile: UserProfile, activeGoals: [ActiveGoal]) async throws -> DailyHomeResponse
    func fetchDailyBrief(profile: UserProfile, activeGoals: [ActiveGoal]) async throws -> DailyBrief
    func fetchHistoryEvents() async throws -> HistoryEventsResponse
    func syncHistory(
        scans: [ScanEvent],
        checkIns: [CheckInEvent],
        favorites: [FavoriteItem],
        memoryItems: [MemoryItem],
        scanDecisions: [ScanDecision]
    ) async throws -> HistorySyncResponse
    func listAlternatives(for analysis: ScanAnalysis, userContext: UserContext) async throws -> [AlternativeSuggestion]
    func saveScanDecision(_ decision: ScanDecision) async throws
    func saveFavoriteItem(_ favorite: FavoriteItem) async throws
    func upsertMemoryItems(_ memoryItems: [MemoryItem]) async throws
    /// Ask the backend to erase every persisted record for this install.
    /// Implements App Store Review Guideline 5.1.1(v).
    func deleteAccount() async throws
    /// Report a verified StoreKit 2 transaction so the backend can keep an
    /// audit trail of entitlements. Expected to be fire-and-forget: failures
    /// must not prevent the user from getting their entitlement because iOS
    /// StoreKit is the authoritative source of truth today.
    func reportSubscription(_ report: SubscriptionReportRequest) async throws
}

enum BackendClientError: LocalizedError {
    case missingBaseURL
    case invalidResponse
    case httpError(statusCode: Int, detail: String?)
    case transportError(description: String)
    case decodingError(description: String)

    var diagnosticSummary: String {
        switch self {
        case .missingBaseURL:
            return "missing-base-url"
        case .invalidResponse:
            return "invalid-response"
        case let .httpError(statusCode, detail):
            guard let detail, !detail.isEmpty else {
                return "http-\(statusCode)"
            }
            return "http-\(statusCode): \(detail)"
        case let .transportError(description):
            return "transport: \(description)"
        case let .decodingError(description):
            return "decode: \(description)"
        }
    }

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "A backend base URL is required for cloud mode."
        case .invalidResponse:
            return "The backend returned an unexpected payload."
        case let .httpError(statusCode, detail):
            if let detail, !detail.isEmpty {
                return "The backend request failed with status code \(statusCode): \(detail)"
            }
            return "The backend request failed with status code \(statusCode)."
        case let .transportError(description):
            return "The backend request could not be completed: \(description)"
        case let .decodingError(description):
            return "The backend returned an unreadable payload: \(description)"
        }
    }
}

actor LocalInstallIdentityProvider: IdentityProviding {
    private let defaults: UserDefaults
    private let key = "WellnessLens.InstallID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func prepare() async {}

    func installID() async -> String {
        if let existing = defaults.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: key)
        return generated
    }

    func authorizationHeader() async -> String? {
        nil
    }

    func deleteAccount() async {
        defaults.removeObject(forKey: key)
    }
}

#if canImport(FirebaseAuth)
actor FirebaseIdentityProvider: IdentityProviding {
    private let fallback = LocalInstallIdentityProvider()

    func prepare() async {
        if Auth.auth().currentUser == nil {
            _ = try? await Auth.auth().signInAnonymously()
        }
    }

    func installID() async -> String {
        if let current = Auth.auth().currentUser?.uid {
            return current
        }
        return await fallback.installID()
    }

    func authorizationHeader() async -> String? {
        guard let currentUser = Auth.auth().currentUser else { return nil }
        do {
            let token = try await currentUser.getIDToken()
            return "Bearer \(token)"
        } catch {
            return nil
        }
    }

    func deleteAccount() async {
        if let currentUser = Auth.auth().currentUser {
            _ = try? await currentUser.delete()
        }
        try? Auth.auth().signOut()
        await fallback.deleteAccount()
    }
}
#endif

struct NoAppCheckTokenProvider: AppCheckTokenProviding {
    func token() async -> String? { nil }
}

#if canImport(FirebaseAppCheck)
struct FirebaseAppCheckTokenProvider: AppCheckTokenProviding {
    func token() async -> String? {
        do {
            return try await AppCheck.appCheck().token(forcingRefresh: false).token
        } catch {
            return nil
        }
    }
}
#endif

final class HTTPWellnessBackendAPI: WellnessBackendAPI, @unchecked Sendable {
    private let baseURL: URL
    private let urlSession: URLSession
    private let identityProvider: IdentityProviding
    private let appCheckProvider: AppCheckTokenProviding
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let localComparisonEngine = AnalysisEngine()

    init(
        baseURL: URL,
        urlSession: URLSession = .shared,
        identityProvider: IdentityProviding,
        appCheckProvider: AppCheckTokenProviding
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.identityProvider = identityProvider
        self.appCheckProvider = appCheckProvider
    }

    func analyzeProduct(input: ScanInput, userContext: UserContext, scanContext: ScanContext? = nil) async throws -> ScanAnalysis {
        let installID = await identityProvider.installID()
        let request = AnalyzeProductRequest(input: input, userContext: userContext, scanContext: scanContext, installID: installID)
        let response: AnalyzeProductResponse = try await send(path: "analyzeProduct", method: "POST", body: request)
        return response.analysis
    }

    func fetchClientConfig() async throws -> ClientConfigResponse {
        try await send(path: "v1/client-config", method: "GET")
    }

    func analyzeStructuredScan(
        input: ScanInput,
        profile: UserProfile,
        recentScans: [ScanEvent],
        recentCheckIns: [CheckInEvent],
        scanContext: ScanContext? = nil
    ) async throws -> AnalysisEnvelope {
        let installID = await identityProvider.installID()
        let response: AnalyzeStructuredScanResponse = try await send(
            path: "v1/scan/analyze",
            method: "POST",
            body: AnalyzeStructuredScanRequest(
                input: input,
                profile: profile,
                recentScans: recentScans,
                recentCheckIns: recentCheckIns,
                scanContext: scanContext,
                installID: installID
            )
        )
        return response.analysis
    }

    func resolveScan(input: ScanInput) async throws -> ResolveScanResponse {
        let installID = await identityProvider.installID()
        return try await send(path: "resolveScan", method: "POST", body: ResolveScanRequest(input: input, installID: installID))
    }

    func compareProducts(left: ScanAnalysis, right: ScanAnalysis) async throws -> ProductComparison {
        let installID = await identityProvider.installID()
        _ = try? await send(
            path: "compareProducts",
            method: "POST",
            body: CompareProductsRequest(left: left, right: right, installID: installID)
        ) as AlternativesResponse
        return localComparisonEngine.compare(left, right)
    }

    func saveCheckIn(_ checkIn: CheckInEntry, userContext: UserContext) async throws {
        let installID = await identityProvider.installID()
        let _: EmptyResponse = try await send(
            path: "saveCheckIn",
            method: "POST",
            body: SaveCheckInRequest(checkIn: checkIn, userContext: userContext, installID: installID)
        )
    }

    func saveCheckInEvent(_ event: CheckInEvent) async throws {
        let installID = await identityProvider.installID()
        let _: EmptyResponse = try await send(
            path: "v1/scan/feedback",
            method: "POST",
            body: SaveCheckInEventRequest(event: event, installID: installID)
        )
    }

    func getWeeklyInsights(userContext: UserContext) async throws -> [WeeklyInsight] {
        let installID = await identityProvider.installID()
        let response: WeeklyInsightsResponse = try await send(
            path: "v1/home/weekly-insights",
            method: "POST",
            body: WeeklyInsightsRequest(userContext: userContext, installID: installID)
        )
        return response.insights
    }

    func completeOnboarding(
        profile: UserProfile,
        activeGoals: [ActiveGoal],
        firstWeekPlan: FirstWeekPlan?
    ) async throws {
        let installID = await identityProvider.installID()
        let _: EmptyResponse = try await send(
            path: "v1/onboarding/complete",
            method: "POST",
            body: CompleteOnboardingRequest(
                profile: profile,
                activeGoals: activeGoals,
                firstWeekPlan: firstWeekPlan,
                installID: installID
            )
        )
    }

    func fetchDailyHome(
        profile: UserProfile,
        activeGoals: [ActiveGoal]
    ) async throws -> DailyHomeResponse {
        let installID = await identityProvider.installID()
        return try await send(
            path: "v1/home",
            method: "POST",
            body: DailyHomeRequest(profile: profile, activeGoals: activeGoals, installID: installID)
        )
    }

    func fetchDailyBrief(profile: UserProfile, activeGoals: [ActiveGoal]) async throws -> DailyBrief {
        let installID = await identityProvider.installID()
        let response: DailyBriefResponse = try await send(
            path: "v1/daily-brief",
            method: "POST",
            body: DailyHomeRequest(profile: profile, activeGoals: activeGoals, installID: installID)
        )
        return response.brief
    }

    func fetchHistoryEvents() async throws -> HistoryEventsResponse {
        let installID = await identityProvider.installID()
        return try await send(
            path: "v1/history",
            method: "POST",
            body: ["installID": installID]
        )
    }

    func syncHistory(
        scans: [ScanEvent],
        checkIns: [CheckInEvent],
        favorites: [FavoriteItem],
        memoryItems: [MemoryItem],
        scanDecisions: [ScanDecision]
    ) async throws -> HistorySyncResponse {
        let installID = await identityProvider.installID()
        return try await send(
            path: "v1/history/sync",
            method: "POST",
            body: HistorySyncRequest(
                installID: installID,
                scans: scans,
                checkIns: checkIns,
                favorites: favorites,
                memoryItems: memoryItems,
                scanDecisions: scanDecisions
            )
        )
    }

    func listAlternatives(for analysis: ScanAnalysis, userContext: UserContext) async throws -> [AlternativeSuggestion] {
        let installID = await identityProvider.installID()
        let response: AlternativesResponse = try await send(
            path: "v1/scans/alternatives",
            method: "POST",
            body: AlternativesRequest(analysis: analysis, userContext: userContext, installID: installID)
        )
        return response.alternatives
    }

    func saveScanDecision(_ decision: ScanDecision) async throws {
        let installID = await identityProvider.installID()
        let _: EmptyResponse = try await send(
            path: "v1/scans/decision",
            method: "POST",
            body: SaveScanDecisionRequest(decision: decision, installID: installID)
        )
    }

    func saveFavoriteItem(_ favorite: FavoriteItem) async throws {
        let installID = await identityProvider.installID()
        let _: EmptyResponse = try await send(
            path: "v1/favorites",
            method: "POST",
            body: SaveFavoriteItemRequest(favorite: favorite, installID: installID)
        )
    }

    func upsertMemoryItems(_ memoryItems: [MemoryItem]) async throws {
        let installID = await identityProvider.installID()
        let _: EmptyResponse = try await send(
            path: "v1/memory/upsert",
            method: "POST",
            body: UpsertMemoryRequest(memoryItems: memoryItems, installID: installID)
        )
    }

    func deleteAccount() async throws {
        let _: EmptyResponse = try await send(path: "v1/profile", method: "DELETE")
    }

    func reportSubscription(_ report: SubscriptionReportRequest) async throws {
        // The server returns the full `SubscriptionGrant` record, but the
        // iOS side does not consume it yet (StoreKit remains authoritative).
        // `EmptyResponse` is an empty decodable struct that accepts any JSON
        // object regardless of its keys, so we drop the body cheaply.
        let _: EmptyResponse = try await send(
            path: "v1/subscriptions/report",
            method: "POST",
            body: report
        )
    }

    private func send<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        method: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        var request = await makeRequest(path: path, method: method)
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }

    private func send<ResponseBody: Decodable>(
        path: String,
        method: String
    ) async throws -> ResponseBody {
        let request = await makeRequest(path: path, method: method)
        return try await execute(request)
    }

    private func makeRequest(path: String, method: String) async -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let authHeader = await identityProvider.authorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }

        request.setValue(await identityProvider.installID(), forHTTPHeaderField: "X-Wellness-Install-ID")

        if let appCheckToken = await appCheckProvider.token() {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }
        return request
    }

    private func execute<ResponseBody: Decodable>(_ request: URLRequest) async throws -> ResponseBody {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw BackendClientError.transportError(description: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendClientError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw BackendClientError.httpError(
                statusCode: httpResponse.statusCode,
                detail: responseDetail(from: data)
            )
        }

        do {
            return try decoder.decode(ResponseBody.self, from: data)
        } catch {
            throw BackendClientError.decodingError(description: error.localizedDescription)
        }
    }

    private func responseDetail(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = jsonObject["detail"] as? String {
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        guard let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty else {
            return nil
        }
        if raw.count <= 160 {
            return raw
        }
        return String(raw.prefix(157)) + "..."
    }
}

private struct EmptyResponse: Decodable {}

final class CloudScanService: ScanService, @unchecked Sendable {
    let featuredProducts: [ProductCandidate]
    private let backendAPI: WellnessBackendAPI
    private let fallbackCatalog: [ProductCandidate]

    init(backendAPI: WellnessBackendAPI, fallbackCatalog: [ProductCandidate] = SampleCatalog.products) {
        self.backendAPI = backendAPI
        self.fallbackCatalog = fallbackCatalog
        self.featuredProducts = Array(fallbackCatalog.prefix(5))
    }

    func analyze(input: ScanInput, userContext: UserContext, scanContext: ScanContext? = nil) async throws -> ScanAnalysis {
        do {
            return try await backendAPI.analyzeProduct(input: input, userContext: userContext, scanContext: scanContext)
        } catch {
            let fallback = DemoScanService(catalog: fallbackCatalog)
            return try await fallback.analyze(input: input, userContext: userContext, scanContext: scanContext)
        }
    }
}

@MainActor
final class StoreKitSubscriptionController: SubscriptionClient {
    private let configuration: RuntimeConfiguration
    private(set) var status: SubscriptionStatus = .free
    private var cachedProducts: [String: Product] = [:]
    private var productsLoadTask: Task<Void, Never>?
    private var transactionListener: Task<Void, Never>?
    /// Optional backend client. When set, verified transactions are reported
    /// as a fire-and-forget audit trail. Never blocks entitlement delivery.
    private let backendAPI: WellnessBackendAPI?
    /// Optional identity provider so the backend report carries the same
    /// install id that the rest of the API already uses.
    private let identityProvider: IdentityProviding?

    init(
        configuration: RuntimeConfiguration,
        backendAPI: WellnessBackendAPI? = nil,
        identityProvider: IdentityProviding? = nil
    ) {
        self.configuration = configuration
        self.backendAPI = backendAPI
        self.identityProvider = identityProvider
        // Start the long-running Transaction.updates listener so renewals,
        // cancellations, refunds, and cross-device purchases are reflected
        // while the app is open. Apple requires this for StoreKit 2.
        transactionListener = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(transactionUpdate: update)
            }
        }

        // Fire-and-forget product load so the paywall has localized prices
        // without blocking UI.
        productsLoadTask = Task { [weak self] in
            await self?.reloadProducts()
        }

        // Seed status from any currently valid entitlements without forcing a
        // full `AppStore.sync()` (that requires a user gesture / Apple ID).
        Task { [weak self] in
            await self?.reconcileCurrentEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
        productsLoadTask?.cancel()
    }

    private var productIDs: [String] {
        [configuration.plusProductID, configuration.proProductID].compactMap { $0 }
    }

    private func tier(forProductID id: String) -> SubscriptionStatus? {
        if id == configuration.proProductID { return .pro }
        if id == configuration.plusProductID { return .plus }
        return nil
    }

    private func productID(for target: SubscriptionStatus) -> String? {
        switch target {
        case .free: nil
        case .plus: configuration.plusProductID
        case .pro: configuration.proProductID
        }
    }

    private func reloadProducts() async {
        guard !productIDs.isEmpty else { return }
        do {
            let products = try await Product.products(for: productIDs)
            cachedProducts = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            // Products can fail to load offline or before App Store Connect
            // approves the submission. The paywall falls back to demo copy.
        }
    }

    private func handle(transactionUpdate: VerificationResult<Transaction>) async {
        switch transactionUpdate {
        case let .verified(transaction):
            await apply(verifiedTransaction: transaction)
            await transaction.finish()
        case .unverified:
            // Unverified updates are discarded without finishing; Apple will
            // redeliver them if the signature actually becomes trusted later.
            break
        }
    }

    private func apply(verifiedTransaction transaction: Transaction) async {
        guard let tier = tier(forProductID: transaction.productID) else { return }

        // Emit a best-effort audit report to the backend regardless of the
        // final status. Doing this before the local mutation lets renewals
        // and revocations reach the backend even when the local status does
        // not change (for example, when the user is already on the target
        // tier).
        await reportToBackendIfPossible(transaction: transaction, tier: tier)

        if transaction.revocationDate != nil {
            // The user was refunded or their family sharing was revoked.
            // Drop the matching tier if it is currently granted.
            if status == tier {
                status = .free
            }
            return
        }

        if let expiration = transaction.expirationDate, expiration <= .now {
            if status == tier {
                status = .free
            }
            return
        }

        if tier.rank > status.rank {
            status = tier
        }
    }

    private func reportToBackendIfPossible(
        transaction: Transaction,
        tier: SubscriptionStatus
    ) async {
        guard let backendAPI, let identityProvider else { return }

        let installID = await identityProvider.installID()
        let report = SubscriptionReportRequest(
            installID: installID,
            productID: transaction.productID,
            originalTransactionID: String(transaction.originalID),
            transactionID: String(transaction.id),
            purchasedAt: transaction.purchaseDate,
            expiresAt: transaction.expirationDate,
            revokedAt: transaction.revocationDate,
            tier: tier.rawValue,
            rawTransactionJWS: nil
        )

        // Fire-and-forget: this must never block entitlement delivery. The
        // iOS client is still the authoritative entitlement source; the
        // backend report is an audit trail.
        do {
            try await backendAPI.reportSubscription(report)
        } catch {
            // Intentionally swallowed. A durable retry queue lives in a
            // follow-up slice once the grant also becomes authoritative.
        }
    }

    private func reconcileCurrentEntitlements() async {
        var highest: SubscriptionStatus = .free
        for await entitlement in Transaction.currentEntitlements {
            guard case let .verified(transaction) = entitlement,
                  let tier = tier(forProductID: transaction.productID),
                  transaction.revocationDate == nil else {
                continue
            }
            if let expiration = transaction.expirationDate, expiration <= .now {
                continue
            }
            if tier.rank > highest.rank {
                highest = tier
            }
        }
        status = highest
    }

    func purchase(_ target: SubscriptionStatus) async -> SubscriptionStatus {
        guard let productID = productID(for: target) else {
            return status
        }

        let product: Product
        if let cached = cachedProducts[productID] {
            product = cached
        } else {
            do {
                let products = try await Product.products(for: [productID])
                guard let fetched = products.first else { return status }
                cachedProducts[productID] = fetched
                product = fetched
            } catch {
                return status
            }
        }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                switch verification {
                case let .verified(transaction):
                    await apply(verifiedTransaction: transaction)
                    await transaction.finish()
                case .unverified:
                    // Apple instructs: do not grant access and do not finish
                    // unverified transactions. They may become verified later
                    // and arrive via Transaction.updates.
                    break
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            // Purchase failed (network, StoreKit sandbox not ready, etc.).
            // Keep the previous status; the caller can retry.
        }
        return status
    }

    func restore() async -> SubscriptionStatus {
        do {
            try await AppStore.sync()
        } catch {
            // If sync fails the current entitlements snapshot still reflects
            // what Apple has on record, so keep going.
        }
        await reconcileCurrentEntitlements()
        return status
    }

    func availablePlans() async -> [SubscriptionPlan] {
        if cachedProducts.isEmpty {
            await reloadProducts()
        }

        let orderedTiers: [SubscriptionStatus] = [.plus, .pro]
        return orderedTiers.compactMap { tier -> SubscriptionPlan? in
            guard let id = productID(for: tier),
                  let product = cachedProducts[id] else {
                return nil
            }
            return Self.plan(for: tier, product: product)
        }
    }

    private static func plan(for tier: SubscriptionStatus, product: Product) -> SubscriptionPlan {
        let period = Self.periodCopy(for: product)
        let offer = Self.introductoryOffer(for: product)
        let renewal: String
        if let offer {
            renewal = "\(offer) Then \(product.displayPrice) \(period). Auto-renews until cancelled in Settings > Apple ID > Subscriptions. Payment is charged to your Apple ID."
        } else {
            renewal = "\(product.displayPrice) \(period). Auto-renews until cancelled in Settings > Apple ID > Subscriptions. Payment is charged to your Apple ID."
        }
        return SubscriptionPlan(
            tier: tier,
            productID: product.id,
            displayPrice: product.displayPrice,
            displayPeriod: period,
            introductoryOffer: offer,
            renewalDisclosure: renewal,
            isDemo: false
        )
    }

    private static func periodCopy(for product: Product) -> String {
        guard let subscription = product.subscription else {
            return ""
        }
        let unit: String
        switch subscription.subscriptionPeriod.unit {
        case .day: unit = subscription.subscriptionPeriod.value == 1 ? "day" : "\(subscription.subscriptionPeriod.value) days"
        case .week: unit = subscription.subscriptionPeriod.value == 1 ? "week" : "\(subscription.subscriptionPeriod.value) weeks"
        case .month: unit = subscription.subscriptionPeriod.value == 1 ? "month" : "\(subscription.subscriptionPeriod.value) months"
        case .year: unit = subscription.subscriptionPeriod.value == 1 ? "year" : "\(subscription.subscriptionPeriod.value) years"
        @unknown default: unit = "billing period"
        }
        return "per \(unit)"
    }

    private static func introductoryOffer(for product: Product) -> String? {
        guard let intro = product.subscription?.introductoryOffer else { return nil }
        let periodUnit: String
        switch intro.period.unit {
        case .day: periodUnit = intro.period.value == 1 ? "day" : "\(intro.period.value) days"
        case .week: periodUnit = intro.period.value == 1 ? "week" : "\(intro.period.value) weeks"
        case .month: periodUnit = intro.period.value == 1 ? "month" : "\(intro.period.value) months"
        case .year: periodUnit = intro.period.value == 1 ? "year" : "\(intro.period.value) years"
        @unknown default: periodUnit = "introductory period"
        }
        // `Product.SubscriptionOffer.PaymentMode` is a RawRepresentable struct
        // rather than a closed enum, so compare values directly.
        if intro.paymentMode == .freeTrial {
            return "\(periodUnit) free trial."
        }
        if intro.paymentMode == .payAsYouGo {
            return "Intro: \(intro.displayPrice) \(periodUnit)."
        }
        if intro.paymentMode == .payUpFront {
            return "Intro: \(intro.displayPrice) for \(periodUnit)."
        }
        return nil
    }
}
