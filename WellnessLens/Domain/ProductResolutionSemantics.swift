import Foundation

enum ProductResolutionSemantic: String, Codable, CaseIterable, Hashable, Sendable {
    case canonical
    case provisional
    case directional
    case providerBacked = "provider_backed"
    case lowConfidence = "low_confidence"
}

enum ProductResolutionSemantics {
    static let lowConfidenceThreshold = 0.58

    private static let semanticOrder: [ProductResolutionSemantic] = [
        .canonical,
        .provisional,
        .directional,
        .providerBacked,
        .lowConfidence,
    ]

    private static let providerBackedSources: Set<ProductResolutionSource> = [
        .openFoodFacts,
        .usdaFoodDataCentral,
        .nihDSLD,
        .cosing,
        .localCatalog,
    ]

    private static let providerBackedLILASources: Set<LILADomain.ResolutionSource> = [
        .openFoodFacts,
        .usdaFoodDataCentral,
        .nihDSLD,
        .cosing,
        .localCatalog,
    ]

    static func resolved(for product: ProductCandidate, fallbackConfidence: ConfidenceLevel? = nil) -> [ProductResolutionSemantic] {
        if let explicitSemantics = product.resolutionSemantics, explicitSemantics.isEmpty == false {
            return ordered(explicitSemantics)
        }

        return derive(
            productID: product.id,
            canonicalProductID: product.resolution?.canonicalProductID,
            resolutionConfidence: product.resolution?.confidence,
            isDirectional: product.resolution?.isDirectional ?? false,
            isProviderBacked: product.resolution.map { providerBackedSources.contains($0.source) } ?? false,
            fallbackConfidence: fallbackConfidence
        )
    }

    static func resolved(for analysis: ScanAnalysis) -> [ProductResolutionSemantic] {
        resolved(for: analysis.resolvedProduct, fallbackConfidence: analysis.confidence)
    }

    static func resolved(for product: LILADomain.ResolvedProduct) -> [ProductResolutionSemantic] {
        if let explicitSemantics = product.resolutionSemantics, explicitSemantics.isEmpty == false {
            return ordered(explicitSemantics)
        }

        return derive(
            productID: product.id,
            canonicalProductID: product.canonicalProductID,
            resolutionConfidence: nil,
            isDirectional: product.resolutionSource == .agentInferred,
            isProviderBacked: providerBackedLILASources.contains(product.resolutionSource),
            fallbackConfidence: nil
        )
    }

    private static func derive(
        productID: String,
        canonicalProductID: String?,
        resolutionConfidence: Double?,
        isDirectional: Bool,
        isProviderBacked: Bool,
        fallbackConfidence: ConfidenceLevel?
    ) -> [ProductResolutionSemantic] {
        let canonicalProductID = canonicalProductID?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var semantics: Set<ProductResolutionSemantic> = []

        if let canonicalProductID, canonicalProductID.isEmpty == false {
            semantics.insert(.canonical)
        }

        if isDirectional {
            semantics.insert(.directional)
            semantics.insert(.provisional)
        } else if (canonicalProductID?.isEmpty ?? true) && isProvisionalIdentity(productID) {
            semantics.insert(.provisional)
        }

        if isProviderBacked {
            semantics.insert(.providerBacked)
        }

        if let resolutionConfidence {
            if resolutionConfidence < lowConfidenceThreshold {
                semantics.insert(.lowConfidence)
            }
        } else if fallbackConfidence == .low {
            semantics.insert(.lowConfidence)
        }

        return ordered(semantics)
    }

    private static func ordered<S: Sequence>(_ semantics: S) -> [ProductResolutionSemantic] where S.Element == ProductResolutionSemantic {
        let seen = Set(semantics)
        return semanticOrder.filter { seen.contains($0) }
    }

    private static func isProvisionalIdentity(_ productID: String) -> Bool {
        let normalizedProductID = productID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalizedProductID.hasPrefix("scan:")
            || normalizedProductID.hasPrefix("directional:")
            || normalizedProductID.hasPrefix("custom-")
    }
}

extension ProductCandidate {
    var resolvedResolutionSemantics: [ProductResolutionSemantic] {
        ProductResolutionSemantics.resolved(for: self)
    }

    func hasResolutionSemantic(
        _ semantic: ProductResolutionSemantic,
        fallbackConfidence: ConfidenceLevel? = nil
    ) -> Bool {
        ProductResolutionSemantics
            .resolved(for: self, fallbackConfidence: fallbackConfidence)
            .contains(semantic)
    }
}

extension ScanAnalysis {
    var resolvedResolutionSemantics: [ProductResolutionSemantic] {
        ProductResolutionSemantics.resolved(for: self)
    }
}

extension LILADomain.ResolvedProduct {
    var resolvedResolutionSemantics: [ProductResolutionSemantic] {
        ProductResolutionSemantics.resolved(for: self)
    }

    func hasResolutionSemantic(_ semantic: ProductResolutionSemantic) -> Bool {
        resolvedResolutionSemantics.contains(semantic)
    }
}
