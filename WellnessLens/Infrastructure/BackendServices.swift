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

struct SaveFavoriteItemRequest: Codable {
    let favorite: FavoriteItem
    let installID: String
}

protocol IdentityProviding: Sendable {
    func prepare() async
    func installID() async -> String
    func authorizationHeader() async -> String?
}

protocol AppCheckTokenProviding: Sendable {
    func token() async -> String?
}

protocol WellnessBackendAPI: Sendable {
    func analyzeProduct(input: ScanInput, userContext: UserContext) async throws -> ScanAnalysis
    func analyzeStructuredScan(input: ScanInput, profile: UserProfile, recentScans: [ScanEvent], recentCheckIns: [CheckInEvent]) async throws -> AnalysisEnvelope
    func resolveScan(input: ScanInput) async throws -> ResolveScanResponse
    func compareProducts(left: ScanAnalysis, right: ScanAnalysis) async throws -> ProductComparison
    func saveCheckIn(_ checkIn: CheckInEntry, userContext: UserContext) async throws
    func saveCheckInEvent(_ event: CheckInEvent) async throws
    func completeOnboarding(profile: UserProfile, activeGoals: [ActiveGoal], firstWeekPlan: FirstWeekPlan?) async throws
    func getWeeklyInsights(userContext: UserContext) async throws -> [WeeklyInsight]
    func fetchDailyHome(profile: UserProfile, activeGoals: [ActiveGoal]) async throws -> DailyHomeResponse
    func fetchDailyBrief(profile: UserProfile, activeGoals: [ActiveGoal]) async throws -> DailyBrief
    func fetchHistoryEvents() async throws -> HistoryEventsResponse
    func listAlternatives(for analysis: ScanAnalysis, userContext: UserContext) async throws -> [AlternativeSuggestion]
    func saveScanDecision(_ decision: ScanDecision) async throws
    func saveFavoriteItem(_ favorite: FavoriteItem) async throws
    func upsertMemoryItems(_ memoryItems: [MemoryItem]) async throws
}

enum BackendClientError: LocalizedError {
    case missingBaseURL
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            "A backend base URL is required for cloud mode."
        case .invalidResponse:
            "The backend returned an unexpected payload."
        case let .httpError(code):
            "The backend request failed with status code \(code)."
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

    func analyzeProduct(input: ScanInput, userContext: UserContext) async throws -> ScanAnalysis {
        let installID = await identityProvider.installID()
        let request = AnalyzeProductRequest(input: input, userContext: userContext, installID: installID)
        let response: AnalyzeProductResponse = try await send(path: "analyzeProduct", method: "POST", body: request)
        return response.analysis
    }

    func analyzeStructuredScan(
        input: ScanInput,
        profile: UserProfile,
        recentScans: [ScanEvent],
        recentCheckIns: [CheckInEvent]
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

    private func send<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        method: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        if let authHeader = await identityProvider.authorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }

        request.setValue(await identityProvider.installID(), forHTTPHeaderField: "X-Wellness-Install-ID")

        if let appCheckToken = await appCheckProvider.token() {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendClientError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw BackendClientError.httpError(httpResponse.statusCode)
        }
        return try decoder.decode(ResponseBody.self, from: data)
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

    func analyze(input: ScanInput, userContext: UserContext) async throws -> ScanAnalysis {
        do {
            return try await backendAPI.analyzeProduct(input: input, userContext: userContext)
        } catch {
            let fallback = DemoScanService(catalog: fallbackCatalog)
            return try await fallback.analyze(input: input, userContext: userContext)
        }
    }
}

@MainActor
final class StoreKitSubscriptionController: SubscriptionClient {
    private let configuration: RuntimeConfiguration
    private(set) var status: SubscriptionStatus = .free

    init(configuration: RuntimeConfiguration) {
        self.configuration = configuration
    }

    func purchase(_ target: SubscriptionStatus) async -> SubscriptionStatus {
        guard let productID = productID(for: target) else {
            return status
        }

        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first else { return status }
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                switch verification {
                case .verified:
                    status = target
                case .unverified:
                    break
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
            return status
        } catch {
            return status
        }
    }

    func restore() async -> SubscriptionStatus {
        do {
            try await AppStore.sync()
        } catch {
            return status
        }

        var restored: SubscriptionStatus = .free

        for await entitlement in Transaction.currentEntitlements {
            guard case let .verified(transaction) = entitlement else { continue }
            if transaction.productID == configuration.proProductID {
                restored = .pro
                break
            }
            if transaction.productID == configuration.plusProductID {
                restored = .plus
            }
        }

        status = restored
        return status
    }

    private func productID(for status: SubscriptionStatus) -> String? {
        switch status {
        case .free:
            nil
        case .plus:
            configuration.plusProductID
        case .pro:
            configuration.proProductID
        }
    }
}
