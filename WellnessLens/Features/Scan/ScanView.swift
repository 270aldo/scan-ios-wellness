import AVFoundation
import Photos
import PhotosUI
import SwiftUI

private enum ScanCaptureIntent {
    case labelPhoto
    case mealSnapshot
    case menuScanner
}

private enum ScanManualField: Hashable {
    case barcode
    case labelText
}

struct ScanView: View {
    @Environment(AppModel.self) private var model

    @State private var manualBarcode = ""
    @State private var manualLabelText = ""
    @State private var selectedProductType: ProductType = .food
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showBarcodeScanner = false
    @State private var showPhotoPicker = false
    @State private var scannerPermissionState: ScannerPermissionState = .unknown
    @State private var fallbackInputsExpanded = false
    @State private var sampleReadsExpanded = false
    @State private var captureIntent: ScanCaptureIntent = .labelPhoto
    @FocusState private var focusedManualField: ScanManualField?

    var body: some View {
        WLScreen {
            feedbackSection

            ScanHeaderCard()

            ScanPrimaryActionCard(
                openScanner: requestLiveScan,
                openPhotoSelection: {
                    requestPhotoSelection(for: .labelPhoto)
                }
            )

            if model.featureFlags.mealSnapshot || model.featureFlags.menuScanner {
                ScanModeActionsCard(
                    openMealSnapshot: {
                        requestPhotoSelection(for: .mealSnapshot)
                    },
                    openMenuScanner: {
                        requestPhotoSelection(for: .menuScanner)
                    },
                    showMealSnapshot: model.featureFlags.mealSnapshot,
                    showMenuScanner: model.featureFlags.menuScanner,
                    menuScannerUnlocked: model.hasAccess(to: .menuScanner)
                )
            }

            ScanOtherWaysCard(
                manualBarcode: $manualBarcode,
                manualLabelText: $manualLabelText,
                selectedProductType: $selectedProductType,
                isExpanded: fallbackInputsExpanded,
                focusedField: $focusedManualField,
                toggleExpanded: {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                        fallbackInputsExpanded.toggle()
                    }
                },
                analyzeBarcode: analyzeManualBarcode,
                analyzeLabelText: analyzeManualLabelText
            )

            if model.scanEvents.isEmpty || sampleReadsExpanded {
                ScanSampleReadsSection(
                    packs: model.demoScenarioPacks,
                    isExpanded: true,
                    canCollapse: !model.scanEvents.isEmpty,
                    toggleExpanded: model.scanEvents.isEmpty ? nil : {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                            sampleReadsExpanded.toggle()
                        }
                    },
                    runScenario: runScenario
                )
            } else {
                ScanSampleReadsTeaserCard {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                        sampleReadsExpanded = true
                    }
                }
            }
        }
        .navigationTitle(WLProductCopy.Scan.title)
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerView(
                onCodeScanned: { barcode in
                    showBarcodeScanner = false
                    manualBarcode = barcode
                    Task {
                        await model.analyzeBarcode(barcode, source: .liveBarcode)
                    }
                },
                onUnavailable: { message in
                    presentLiveScannerUnavailable(message)
                }
            )
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else { return }
            defer { self.selectedPhotoItem = nil }
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
                switch captureIntent {
                case .labelPhoto:
                    await model.analyzeLabelText(trimmed, source: .labelPhoto, typeHint: selectedProductType)
                case .mealSnapshot:
                    await model.analyzeMealSnapshot(trimmed)
                case .menuScanner:
                    await model.analyzeMenuPhoto(trimmed)
                }
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
                        message: scannerPermissionState.message,
                        actions: scannerRecoveryActions
                    )
                }

                if let scanFeedback = model.scanFeedback {
                    ScanStatusCard(
                        symbol: "exclamationmark.circle",
                        title: scanFeedback.title,
                        message: scanFeedback.message,
                        actions: scanFeedbackActions,
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

    private func analyzeManualBarcode() {
        Task {
            await model.analyzeBarcode(manualBarcode)
        }
    }

    private func analyzeManualLabelText() {
        Task {
            await model.analyzeLabelText(manualLabelText, typeHint: selectedProductType)
        }
    }

    private func requestLiveScan() {
        model.clearScanFeedback()
        scannerPermissionState = .unknown

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentLiveScannerIfAvailable()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        presentLiveScannerIfAvailable()
                    } else {
                        scannerPermissionState = .cameraDenied
                        revealFallbackInputs(focus: .barcode)
                    }
                }
            }
        case .denied, .restricted:
            scannerPermissionState = .cameraDenied
            revealFallbackInputs(focus: .barcode)
        @unknown default:
            presentLiveScannerUnavailable("Live camera scanning is unavailable in this environment.")
        }
    }

    private func requestPhotoSelection(for intent: ScanCaptureIntent) {
        model.clearScanFeedback()
        scannerPermissionState = .unknown
        selectedPhotoItem = nil
        showPhotoPicker = false
        captureIntent = intent

        switch intent {
        case .labelPhoto:
            break
        case .mealSnapshot:
            selectedProductType = .food
        case .menuScanner:
            selectedProductType = .food
            guard model.requireAccess(
                to: .menuScanner,
                surface: .menuScanner,
                previewLines: menuScannerPreview
            ) else {
                scannerPermissionState = .unknown
                return
            }
        }

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
                        revealFallbackInputs(focus: .labelText)
                    case .notDetermined:
                        scannerPermissionState = .unknown
                    @unknown default:
                        scannerPermissionState = .unavailable("Photo selection is unavailable in this environment.")
                    }
                }
            }
        case .denied, .restricted:
            scannerPermissionState = .photoLibraryDenied
            revealFallbackInputs(focus: .labelText)
        @unknown default:
            scannerPermissionState = .unavailable("Photo selection is unavailable in this environment.")
        }
    }

    private func presentLiveScannerIfAvailable() {
        guard AVCaptureDevice.default(for: .video) != nil else {
            presentLiveScannerUnavailable("Live camera scanning is unavailable here. Use a label photo or enter a barcode manually.")
            return
        }

        scannerPermissionState = .ready
        showBarcodeScanner = true
    }

    private func presentLiveScannerUnavailable(_ message: String) {
        showBarcodeScanner = false
        scannerPermissionState = .unavailable(message)
        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            fallbackInputsExpanded = true
        }
        focusedManualField = nil
    }

    private func revealFallbackInputs(focus field: ScanManualField) {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            fallbackInputsExpanded = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            focusedManualField = field
        }
    }

    private var scannerRecoveryActions: [ScanStatusAction] {
        switch scannerPermissionState {
        case .cameraDenied, .unavailable:
            return [
                ScanStatusAction(title: "Use a label photo", systemImage: "photo") {
                    requestPhotoSelection(for: .labelPhoto)
                },
                ScanStatusAction(
                    title: manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter barcode manually" : "Analyze barcode",
                    systemImage: "barcode"
                ) {
                    if manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        revealFallbackInputs(focus: .barcode)
                    } else {
                        analyzeManualBarcode()
                    }
                }
            ]
        case .photoLibraryDenied:
            return [
                ScanStatusAction(
                    title: manualLabelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Type label text" : "Analyze text",
                    systemImage: "text.page"
                ) {
                    if manualLabelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        revealFallbackInputs(focus: .labelText)
                    } else {
                        analyzeManualLabelText()
                    }
                }
            ]
        case .unknown, .ready:
            return []
        }
    }

    private var scanFeedbackActions: [ScanStatusAction] {
        switch model.scanFeedback {
        case .emptyInput?:
            return [
                ScanStatusAction(title: "Use a label photo", systemImage: "photo") {
                    requestPhotoSelection(for: .labelPhoto)
                },
                ScanStatusAction(title: "Enter barcode manually", systemImage: "barcode") {
                    revealFallbackInputs(focus: .barcode)
                }
            ]
        case .ocrEmpty?, .ocrFailed?:
            return [
                ScanStatusAction(title: "Try another photo", systemImage: "photo") {
                    requestPhotoSelection(for: .labelPhoto)
                },
                ScanStatusAction(title: "Type label text", systemImage: "text.page") {
                    revealFallbackInputs(focus: .labelText)
                }
            ]
        case .unresolved?:
            return [
                ScanStatusAction(title: "Use a label photo", systemImage: "photo") {
                    requestPhotoSelection(for: .labelPhoto)
                },
                ScanStatusAction(title: "Show manual fallback", systemImage: "ellipsis.circle") {
                    revealFallbackInputs(focus: .labelText)
                }
            ]
        case .custom?, nil:
            return []
        }
    }

    private var menuScannerPreview: [String] {
        [
            "Restaurant decisions use the same wellness lens as scans at home.",
            "You only hit the paywall when you try to run the premium scan."
        ]
    }
}

private struct ScanHeaderCard: View {
    var body: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLStatusBadge(title: "Scan", systemImage: "viewfinder", tone: .accent)

                Text("Choose the cleanest input for this decision.")
                    .font(WLTypography.title)
                    .foregroundStyle(WLPalette.ink)

                Text("Product label, meal snapshot, or menu read. WellnessLens keeps the recommendation explainable even when the capture is thin.")
                    .font(WLTypography.body)
                    .foregroundStyle(WLPalette.inkSoft)
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
                    subtitle: "Use live barcode first when it works. A label photo is the fastest fallback.",
                    systemImage: "camera.viewfinder"
                )

                WLActionGroup(alignment: .trailing) {
                    WLPrimaryButton(title: "Open camera scanner", systemImage: "camera.viewfinder") {
                        openScanner()
                    }

                    WLUtilityButton(title: "Use a label photo", systemImage: "photo") {
                        openPhotoSelection()
                    }
                }
            }
        }
    }
}

private struct ScanModeActionsCard: View {
    let openMealSnapshot: () -> Void
    let openMenuScanner: () -> Void
    let showMealSnapshot: Bool
    let showMenuScanner: Bool
    let menuScannerUnlocked: Bool

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "More scan modes",
                    subtitle: "Choose the mode that matches the decision instead of forcing everything into a product label flow.",
                    systemImage: "square.grid.2x2"
                )

                if showMealSnapshot {
                    ScanModeCard(
                        title: "Meal Snapshot",
                        subtitle: "Use a meal photo when the decision is the plate, not the package.",
                        systemImage: "fork.knife.circle",
                        badgeTitle: nil,
                        badgeTone: .soft,
                        action: openMealSnapshot
                    )
                }

                if showMenuScanner {
                    ScanModeCard(
                        title: "Menu Scanner",
                        subtitle: "Read a restaurant choice before you order, with the same wellness lens you use at home.",
                        systemImage: "menucard",
                        badgeTitle: menuScannerUnlocked ? "Unlocked" : "Plus",
                        badgeTone: menuScannerUnlocked ? .soft : .accent,
                        action: openMenuScanner
                    )
                }
            }
        }
    }
}

private struct ScanModeCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let badgeTitle: String?
    let badgeTone: WLPill.Tone
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: WLSpacing.s) {
                HStack(alignment: .top, spacing: WLSpacing.s) {
                    Label(title, systemImage: systemImage)
                        .font(WLTypography.bodyEmphasis)
                        .foregroundStyle(WLPalette.ink)

                    Spacer(minLength: WLSpacing.s)

                    if let badgeTitle {
                        WLPill(title: badgeTitle, tone: badgeTone)
                    }
                }

                Text(subtitle)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)

                Text("Use a photo")
                    .font(WLTypography.captionStrong)
                    .foregroundStyle(WLPalette.rose)
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

private struct ScanOtherWaysCard: View {
    @Binding var manualBarcode: String
    @Binding var manualLabelText: String
    @Binding var selectedProductType: ProductType
    let isExpanded: Bool
    let focusedField: FocusState<ScanManualField?>.Binding
    let toggleExpanded: () -> Void
    let analyzeBarcode: () -> Void
    let analyzeLabelText: () -> Void

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.l) {
                Button(action: toggleExpanded) {
                    HStack(spacing: WLSpacing.s) {
                        WLSectionHeader(
                            title: WLProductCopy.Scan.otherWaysTitle,
                            subtitle: "Fallbacks stay deterministic and keep the decision moving without duplicating the main CTA.",
                            systemImage: "ellipsis.circle"
                        )

                        Spacer()

                        WLIcon(systemName: isExpanded ? "chevron.up" : "chevron.down", color: WLPalette.inkSoft, size: 14)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        Text("Barcode")
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        TextField("Enter barcode", text: $manualBarcode)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .focused(focusedField, equals: .barcode)

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
                                .focused(focusedField, equals: .labelText)

                            if manualLabelText.isEmpty {
                                Text("Ingredients, claims, or any key label text")
                                    .font(WLTypography.body)
                                    .foregroundStyle(WLPalette.inkSoft)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 24)
                                    .allowsHitTesting(false)
                            }
                        }

                        WLSecondaryButton(title: "Analyze text", systemImage: "text.page") {
                            analyzeLabelText()
                        }
                    }
                }
            }
        }
    }
}

private struct ScanStatusAction {
    let title: String
    let systemImage: String
    let action: () -> Void
}

private struct ScanStatusCard: View {
    let symbol: String
    let title: String
    let message: String
    var actions: [ScanStatusAction] = []
    var dismissAction: (() -> Void)? = nil

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
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

                if !actions.isEmpty {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                            WLUtilityButton(title: action.title, systemImage: action.systemImage) {
                                action.action()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ScanSampleReadsSection: View {
    let packs: [DemoScenarioPack]
    let isExpanded: Bool
    let canCollapse: Bool
    let toggleExpanded: (() -> Void)?
    let runScenario: (DemoScenario) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            if canCollapse, let toggleExpanded {
                Button(action: toggleExpanded) {
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
            } else {
                WLSectionHeader(
                    title: WLProductCopy.Scan.sampleReadsTitle,
                    subtitle: WLProductCopy.Scan.sampleReadsSubtitle,
                    systemImage: "sparkles"
                )
            }

            if isExpanded {
                ForEach(packs) { pack in
                    ScanDemoPackCard(pack: pack, runScenario: runScenario)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

private struct ScanSampleReadsTeaserCard: View {
    let expand: () -> Void

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: WLProductCopy.Scan.sampleReadsTitle,
                    subtitle: "You already have real scan signal. Open this only if you want a demo reference.",
                    systemImage: "sparkles"
                )

                WLUtilityButton(title: "Show sample reads", systemImage: "sparkles") {
                    expand()
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
