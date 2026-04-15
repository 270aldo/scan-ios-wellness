import AVFoundation
import Photos
import PhotosUI
import SwiftUI

struct ScanView: View {
    @Environment(AppModel.self) private var model

    @State private var manualBarcode = ""
    @State private var manualLabelText = ""
    @State private var selectedProductType: ProductType = .food
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showBarcodeScanner = false
    @State private var showPhotoPicker = false
    @State private var scannerPermissionState: ScannerPermissionState = .unknown

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                feedbackSection
                liveScanSection
                manualBarcodeSection
                labelSection
                demoScenarioPacksSection
            }
            .padding(20)
        }
        .navigationTitle("Scan")
        .background(Color(red: 0.98, green: 0.97, blue: 0.99))
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerView { barcode in
                showBarcodeScanner = false
                manualBarcode = barcode
                Task {
                    await model.analyzeBarcode(barcode, source: .liveBarcode)
                }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else { return }
            do {
                guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self) else {
                    model.presentScanFeedback(.ocrEmpty)
                    return
                }
                let parsedText = try await model.services.labelOCRService.recognizeText(from: data)
                let trimmed = parsedText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    model.presentScanFeedback(.ocrEmpty)
                    return
                }
                manualLabelText = trimmed
                await model.analyzeLabelText(trimmed, source: .labelPhoto, typeHint: selectedProductType)
            } catch {
                model.presentScanFeedback(.ocrFailed)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Demo the full scan loop fast")
                .font(.title2.bold())
            Text("Choose a one-tap scenario, try barcode input, or simulate OCR with label text. The score stays deterministic and the guidance stays non-clinical.")
                .foregroundStyle(.secondary)

            if let lastDemoScenario = model.lastDemoScenario {
                Label("Last demo: \(lastDemoScenario.title)", systemImage: "sparkles.rectangle.stack.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isAnalyzing {
                scanStatusCard(
                    symbol: "sparkles",
                    title: "Analyzing",
                    message: "We are running a deterministic read, then building the directional summary and swap suggestions."
                )
            }

            if scannerPermissionState != .unknown && scannerPermissionState != .ready {
                scanStatusCard(
                    symbol: scannerPermissionState.symbol,
                    title: scannerPermissionState.title,
                    message: scannerPermissionState.message
                )
            }

            if let scanFeedback = model.scanFeedback {
                scanStatusCard(
                    symbol: "exclamationmark.circle.fill",
                    title: scanFeedback.title,
                    message: scanFeedback.message,
                    dismissAction: model.clearScanFeedback
                )
            }
        }
    }

    private var liveScanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live barcode scan")
                .font(.headline)
            Text("Use this on-device when camera access is available. For simulator demos, the one-tap scenarios below are the primary path.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                requestLiveScan()
            } label: {
                Label("Open camera scanner", systemImage: "camera.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var manualBarcodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual barcode")
                .font(.headline)
            TextField("Enter barcode", text: $manualBarcode)
                .textInputAutocapitalization(.never)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            Button("Analyze barcode") {
                Task {
                    await model.analyzeBarcode(manualBarcode)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var labelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Label fallback")
                .font(.headline)

            Picker("Product type", selection: $selectedProductType) {
                ForEach(ProductType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.menu)

            TextEditor(text: $manualLabelText)
                .frame(minHeight: 120)
                .padding(10)
                .background(Color(red: 0.97, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 12) {
                Button("Analyze text") {
                    Task {
                        await model.analyzeLabelText(manualLabelText, typeHint: selectedProductType)
                    }
                }
                .buttonStyle(.bordered)

                Button {
                    requestPhotoSelection()
                } label: {
                    Label("Use a label photo", systemImage: "photo")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var demoScenarioPacksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("1-tap demo packs")
                .font(.headline)

            ForEach(model.demoScenarioPacks) { pack in
                VStack(alignment: .leading, spacing: 12) {
                    Label(pack.title, systemImage: pack.icon)
                        .font(.subheadline.weight(.bold))
                    Text(pack.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(pack.scenarios) { scenario in
                        Button {
                            Task {
                                await model.runDemoScenario(scenario)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(scenario.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.primary)
                                        Text(scenario.subtitle)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(scenario.productType.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                Text(scenario.expectedHighlight)
                                    .font(.caption)
                                    .foregroundStyle(.primary)

                                Label(scenario.expectedLensBias.title, systemImage: scenario.expectedLensBias.icon)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 0.98, green: 0.97, blue: 0.99), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
        }
    }

    private func scanStatusCard(
        symbol: String,
        title: String,
        message: String,
        dismissAction: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let dismissAction {
                Button("Dismiss") {
                    dismissAction()
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func requestLiveScan() {
        model.clearScanFeedback()

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            scannerPermissionState = .ready
            showBarcodeScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        scannerPermissionState = .ready
                        showBarcodeScanner = true
                    } else {
                        scannerPermissionState = .cameraDenied
                    }
                }
            }
        case .denied, .restricted:
            scannerPermissionState = .cameraDenied
        @unknown default:
            scannerPermissionState = .unavailable("Live camera scanning is unavailable in this environment.")
        }
    }

    private func requestPhotoSelection() {
        model.clearScanFeedback()

        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            scannerPermissionState = .ready
            showPhotoPicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                Task { @MainActor in
                    switch status {
                    case .authorized, .limited:
                        scannerPermissionState = .ready
                        showPhotoPicker = true
                    case .denied, .restricted:
                        scannerPermissionState = .photoLibraryDenied
                    case .notDetermined:
                        scannerPermissionState = .unknown
                    @unknown default:
                        scannerPermissionState = .unavailable("Photo selection is unavailable in this environment.")
                    }
                }
            }
        case .denied, .restricted:
            scannerPermissionState = .photoLibraryDenied
        @unknown default:
            scannerPermissionState = .unavailable("Photo selection is unavailable in this environment.")
        }
    }
}

struct AnalysisView: View {
    let analysis: ScanAnalysis
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    confidenceCard
                    lensGrid
                    reasonsSection
                    warningsSection
                    alternativesSection
                    disclaimerSection
                }
                .padding(20)
            }
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(analysis.resolvedProduct.name)
                .font(.title2.bold())
            Text(analysis.overallSummary)
                .foregroundStyle(.secondary)
            HStack {
                Label(analysis.productType.title, systemImage: "tag")
                Spacer()
                Text("Source: \(analysis.source.title)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var confidenceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Confidence: \(analysis.confidence.title)", systemImage: "scope")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text("Directional only")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(confidenceExplanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("This is consumer wellness guidance, not diagnosis or treatment advice.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var lensGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(analysis.lensScores) { score in
                VStack(alignment: .leading, spacing: 8) {
                    Label(score.lens.title, systemImage: score.lens.icon)
                        .font(.footnote.weight(.semibold))
                    Text("\(score.score)")
                        .font(.title.bold())
                    Text(score.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                .padding(16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var reasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why this read landed here")
                .font(.headline)
            ForEach(analysis.topReasons) { reason in
                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.title)
                        .font(.subheadline.bold())
                    Text(reason.detail)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(reason.impact == .positive ? Color.green.opacity(0.08) : Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var warningsSection: some View {
        if !analysis.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Caution")
                    .font(.headline)
                ForEach(analysis.warnings, id: \.self) { warning in
                    Text(warning)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var alternativesSection: some View {
        if !analysis.alternatives.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Better swaps")
                    .font(.headline)
                ForEach(analysis.alternatives) { suggestion in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(suggestion.productName)
                            .font(.subheadline.bold())
                        Text(suggestion.whyBetter)
                            .foregroundStyle(.secondary)
                        Text(suggestion.improvedLenses.map(\.title).joined(separator: " · "))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var disclaimerSection: some View {
        Text(analysis.disclaimer)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }

    private var confidenceExplanation: String {
        switch analysis.confidence {
        case .high:
            "This product was matched with strong confidence, so the summary should be a stable directional read."
        case .medium:
            "This scan matched with partial confidence, so use the score as directional context rather than a final verdict."
        case .low:
            "This scan was inferred from limited input, so double-check the label before acting on the guidance."
        }
    }
}
