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
    @State private var sampleReadsExpanded = false

    var body: some View {
        WLScreen {
            ScanHeaderCard(lastDemoScenario: model.lastDemoScenario)

            ScanPrimaryActionCard(
                openScanner: requestLiveScan,
                openPhotoSelection: requestPhotoSelection
            )

            ScanOtherWaysCard(
                manualBarcode: $manualBarcode,
                manualLabelText: $manualLabelText,
                selectedProductType: $selectedProductType,
                analyzeBarcode: {
                    Task {
                        await model.analyzeBarcode(manualBarcode)
                    }
                },
                analyzeLabelText: {
                    Task {
                        await model.analyzeLabelText(manualLabelText, typeHint: selectedProductType)
                    }
                },
                openPhotoSelection: requestPhotoSelection
            )

            feedbackSection

            ScanSampleReadsSection(
                packs: model.demoScenarioPacks,
                isExpanded: $sampleReadsExpanded,
                runScenario: runScenario
            )
        }
        .navigationTitle(WLProductCopy.Scan.title)
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

    @ViewBuilder
    private var feedbackSection: some View {
        if model.isAnalyzing || (scannerPermissionState != .unknown && scannerPermissionState != .ready) || model.scanFeedback != nil {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                if model.isAnalyzing {
                    ScanStatusCard(
                        symbol: "sparkles",
                        title: "Building your read",
                        message: "Shaping the lens story, checking confidence, and looking for softer swaps."
                    )
                }

                if scannerPermissionState != .unknown && scannerPermissionState != .ready {
                    ScanStatusCard(
                        symbol: scannerPermissionState.symbol,
                        title: scannerPermissionState.title,
                        message: scannerPermissionState.message
                    )
                }

                if let scanFeedback = model.scanFeedback {
                    ScanStatusCard(
                        symbol: "exclamationmark.circle",
                        title: scanFeedback.title,
                        message: scanFeedback.message,
                        dismissAction: model.clearScanFeedback
                    )
                }
            }
        }
    }

    private func runScenario(_ scenario: DemoScenario) {
        Task {
            await model.runDemoScenario(scenario)
        }
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

private struct ScanHeaderCard: View {
    let lastDemoScenario: DemoScenario?

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLStatusBadge(title: "Scan", systemImage: "viewfinder", tone: .accent)

                Text(WLProductCopy.Scan.heroTitle)
                    .font(WLTypography.title)
                    .foregroundStyle(WLPalette.ink)

                Text(WLProductCopy.Scan.heroSubtitle)
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)

                if let lastDemoScenario {
                    Text("Last sample read: \(lastDemoScenario.title)")
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(WLPalette.rose)
                }
            }
        }
    }
}

private struct ScanPrimaryActionCard: View {
    let openScanner: () -> Void
    let openPhotoSelection: () -> Void

    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: WLProductCopy.Scan.primaryTitle,
                    subtitle: WLProductCopy.Scan.primarySubtitle,
                    systemImage: "camera.viewfinder"
                )

                VStack(spacing: WLSpacing.s) {
                    WLPrimaryButton(title: "Open camera scanner", systemImage: "camera.viewfinder") {
                        openScanner()
                    }

                    WLSecondaryButton(title: "Use a label photo", systemImage: "photo") {
                        openPhotoSelection()
                    }
                }
            }
        }
    }
}

private struct ScanOtherWaysCard: View {
    @Binding var manualBarcode: String
    @Binding var manualLabelText: String
    @Binding var selectedProductType: ProductType
    let analyzeBarcode: () -> Void
    let analyzeLabelText: () -> Void
    let openPhotoSelection: () -> Void

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.l) {
                WLSectionHeader(
                    title: WLProductCopy.Scan.otherWaysTitle,
                    subtitle: WLProductCopy.Scan.otherWaysSubtitle,
                    systemImage: "ellipsis.circle"
                )

                VStack(alignment: .leading, spacing: WLSpacing.m) {
                    Text("Barcode")
                        .font(WLTypography.bodyEmphasis)
                        .foregroundStyle(WLPalette.ink)

                    TextField("Enter barcode", text: $manualBarcode)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    WLSecondaryButton(title: "Analyze barcode", systemImage: "barcode") {
                        analyzeBarcode()
                    }
                }

                Divider()
                    .overlay(WLPalette.strokeStrong)

                VStack(alignment: .leading, spacing: WLSpacing.m) {
                    Text("Label text")
                        .font(WLTypography.bodyEmphasis)
                        .foregroundStyle(WLPalette.ink)

                    Picker("Product type", selection: $selectedProductType) {
                        ForEach(ProductType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $manualLabelText)
                            .frame(minHeight: 130)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                    .fill(WLPalette.surfaceMuted)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                    .stroke(WLPalette.stroke)
                            )

                        if manualLabelText.isEmpty {
                            Text("Ingredients, claims, or any key label text")
                                .font(WLTypography.body)
                                .foregroundStyle(WLPalette.inkSoft)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 24)
                                .allowsHitTesting(false)
                        }
                    }

                    HStack(spacing: WLSpacing.s) {
                        WLSecondaryButton(title: "Analyze text", systemImage: "text.page") {
                            analyzeLabelText()
                        }

                        WLSecondaryButton(title: "Use a label photo", systemImage: "photo") {
                            openPhotoSelection()
                        }
                    }
                }
            }
        }
    }
}

private struct ScanStatusCard: View {
    let symbol: String
    let title: String
    let message: String
    var dismissAction: (() -> Void)? = nil

    var body: some View {
        WLCompactCard {
            HStack(alignment: .top, spacing: WLSpacing.s) {
                WLIcon(systemName: symbol, color: WLPalette.rose, size: 15)

                VStack(alignment: .leading, spacing: WLSpacing.xs) {
                    Text(title)
                        .font(WLTypography.bodyEmphasis)
                        .foregroundStyle(WLPalette.ink)

                    Text(message)
                        .font(WLTypography.caption)
                        .foregroundStyle(WLPalette.inkSoft)
                }

                Spacer()

                if let dismissAction {
                    Button("Dismiss", action: dismissAction)
                        .font(WLTypography.captionStrong)
                }
            }
        }
    }
}

private struct ScanSampleReadsSection: View {
    let packs: [DemoScenarioPack]
    @Binding var isExpanded: Bool
    let runScenario: (DemoScenario) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: WLSpacing.s) {
                    WLSectionHeader(
                        title: WLProductCopy.Scan.sampleReadsTitle,
                        subtitle: WLProductCopy.Scan.sampleReadsSubtitle,
                        systemImage: "sparkles"
                    )

                    Spacer()

                    WLIcon(systemName: isExpanded ? "chevron.up" : "chevron.down", color: WLPalette.inkSoft, size: 14)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(packs) { pack in
                    ScanDemoPackCard(pack: pack, runScenario: runScenario)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

private struct ScanDemoPackCard: View {
    let pack: DemoScenarioPack
    let runScenario: (DemoScenario) -> Void

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                Label(pack.title, systemImage: pack.icon)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text(pack.subtitle)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)

                ForEach(pack.scenarios) { scenario in
                    Button(action: { runScenario(scenario) }) {
                        VStack(alignment: .leading, spacing: WLSpacing.s) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: WLSpacing.xs) {
                                    Text(scenario.title)
                                        .font(WLTypography.bodyEmphasis)
                                        .foregroundStyle(WLPalette.ink)
                                        .multilineTextAlignment(.leading)

                                    Text(scenario.subtitle)
                                        .font(WLTypography.caption)
                                        .foregroundStyle(WLPalette.inkSoft)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: WLSpacing.s)

                                WLPill(title: scenario.productType.title, tone: .soft)
                            }

                            WLStatusBadge(
                                title: scenario.expectedLensBias.title,
                                systemImage: scenario.expectedLensBias.icon,
                                tone: .accent
                            )
                        }
                        .padding(WLSpacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.98), WLPalette.canvasWarm],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                .stroke(WLPalette.stroke)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview("Scan") {
    NavigationStack {
        ScanView()
            .environment(AppModel())
    }
}
