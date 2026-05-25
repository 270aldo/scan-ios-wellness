import Foundation

/// Cliente HTTP que llama al endpoint `POST /v1/scan/verdict` del agent-service.
///
/// Si la red falla, el servidor devuelve error, el payload no valida, o el
/// timeout se cumple, hace auto-fallback al `DeterministicScanVerdictAgent`
/// local sin propagar el error a la UI.
struct RemoteScanVerdictAgent: ScanVerdictServing {
    let endpoint: URL
    let session: URLSession
    let timeoutSeconds: TimeInterval
    let localFallback: ScanVerdictServing
    let identityProvider: IdentityProviding
    let appCheckProvider: AppCheckTokenProviding

    init(
        endpoint: URL,
        session: URLSession = .shared,
        timeoutSeconds: TimeInterval = 8,
        localFallback: ScanVerdictServing = DeterministicScanVerdictAgent(),
        identityProvider: IdentityProviding,
        appCheckProvider: AppCheckTokenProviding
    ) {
        self.endpoint = endpoint
        self.session = session
        self.timeoutSeconds = timeoutSeconds
        self.localFallback = localFallback
        self.identityProvider = identityProvider
        self.appCheckProvider = appCheckProvider
    }

    func generateVerdict(for request: ScanVerdictRequest) async -> LILADomain.ScanVerdict {
        do {
            let payload = try buildRequestPayload(from: request)
            var urlRequest = URLRequest(url: endpoint)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            if let authorizationHeader = await identityProvider.authorizationHeader() {
                urlRequest.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
            }
            if let appCheckToken = await appCheckProvider.token() {
                urlRequest.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
            }
            urlRequest.httpBody = payload
            urlRequest.timeoutInterval = timeoutSeconds

            let (data, response) = try await session.data(for: urlRequest)

            guard let http = response as? HTTPURLResponse else {
                return await fallbackVerdict(for: request, reason: "invalid-response")
            }

            guard (200..<300).contains(http.statusCode) else {
                return await fallbackVerdict(
                    for: request,
                    reason: httpFailureReason(statusCode: http.statusCode, data: data)
                )
            }

            let decoder = JSONDecoder()
            let envelope: RemoteScanVerdictResponse
            do {
                envelope = try decoder.decode(RemoteScanVerdictResponse.self, from: data)
            } catch {
                return await fallbackVerdict(for: request, reason: "decode-error")
            }
            return envelope.verdict.asDomainVerdict(
                resolvedProduct: request.remoteResolvedProduct.remoteLILAResolvedProduct,
                scanSource: request.input.sourceType.remoteLILAScanSource
            )
        } catch {
            return await fallbackVerdict(
                for: request,
                reason: "transport-\(sanitizeReasonFragment(error.localizedDescription))"
            )
        }
    }

    private func buildRequestPayload(from request: ScanVerdictRequest) throws -> Data {
        let encoder = JSONEncoder()
        let wire = RemoteScanVerdictRequest(
            scanId: request.legacyAnalysis.id.uuidString,
            productName: request.remoteResolvedProduct.name,
            source: request.input.sourceType.agentWireValue,
            userContextSummary: request.scanVerdictContextSummary,
            structuredSummary: request.remoteStructuredSummary,
            resolvedProduct: RemoteResolvedProductWire(from: request.remoteResolvedProduct)
        )
        return try encoder.encode(wire)
    }

    private func fallbackVerdict(for request: ScanVerdictRequest, reason: String) async -> LILADomain.ScanVerdict {
        var verdict = await localFallback.generateVerdict(for: request)
        verdict.reasoningBreakdown.agentInsights.insert(
            LILADomain.AgentInsight(
                insight: "iOS remote verdict fallback engaged before the UI could be interrupted (\(reason)).",
                modelUsed: "ios-remote-fallback/\(reason)",
                confidenceScore: verdict.confidence.numericValue
            ),
            at: 0
        )
        return verdict
    }

    private func httpFailureReason(statusCode: Int, data: Data) -> String {
        if let detail = responseDetail(from: data) {
            return "http-\(statusCode)-\(sanitizeReasonFragment(detail))"
        }
        return "http-\(statusCode)"
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
        return raw
    }

    private func sanitizeReasonFragment(_ value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        if normalized.isEmpty {
            return "unknown"
        }
        return String(normalized.prefix(80))
    }
}

private struct RemoteScanVerdictRequest: Encodable {
    let scanId: String?
    let productName: String
    let source: String
    let userContextSummary: String
    let structuredSummary: String?
    let resolvedProduct: RemoteResolvedProductWire?

    enum CodingKeys: String, CodingKey {
        case scanId
        case productName
        case source
        case userContextSummary
        case structuredSummary
        case resolvedProduct = "resolved_product"
    }
}

private struct RemoteResolvedProductWire: Encodable {
    let productId: String?
    let canonicalProductID: String?
    let name: String
    let brand: String?
    let barcode: String?
    let source: String?
    let confidence: Double?
    let ingredients: [String]
    let nutritionSnapshot: NutritionSnapshot?
    let mexicoNutritionSignals: MexicoNutritionSignals?
    let isDirectional: Bool

    init(from product: ProductCandidate) {
        productId = product.id
        canonicalProductID = product.resolution?.canonicalProductID
        name = product.name
        brand = product.brand
        barcode = product.barcode
        source = product.resolution?.source.rawValue
        confidence = product.resolution?.confidence
        ingredients = product.ingredients.map(\.name)
        nutritionSnapshot = product.resolution?.nutritionSnapshot
        mexicoNutritionSignals = product.mexicoNutritionSignals
        isDirectional = product.resolution?.isDirectional ?? false
    }

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case canonicalProductID = "canonical_product_id"
        case name
        case brand
        case barcode
        case source
        case confidence
        case ingredients
        case nutritionSnapshot = "nutrition_snapshot"
        case mexicoNutritionSignals = "mexico_nutrition_signals"
        case isDirectional = "is_directional"
    }
}

private struct RemoteScanVerdictResponse: Decodable {
    let verdict: RemoteScanVerdictWire
}

private struct RemoteScanVerdictWire: Decodable {
    let fit: String
    let confidence: String
    let headline: String
    let primaryReason: String
    let lensScores: [RemoteLensScoreWire]
    let watchouts: [RemoteWatchoutWire]
    let betterSwap: RemoteAlternativeWire?
    let trackPrompt: RemoteTrackPromptWire?
    let evidenceTier: String
    let reasoningBreakdown: RemoteReasoningBreakdownWire
    let disclaimer: String
    let sources: [RemoteEvidenceSourceWire]

    func asDomainVerdict(
        resolvedProduct: LILADomain.ResolvedProduct,
        scanSource: LILADomain.ScanSource
    ) -> LILADomain.ScanVerdict {
        LILADomain.ScanVerdict(
            createdAt: .now,
            resolvedProduct: resolvedProduct,
            scanSource: scanSource,
            fit: fit.domainFit,
            confidence: confidence.domainConfidence,
            headline: headline,
            primaryReason: primaryReason,
            lensScores: lensScores.map(\.domainLensScore),
            watchouts: watchouts.map(\.domainWatchout),
            betterSwap: betterSwap?.domainAlternative,
            trackPrompt: trackPrompt?.domainTrackPrompt,
            evidenceTier: evidenceTier.domainEvidenceTier,
            reasoningBreakdown: reasoningBreakdown.domainReasoningBreakdown,
            disclaimer: disclaimer,
            sources: sources.map(\.domainEvidenceSource)
        )
    }
}

private struct RemoteLensScoreWire: Decodable {
    let lens: String
    let score: Int
    let trend: String
    let summary: String
    let contextApplied: [RemoteContextFactorWire]

    var domainLensScore: LILADomain.LensScore {
        LILADomain.LensScore(
            lens: lens.domainLens,
            score: score,
            trend: trend.domainTrend,
            summary: summary,
            contextApplied: contextApplied.map(\.domainContextFactor)
        )
    }
}

private struct RemoteContextFactorWire: Decodable {
    let label: String
    let direction: String
    let explanation: String

    var domainContextFactor: LILADomain.ContextFactor {
        LILADomain.ContextFactor(
            label: label,
            direction: direction.domainFactorDirection,
            explanation: explanation
        )
    }
}

private struct RemoteWatchoutWire: Decodable {
    let title: String
    let detail: String
    let severity: String
    let personalRelevance: String

    var domainWatchout: LILADomain.Watchout {
        LILADomain.Watchout(
            title: title,
            detail: detail,
            severity: severity.domainWatchoutSeverity,
            personalRelevance: personalRelevance.domainPersonalRelevance
        )
    }
}

private struct RemoteAlternativeWire: Decodable {
    let productName: String
    let productID: String?
    let brand: String?
    let whyBetter: String
    let improvedLenses: [String]
    let expectedLensDeltas: [RemoteLensDeltaWire]

    var domainAlternative: LILADomain.Alternative {
        LILADomain.Alternative(
            productName: productName,
            productID: productID,
            brand: brand,
            whyBetter: whyBetter,
            improvedLenses: improvedLenses.map(\.domainLens),
            expectedLensDeltas: expectedLensDeltas.map(\.domainLensDelta)
        )
    }
}

private struct RemoteLensDeltaWire: Decodable {
    let lens: String
    let estimatedChange: Int

    var domainLensDelta: LILADomain.LensDelta {
        LILADomain.LensDelta(lens: lens.domainLens, estimatedChange: estimatedChange)
    }
}

private struct RemoteTrackPromptWire: Decodable {
    let triggerAfterHours: Int
    let questionText: String
    let targetLens: String
    let expectedResponseType: String

    var domainTrackPrompt: LILADomain.FollowUpPrompt {
        LILADomain.FollowUpPrompt(
            triggerAfterHours: triggerAfterHours,
            questionText: questionText,
            targetLens: targetLens.domainLens,
            expectedResponseType: expectedResponseType.domainFollowUpResponseType
        )
    }
}

private struct RemoteReasoningBreakdownWire: Decodable {
    let deterministicFactors: [RemoteDeterministicFactorWire]
    let agentInsights: [RemoteAgentInsightWire]
    let userHistoryFactors: [RemoteUserHistoryFactorWire]
    let totalAdjustments: Int

    var domainReasoningBreakdown: LILADomain.ReasoningBreakdown {
        LILADomain.ReasoningBreakdown(
            deterministicFactors: deterministicFactors.map(\.domainDeterministicFactor),
            agentInsights: agentInsights.map(\.domainAgentInsight),
            userHistoryFactors: userHistoryFactors.map(\.domainUserHistoryFactor),
            totalAdjustments: totalAdjustments
        )
    }
}

private struct RemoteDeterministicFactorWire: Decodable {
    let rule: String
    let delta: Int
    let affectedLens: String

    var domainDeterministicFactor: LILADomain.DeterministicFactor {
        LILADomain.DeterministicFactor(
            rule: rule,
            delta: delta,
            affectedLens: affectedLens.domainLens
        )
    }
}

private struct RemoteAgentInsightWire: Decodable {
    let insight: String
    let modelUsed: String
    let confidenceScore: Double

    var domainAgentInsight: LILADomain.AgentInsight {
        LILADomain.AgentInsight(
            insight: insight,
            modelUsed: modelUsed,
            confidenceScore: confidenceScore
        )
    }
}

private struct RemoteUserHistoryFactorWire: Decodable {
    let pattern: String
    let scansReferenced: Int

    var domainUserHistoryFactor: LILADomain.UserHistoryFactor {
        LILADomain.UserHistoryFactor(pattern: pattern, scansReferenced: scansReferenced)
    }
}

private struct RemoteEvidenceSourceWire: Decodable {
    let title: String
    let organization: String
    let url: String?
    let publishedYear: Int?
    let tier: String

    var domainEvidenceSource: LILADomain.EvidenceSource {
        LILADomain.EvidenceSource(
            title: title,
            organization: organization,
            url: url.flatMap(URL.init(string:)),
            publishedYear: publishedYear,
            tier: tier.domainEvidenceTier
        )
    }
}

private extension ScanVerdictRequest {
    var remoteResolvedProduct: ProductCandidate {
        structuredAnalysis?.resolvedProduct ?? legacyAnalysis.resolvedProduct
    }

    var scanVerdictContextSummary: String {
        let context = profile.lilaContext(biometrics: biometrics)
        var parts: [String] = []

        if let age = context.identity.age {
            parts.append("Age: \(age)")
        }
        parts.append("Biology: \(context.biology.displayTitle)")
        parts.append("Diet style: \(context.dietStyle.rawValue)")

        if let phase = context.biology.currentPhase {
            parts.append("Cycle phase: \(phase.rawValue)")
        }
        if !context.sensitivities.isEmpty {
            parts.append("Sensitivities: \(context.sensitivities.map(\.rawValue).sorted().joined(separator: ", "))")
        }
        if !context.goals.primary.isEmpty {
            parts.append("Goals: \(context.goals.primary.map(\.displayTitle).joined(separator: ", "))")
        }
        if let latestCheckIn = recentCheckIns.first {
            parts.append(
                "Recent check-in: energy \(latestCheckIn.energy)/5, bloating \(latestCheckIn.bloating)/5, mood \(latestCheckIn.mood)/5"
            )
        }
        if !recentScans.isEmpty {
            parts.append("Recent scans available: \(min(recentScans.count, 5))")
        }
        if biometrics?.trainingLoad?.isInAnabolicWindow == true {
            parts.append("Recently trained")
        }
        if let sleepHours = biometrics?.sleepHours, sleepHours < 6 {
            parts.append("Short sleep recent")
        }

        return parts.joined(separator: ". ")
    }

    var remoteStructuredSummary: String? {
        var parts: [String] = [legacyAnalysis.overallSummary]
        if !legacyAnalysis.topReasons.isEmpty {
            parts.append("Reasons: \(legacyAnalysis.topReasons.prefix(3).map(\.detail).joined(separator: " | "))")
        }
        if !legacyAnalysis.warnings.isEmpty {
            parts.append("Warnings: \(legacyAnalysis.warnings.prefix(2).joined(separator: " | "))")
        }
        if let structuredAnalysis {
            parts.append("Why today: \(structuredAnalysis.whyToday.prefix(3).joined(separator: " | "))")
            parts.append("Actions: \(structuredAnalysis.recommendedActions.prefix(2).joined(separator: " | "))")
            if let resolvedProduct = structuredAnalysis.resolvedProduct {
                parts.append("Structured resolved product: \(resolvedProduct.name)")
            }
        }
        let summary = parts.joined(separator: ". ").trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? nil : summary
    }
}

private extension ScanSource {
    var remoteLILAScanSource: LILADomain.ScanSource {
        switch self {
        case .liveBarcode: .liveBarcode
        case .manualBarcode: .manualBarcode
        case .labelPhoto: .labelPhoto
        case .mealPhoto: .mealPhoto
        case .menuPhoto: .menuPhoto
        case .manualLabel: .manualLabel
        }
    }

    var agentWireValue: String {
        switch self {
        case .liveBarcode, .manualBarcode:
            "barcode"
        case .labelPhoto:
            "label_photo"
        case .mealPhoto:
            "meal_photo"
        case .menuPhoto:
            "menu_photo"
        case .manualLabel:
            "manual"
        }
    }
}

private extension ProductCandidate {
    var remoteLILAResolvedProduct: LILADomain.ResolvedProduct {
        LILADomain.ResolvedProduct(
            id: id,
            canonicalProductID: resolution?.canonicalProductID,
            resolutionSemantics: resolvedResolutionSemantics,
            name: name,
            brand: brand,
            category: productType.remoteLILAProductCategory,
            barcode: barcode,
            ingredients: ingredients.map(\.name),
            nutrition: resolution?.nutritionSnapshot?.remoteLILANutritionProfile(for: self),
            skincare: nil,
            resolutionSource: resolution?.source.remoteLILAResolutionSource ?? .localCatalog,
            headline: headline,
            imageURL: nil
        )
    }
}

private extension ProductType {
    var remoteLILAProductCategory: LILADomain.ProductCategory {
        switch self {
        case .food, .skincare, .haircare, .personalCare:
            .foodAndDrink
        case .supplement:
            .supplement
        }
    }
}

private extension ProductResolutionSource {
    var remoteLILAResolutionSource: LILADomain.ResolutionSource {
        switch self {
        case .openFoodFacts:
            .openFoodFacts
        case .usdaFoodDataCentral:
            .usdaFoodDataCentral
        case .nihDSLD:
            .nihDSLD
        case .cosing:
            .cosing
        case .localCatalog:
            .localCatalog
        case .agentInferred:
            .agentInferred
        case .userProvided:
            .userProvided
        case .userEdited:
            .userEdited
        }
    }
}

private extension NutritionSnapshot {
    func remoteLILANutritionProfile(for _: ProductCandidate) -> LILADomain.NutritionProfile {
        LILADomain.NutritionProfile(
            macros: .init(
                energyKcal: energyKcalPer100g ?? 0,
                proteinG: proteinGPer100g ?? 0,
                carbsG: carbsGPer100g ?? 0,
                fatG: fatGPer100g ?? 0
            ),
            micros: .empty,
            caffeineMg: caffeineMgPer100g,
            alcoholPercent: nil,
            addedSugarsG: sugarsGPer100g,
            freeSugarsG: sugarsGPer100g,
            saturatedFatG: nil,
            transFatG: nil,
            sodiumMg: sodiumMgPer100g,
            fiberG: fiberGPer100g,
            glycemicIndex: nil,
            glycemicLoad: nil,
            nutriScore: nil,
            novaGroup: novaGroup.flatMap {
                switch $0 {
                case 1: .unprocessed
                case 2: .culinaryIngredient
                case 3: .processed
                case 4: .ultraProcessed
                default: nil
                }
            },
            additives: [],
            allergens: [],
            dietaryFlags: [],
            servingSize: nil
        )
    }
}

private extension String {
    var domainFit: LILADomain.FitLevel {
        switch self {
        case "greatFit": .greatFit
        case "goodFit": .goodFit
        case "occasional": .occasional
        case "skip": .skip
        default: .unclear
        }
    }

    var domainConfidence: LILADomain.Confidence {
        switch self {
        case "high": .high
        case "medium": .medium
        case "low": .low
        default: .insufficient
        }
    }

    var domainLens: LILADomain.WellnessLens {
        switch self {
        case "glowAndSkin": .glowAndSkin
        case "hormoneBalance": .hormoneBalance
        case "gutComfort": .gutComfort
        case "energyAndMood": .energyAndMood
        default: .bodyCompositionAndStrength
        }
    }

    var domainTrend: LILADomain.ScoreTrend {
        switch self {
        case "rising": .rising
        case "falling": .falling
        default: .neutral
        }
    }

    var domainFactorDirection: LILADomain.FactorDirection {
        switch self {
        case "boost": .boost
        case "reduce": .reduce
        default: .neutral
        }
    }

    var domainWatchoutSeverity: LILADomain.WatchoutSeverity {
        switch self {
        case "gentle": .gentle
        case "important": .important
        default: .moderate
        }
    }

    var domainPersonalRelevance: LILADomain.PersonalRelevance {
        switch self {
        case "personal": .personal
        case "clinical": .clinical
        default: .general
        }
    }

    var domainFollowUpResponseType: LILADomain.FollowUpResponseType {
        switch self {
        case "intensityScale": .intensityScale
        case "symptomsChecklist": .symptomsChecklist
        default: .openText
        }
    }

    var domainEvidenceTier: LILADomain.EvidenceTier {
        switch self {
        case "high": .high
        case "personalPattern": .personalPattern
        default: .emerging
        }
    }
}
