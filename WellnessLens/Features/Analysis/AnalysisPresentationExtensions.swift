import SwiftUI

// Presentation-only extensions on LILA + resolution semantics types used by
// `AnalysisView` and its subviews. These used to live at the bottom of
// `AnalysisView.swift`; extracting them here keeps the view file focused on
// layout and keeps the surface-level copy discoverable in one place.
//
// The extensions are `internal` (the default) because every caller still
// lives inside this module. External modules don't need them.

extension LILADomain.Confidence {
    var surfaceTitle: String {
        switch self {
        case .high:
            "High confidence"
        case .medium:
            "Medium confidence"
        case .low:
            "Low confidence"
        case .insufficient:
            "Insufficient confidence"
        }
    }
}

extension LILADomain.ScanSource {
    var surfaceTitle: String {
        switch self {
        case .liveBarcode:
            "Live barcode"
        case .manualBarcode:
            "Manual barcode"
        case .labelPhoto:
            "Label photo"
        case .mealPhoto:
            "Meal snapshot"
        case .menuPhoto:
            "Menu scanner"
        case .manualLabel:
            "Manual label"
        case .voiceLog:
            "Voice log"
        }
    }

    func readStateTitle(for resolvedProduct: LILADomain.ResolvedProduct) -> String {
        guard resolvedProduct.hasResolutionSemantic(.directional) else {
            return "Resolved product"
        }
        switch self {
        case .labelPhoto, .manualLabel:
            return "Directional label read"
        case .mealPhoto:
            return "Directional meal read"
        case .menuPhoto:
            return "Directional menu read"
        case .liveBarcode, .manualBarcode:
            return "Unresolved barcode read"
        case .voiceLog:
            return "Directional voice read"
        }
    }

    func directionalGuidanceNote(for resolvedProduct: LILADomain.ResolvedProduct) -> String? {
        guard resolvedProduct.hasResolutionSemantic(.directional) else {
            return nil
        }
        switch self {
        case .labelPhoto, .manualLabel:
            return "This is a directional label read, not an exact packaged-food match yet. Rescan with a barcode or a cleaner label when you can."
        case .mealPhoto:
            return "This meal read stays directional for now. Use it for guidance, not exact product identity."
        case .menuPhoto:
            return "This menu read stays directional for now. Treat it as a pre-order steer, not a resolved product."
        case .liveBarcode, .manualBarcode:
            return "The barcode did not resolve to a stable packaged-food match yet. Try another scan or add clearer label details."
        case .voiceLog:
            return "This voice-led read is directional and should be confirmed with a stronger packaged-food input."
        }
    }
}

extension LILADomain.ResolutionSource {
    var surfaceTitle: String {
        switch self {
        case .openFoodFacts:
            "Open Food Facts"
        case .usdaFoodDataCentral:
            "USDA nutrients"
        case .nihDSLD:
            "NIH DSLD"
        case .cosing:
            "COSING"
        case .localCatalog:
            "Local catalog"
        case .agentInferred:
            "Directional inference"
        case .userProvided:
            "User provided"
        case .userEdited:
            "User edited"
        }
    }
}

extension LILADomain.WatchoutSeverity {
    var surfaceTitle: String {
        switch self {
        case .gentle:
            "Gentle"
        case .moderate:
            "Watch"
        case .important:
            "Important"
        }
    }

    var pillTone: WLPill.Tone {
        switch self {
        case .gentle:
            .soft
        case .moderate, .important:
            .neutral
        }
    }
}

extension LILADomain.PersonalRelevance {
    var surfaceTitle: String {
        switch self {
        case .general:
            "General"
        case .personal:
            "Personal"
        case .clinical:
            "Higher sensitivity"
        }
    }
}

extension ProductResolutionSemantic {
    var surfaceTitle: String {
        switch self {
        case .canonical:
            "Exact match"
        case .provisional:
            "Provisional"
        case .directional:
            "Directional"
        case .providerBacked:
            "Provider-backed"
        case .lowConfidence:
            "Thin input"
        }
    }
}
