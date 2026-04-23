import Foundation

extension LILADomain {
    struct ScanVerdict: Codable, Hashable, Identifiable, Sendable {
        var id: UUID
        var createdAt: Date
        var resolvedProduct: ResolvedProduct
        var scanSource: ScanSource
        var fit: FitLevel
        var confidence: Confidence
        var headline: String
        var primaryReason: String
        var lensScores: [LensScore]
        var watchouts: [Watchout]
        var betterSwap: Alternative?
        var trackPrompt: FollowUpPrompt?
        var evidenceTier: EvidenceTier
        var reasoningBreakdown: ReasoningBreakdown
        var disclaimer: String
        var sources: [EvidenceSource]

        init(
            id: UUID = UUID(),
            createdAt: Date = .now,
            resolvedProduct: ResolvedProduct,
            scanSource: ScanSource,
            fit: FitLevel,
            confidence: Confidence,
            headline: String,
            primaryReason: String,
            lensScores: [LensScore],
            watchouts: [Watchout] = [],
            betterSwap: Alternative? = nil,
            trackPrompt: FollowUpPrompt? = nil,
            evidenceTier: EvidenceTier,
            reasoningBreakdown: ReasoningBreakdown,
            disclaimer: String,
            sources: [EvidenceSource] = []
        ) {
            self.id = id
            self.createdAt = createdAt
            self.resolvedProduct = resolvedProduct
            self.scanSource = scanSource
            self.fit = fit
            self.confidence = confidence
            self.headline = headline
            self.primaryReason = primaryReason
            self.lensScores = lensScores
            self.watchouts = Array(watchouts.prefix(2))
            self.betterSwap = betterSwap
            self.trackPrompt = trackPrompt
            self.evidenceTier = evidenceTier
            self.reasoningBreakdown = reasoningBreakdown
            self.disclaimer = disclaimer
            self.sources = sources
        }
    }

    enum FitLevel: String, Codable, Sendable {
        case greatFit
        case goodFit
        case occasional
        case skip
        case unclear
    }

    enum Confidence: String, Codable, Sendable {
        case high
        case medium
        case low
        case insufficient

        var numericValue: Double {
            switch self {
            case .high: 0.92
            case .medium: 0.72
            case .low: 0.45
            case .insufficient: 0.18
            }
        }
    }

    struct LensScore: Codable, Hashable, Identifiable, Sendable {
        var id: WellnessLens { lens }
        var lens: WellnessLens
        var score: Int
        var trend: ScoreTrend
        var summary: String
        var contextApplied: [ContextFactor]

        init(
            lens: WellnessLens,
            score: Int,
            trend: ScoreTrend = .neutral,
            summary: String,
            contextApplied: [ContextFactor] = []
        ) {
            self.lens = lens
            self.score = max(0, min(100, score))
            self.trend = trend
            self.summary = summary
            self.contextApplied = contextApplied
        }
    }

    enum ScoreTrend: String, Codable, Sendable {
        case rising
        case neutral
        case falling
    }

    struct ContextFactor: Codable, Hashable, Identifiable, Sendable {
        var id: UUID
        var label: String
        var direction: FactorDirection
        var explanation: String

        init(
            id: UUID = UUID(),
            label: String,
            direction: FactorDirection,
            explanation: String
        ) {
            self.id = id
            self.label = label
            self.direction = direction
            self.explanation = explanation
        }
    }

    enum FactorDirection: String, Codable, Sendable {
        case boost
        case reduce
        case neutral
    }

    struct Watchout: Codable, Hashable, Identifiable, Sendable {
        var id: UUID
        var title: String
        var detail: String
        var severity: WatchoutSeverity
        var personalRelevance: PersonalRelevance

        init(
            id: UUID = UUID(),
            title: String,
            detail: String,
            severity: WatchoutSeverity,
            personalRelevance: PersonalRelevance
        ) {
            self.id = id
            self.title = title
            self.detail = detail
            self.severity = severity
            self.personalRelevance = personalRelevance
        }
    }

    enum WatchoutSeverity: String, Codable, Sendable {
        case gentle
        case moderate
        case important
    }

    enum PersonalRelevance: String, Codable, Sendable {
        case general
        case personal
        case clinical
    }

    struct Alternative: Codable, Hashable, Identifiable, Sendable {
        var id: UUID
        var productName: String
        var productID: String?
        var brand: String?
        var whyBetter: String
        var improvedLenses: [WellnessLens]
        var expectedLensDeltas: [LensDelta]

        init(
            id: UUID = UUID(),
            productName: String,
            productID: String? = nil,
            brand: String? = nil,
            whyBetter: String,
            improvedLenses: [WellnessLens],
            expectedLensDeltas: [LensDelta] = []
        ) {
            self.id = id
            self.productName = productName
            self.productID = productID
            self.brand = brand
            self.whyBetter = whyBetter
            self.improvedLenses = improvedLenses
            self.expectedLensDeltas = expectedLensDeltas
        }
    }

    struct LensDelta: Codable, Hashable, Sendable {
        var lens: WellnessLens
        var estimatedChange: Int
    }

    struct FollowUpPrompt: Codable, Hashable, Sendable {
        var triggerAfterHours: Int
        var questionText: String
        var targetLens: WellnessLens
        var expectedResponseType: FollowUpResponseType
    }

    enum FollowUpResponseType: String, Codable, Sendable {
        case intensityScale
        case symptomsChecklist
        case openText
    }

    enum EvidenceTier: String, Codable, Sendable {
        case high
        case emerging
        case personalPattern
    }

    struct ReasoningBreakdown: Codable, Hashable, Sendable {
        var deterministicFactors: [DeterministicFactor]
        var agentInsights: [AgentInsight]
        var userHistoryFactors: [UserHistoryFactor]
        var totalAdjustments: Int
    }

    struct DeterministicFactor: Codable, Hashable, Identifiable, Sendable {
        var id: UUID
        var rule: String
        var delta: Int
        var affectedLens: WellnessLens

        init(id: UUID = UUID(), rule: String, delta: Int, affectedLens: WellnessLens) {
            self.id = id
            self.rule = rule
            self.delta = delta
            self.affectedLens = affectedLens
        }
    }

    struct AgentInsight: Codable, Hashable, Identifiable, Sendable {
        var id: UUID
        var insight: String
        var modelUsed: String
        var confidenceScore: Double

        init(id: UUID = UUID(), insight: String, modelUsed: String, confidenceScore: Double) {
            self.id = id
            self.insight = insight
            self.modelUsed = modelUsed
            self.confidenceScore = confidenceScore
        }
    }

    struct UserHistoryFactor: Codable, Hashable, Identifiable, Sendable {
        var id: UUID
        var pattern: String
        var scansReferenced: Int

        init(id: UUID = UUID(), pattern: String, scansReferenced: Int) {
            self.id = id
            self.pattern = pattern
            self.scansReferenced = scansReferenced
        }
    }

    struct EvidenceSource: Codable, Hashable, Identifiable, Sendable {
        var id: UUID
        var title: String
        var organization: String
        var url: URL?
        var publishedYear: Int?
        var tier: EvidenceTier

        init(
            id: UUID = UUID(),
            title: String,
            organization: String,
            url: URL? = nil,
            publishedYear: Int? = nil,
            tier: EvidenceTier
        ) {
            self.id = id
            self.title = title
            self.organization = organization
            self.url = url
            self.publishedYear = publishedYear
            self.tier = tier
        }
    }

    struct ResolvedProduct: Codable, Hashable, Identifiable, Sendable {
        var id: String
        var canonicalProductID: String? = nil
        var resolutionSemantics: [ProductResolutionSemantic]? = nil
        var name: String
        var brand: String?
        var category: ProductCategory
        var barcode: String?
        var ingredients: [String]
        var nutrition: NutritionProfile?
        var skincare: SkincareProfile?
        var resolutionSource: ResolutionSource
        var headline: String?
        var imageURL: URL?

        var stableIdentityKey: String {
            let canonical = canonicalProductID?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let canonical, !canonical.isEmpty {
                return canonical
            }
            return id
        }
    }

    enum ResolutionSource: String, Codable, Sendable {
        case openFoodFacts
        case usdaFoodDataCentral
        case nihDSLD
        case cosing
        case localCatalog
        case agentInferred
        case userProvided
        case userEdited
    }

    enum ScanSource: String, Codable, CaseIterable, Sendable {
        case liveBarcode
        case manualBarcode
        case labelPhoto
        case mealPhoto
        case menuPhoto
        case manualLabel
        case voiceLog
    }
}
