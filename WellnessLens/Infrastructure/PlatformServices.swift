@preconcurrency import AppIntents
import AVFoundation
import Foundation
import SwiftUI
import UIKit
@preconcurrency import Vision

struct StoredAppState: Codable {
    var hasCompletedOnboarding: Bool
    var userContext: UserContext
    var history: [ScanRecord]
    var checkIns: [CheckInEntry]
    var subscriptionStatus: SubscriptionStatus
    var lastDemoScenarioID: String?

    static let `default` = StoredAppState(
        hasCompletedOnboarding: false,
        userContext: .starter,
        history: [],
        checkIns: [],
        subscriptionStatus: .free,
        lastDemoScenarioID: nil
    )
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
            "Add a barcode, ingredient label, or demo product before analyzing."
        case .unresolvedScan:
            "We could not confidently resolve this product yet. Try a cleaner label photo or a barcode."
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
            return .default
        }
        return (try? decoder.decode(StoredAppState.self, from: data)) ?? .default
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
                    name: "Custom Label Scan",
                    brand: "Manual analysis",
                    productType: input.productTypeHint ?? .food,
                    barcode: nil,
                    headline: "Resolved from your label text. Best used as a directional read.",
                    ingredients: rawText.split(separator: ",").prefix(5).map { Ingredient(name: $0.trimmingCharacters(in: .whitespacesAndNewlines).capitalized) },
                    claims: ["Resolved from OCR / manual label input"],
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
            ("erythritol", .sugarAlcohol)
        ]

        for (keyword, tag) in mappings where rawText.contains(keyword) {
            tags.insert(tag)
        }
        return Array(tags)
    }
}

struct AppServices {
    var configuration: RuntimeConfiguration
    var store: AppDataStore
    var scanService: ScanService
    var subscription: SubscriptionClient
    var labelOCRService: LabelOCRService
    var backendAPI: WellnessBackendAPI?
    var identityProvider: IdentityProviding

    @MainActor
    static func makePreviewServices() -> AppServices {
        let configuration = RuntimeConfiguration.load()
        FirebaseBootstrap.configureIfNeeded(using: configuration)

        let store = LocalAppDataStore()
        let snapshot = store.load()
        let identityProvider: IdentityProviding = {
            #if canImport(FirebaseAuth)
            if configuration.isFirebaseEnabled {
                return FirebaseIdentityProvider()
            }
            #endif
            return LocalInstallIdentityProvider()
        }()

        let appCheckProvider: AppCheckTokenProviding = {
            #if canImport(FirebaseAppCheck)
            if configuration.isFirebaseEnabled {
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

        return AppServices(
            configuration: configuration,
            store: store,
            scanService: scanService,
            subscription: subscription,
            labelOCRService: LabelOCRService(),
            backendAPI: backendAPI,
            identityProvider: identityProvider
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
            "Use a demo scenario, manual barcode, or text label instead of live camera scanning."
        case .photoLibraryDenied:
            "Use manual label text or enable photo access to simulate OCR from a saved label."
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

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.metadataDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onCodeScanned: @MainActor (String) -> Void

        init(onCodeScanned: @escaping @MainActor (String) -> Void) {
            self.onCodeScanned = onCodeScanned
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
    }
}

final class ScannerViewController: UIViewController {
    var metadataDelegate: AVCaptureMetadataOutputObjectsDelegate?

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
                    granted ? self?.setupSession() : self?.showMessage("Camera access is needed for live barcode scanning.")
                }
            }
        default:
            showMessage("Camera access is unavailable here. Use manual barcode entry or a label photo.")
        }
    }

    private func setupSession() {
        guard let captureDevice = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            showMessage("Live camera scanning is unavailable on this device.")
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
}
