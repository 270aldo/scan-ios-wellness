import Foundation

enum ProductGraphIdentity {
    static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalized(_ value: String?) -> String? {
        trimmed(value)?.lowercased()
    }

    static func aliases(_ values: [String?]) -> [String] {
        var seen = Set<String>()
        return values
            .compactMap(trimmed)
            .filter { seen.insert($0).inserted }
    }

    static func hasOverlap(_ lhs: [String], _ rhs: [String]) -> Bool {
        let lhsAliases = Set(lhs.compactMap(normalized))
        guard lhsAliases.isEmpty == false else { return false }

        for alias in rhs.compactMap(normalized) where lhsAliases.contains(alias) {
            return true
        }
        return false
    }

    static func dedupeKey(
        relatedProductID: String?,
        sourceScanID: String?,
        fallbackTitle: String
    ) -> String {
        if let normalizedProductID = normalized(relatedProductID) {
            return normalizedProductID
        }

        if let normalizedScanID = normalized(sourceScanID) {
            return "scan:\(normalizedScanID)"
        }

        return fallbackTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct ProductReference: Hashable, Sendable {
    let graphID: String
    let aliases: [String]
    let displayName: String?
    let sourceScanID: String?
    let isProvisional: Bool

    init?(
        graphID: String?,
        aliases: [String?] = [],
        displayName: String? = nil,
        sourceScanID: String? = nil,
        isProvisional: Bool = false
    ) {
        guard let graphID = ProductGraphIdentity.trimmed(graphID) else { return nil }

        self.graphID = graphID
        self.aliases = ProductGraphIdentity.aliases(
            [graphID]
                + aliases
                + [
                    ProductGraphIdentity.trimmed(sourceScanID),
                    ProductGraphIdentity.trimmed(sourceScanID).map { "scan:\($0)" }
                ]
        )
        self.displayName = ProductGraphIdentity.trimmed(displayName)
        self.sourceScanID = ProductGraphIdentity.trimmed(sourceScanID)
        self.isProvisional = isProvisional
    }

    func overlaps(with other: ProductReference) -> Bool {
        ProductGraphIdentity.hasOverlap(aliases, other.aliases)
    }
}

extension FavoriteItem {
    var productReference: ProductReference? {
        ProductReference(
            graphID: "scan:\(scanEventID)",
            aliases: [scanEventID],
            displayName: title,
            sourceScanID: scanEventID,
            isProvisional: true
        )
    }

    var productGraphAliases: [String] {
        productReference?.aliases ?? []
    }
}

extension PantryItem {
    var productReference: ProductReference? {
        ProductReference(
            graphID: relatedProductID ?? sourceScanID.map { "scan:\($0)" },
            aliases: [relatedProductID],
            displayName: title,
            sourceScanID: sourceScanID,
            isProvisional: (ProductGraphIdentity.normalized(relatedProductID)?.hasPrefix("scan:") ?? false)
                || sourceScanID != nil
        )
    }

    var productGraphAliases: [String] {
        productReference?.aliases ?? []
    }
}

extension RoutineItem {
    var productReference: ProductReference? {
        ProductReference(
            graphID: productID,
            displayName: productName,
            isProvisional: ProductGraphIdentity.normalized(productID)?.hasPrefix("scan:") ?? false
        )
    }

    var productGraphAliases: [String] {
        productReference?.aliases ?? []
    }
}

extension ScanDecision {
    var productReference: ProductReference? {
        ProductReference(
            graphID: productID,
            displayName: productName,
            isProvisional: ProductGraphIdentity.normalized(productID)?.hasPrefix("scan:") ?? false
        )
    }

    var productGraphAliases: [String] {
        productReference?.aliases ?? []
    }
}

extension MemoryItem {
    var productReference: ProductReference? {
        ProductReference(
            graphID: relatedProductID,
            displayName: relatedProductName,
            isProvisional: ProductGraphIdentity.normalized(relatedProductID)?.hasPrefix("scan:") ?? false
        )
    }

    var productGraphAliases: [String] {
        productReference?.aliases ?? []
    }
}

extension Experiment {
    var productReference: ProductReference? {
        nil
    }

    var productGraphAliases: [String] {
        productReference?.aliases ?? []
    }

    var hasStableProductIdentity: Bool {
        productReference != nil
    }
}

extension AnalysisInputType {
    var createsProvisionalProductNode: Bool {
        switch self {
        case .mealPhoto, .menuPhoto:
            true
        case .barcode, .labelPhoto, .manual:
            false
        }
    }
}

extension ScanAnalysis {
    func productGraphKey(scanEventID: String? = nil) -> String {
        if source.analysisInputType.createsProvisionalProductNode || resolvedProduct.isProvisionallyResolved {
            return "scan:\(scanEventID ?? id.uuidString)"
        }
        return resolvedProduct.stableIdentityKey
    }

    func productReference(scanEventID: String? = nil) -> ProductReference {
        ProductReference(
            graphID: productGraphKey(scanEventID: scanEventID),
            aliases: [resolvedProduct.stableIdentityKey, resolvedProduct.id],
            displayName: resolvedProduct.name,
            sourceScanID: scanEventID,
            isProvisional: source.analysisInputType.createsProvisionalProductNode || resolvedProduct.isProvisionallyResolved
        )!
    }

    var productIdentityAliases: [String] {
        productReference().aliases
    }
}

extension ScanEvent {
    var createsProvisionalProductNode: Bool {
        inputType.createsProvisionalProductNode || legacyAnalysis.resolvedProduct.isProvisionallyResolved
    }

    var productGraphKey: String {
        legacyAnalysis.productGraphKey(scanEventID: id)
    }

    var preferredRelatedProductID: String {
        productGraphKey
    }

    var productReference: ProductReference {
        legacyAnalysis.productReference(scanEventID: id)
    }

    var productIdentityAliases: [String] {
        productReference.aliases
    }
}

struct ProductGraphIndex {
    private let scanEventsByID: [String: ScanEvent]
    private let scanEventIDsByAlias: [String: [String]]
    private let routineAliases: Set<String>
    private let verdictsByScanID: [String: StoredScanVerdict]
    private let favoritesByAlias: [String: [FavoriteItem]]
    private let memoriesByAlias: [String: [MemoryItem]]
    private let decisionsByAlias: [String: [ScanDecision]]
    private let pantryByAlias: [String: [PantryItem]]

    init(
        scanEvents: [ScanEvent],
        scanVerdicts: [StoredScanVerdict],
        favoriteItems: [FavoriteItem],
        routines: [RoutineItem],
        memoryItems: [MemoryItem],
        scanDecisions: [ScanDecision],
        pantryItems: [PantryItem]
    ) {
        scanEventsByID = Dictionary(uniqueKeysWithValues: scanEvents.map { ($0.id, $0) })
        verdictsByScanID = Dictionary(uniqueKeysWithValues: scanVerdicts.map { ($0.scanEventID, $0) })

        var scanAliases: [String: [String]] = [:]
        for event in scanEvents {
            for alias in event.productReference.aliases.compactMap(ProductGraphIdentity.normalized) {
                scanAliases[alias, default: []].append(event.id)
            }
        }
        scanEventIDsByAlias = scanAliases.mapValues { ids in
            var seen = Set<String>()
            return ids.filter { seen.insert($0).inserted }
        }

        routineAliases = Set(
            routines
                .compactMap(\.productReference)
                .flatMap { $0.aliases.compactMap(ProductGraphIdentity.normalized) }
        )

        favoritesByAlias = Self.groupByAlias(favoriteItems) { $0.productGraphAliases }
        memoriesByAlias = Self.groupByAlias(memoryItems) { $0.productGraphAliases }
        decisionsByAlias = Self.groupByAlias(scanDecisions) { $0.productGraphAliases }
        pantryByAlias = Self.groupByAlias(pantryItems) { $0.productGraphAliases }
    }

    func analysis(for item: PantryItem, history: [ScanRecord]) -> ScanAnalysis? {
        analysis(
            for: item.productReference,
            fallbackSourceScanID: item.sourceScanID,
            history: history
        )
    }

    func analysis(
        for reference: ProductReference?,
        fallbackSourceScanID: String? = nil,
        history: [ScanRecord]
    ) -> ScanAnalysis? {
        let sourceScanID = ProductGraphIdentity.trimmed(reference?.sourceScanID ?? fallbackSourceScanID)
        if let sourceScanID {
            if let event = scanEventsByID[sourceScanID] {
                return event.legacyAnalysis
            }

            if let recordID = UUID(uuidString: sourceScanID),
               let record = history.first(where: { $0.id == recordID }) {
                return record.analysis
            }
        }

        let orderedAliases = (reference?.aliases ?? [])
            .compactMap(ProductGraphIdentity.normalized)
            .sorted { lhs, rhs in
                let lhsSignal = relationshipSignal(for: lhs)
                let rhsSignal = relationshipSignal(for: rhs)
                if lhsSignal != rhsSignal {
                    return lhsSignal > rhsSignal
                }
                return lhs < rhs
            }

        for alias in orderedAliases {
            if let event = bestEvent(for: alias) {
                return event.legacyAnalysis
            }
        }

        return nil
    }

    func hasRoutine(matching aliases: [String]) -> Bool {
        for alias in aliases.compactMap(ProductGraphIdentity.normalized) where routineAliases.contains(alias) {
            return true
        }
        return false
    }

    func hasRoutine(matching reference: ProductReference?) -> Bool {
        guard let reference else { return false }
        return hasRoutine(matching: reference.aliases)
    }

    func hasRoutine(matching item: PantryItem) -> Bool {
        hasRoutine(matching: item.productReference)
    }

    private func relationshipSignal(for alias: String) -> Int {
        (favoritesByAlias[alias]?.count ?? 0)
            + (memoriesByAlias[alias]?.count ?? 0)
            + (decisionsByAlias[alias]?.count ?? 0)
            + (pantryByAlias[alias]?.count ?? 0)
    }

    private func bestEvent(for alias: String) -> ScanEvent? {
        guard let scanEventIDs = scanEventIDsByAlias[alias] else { return nil }
        return scanEventIDs
            .compactMap { scanEventsByID[$0] }
            .sorted { lhs, rhs in
                let lhsHasVerdict = verdictsByScanID[lhs.id] != nil
                let rhsHasVerdict = verdictsByScanID[rhs.id] != nil
                if lhsHasVerdict != rhsHasVerdict {
                    return lhsHasVerdict && !rhsHasVerdict
                }
                return lhs.timestamp > rhs.timestamp
            }
            .first
    }

    private static func groupByAlias<Item>(
        _ items: [Item],
        aliases: (Item) -> [String]
    ) -> [String: [Item]] {
        var grouped: [String: [Item]] = [:]
        for item in items {
            for alias in aliases(item).compactMap(ProductGraphIdentity.normalized) {
                grouped[alias, default: []].append(item)
            }
        }
        return grouped
    }
}
