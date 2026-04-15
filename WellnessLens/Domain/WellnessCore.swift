import Foundation

enum ProductType: String, Codable, CaseIterable, Identifiable {
    case food
    case supplement
    case skincare
    case haircare
    case personalCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: "Food & Drink"
        case .supplement: "Supplement"
        case .skincare: "Skincare"
        case .haircare: "Haircare"
        case .personalCare: "Personal Care"
        }
    }
}

enum ScanSource: String, Codable, CaseIterable {
    case liveBarcode
    case manualBarcode
    case labelPhoto
    case manualLabel

    var title: String {
        switch self {
        case .liveBarcode: "Live barcode"
        case .manualBarcode: "Manual barcode"
        case .labelPhoto: "Label photo"
        case .manualLabel: "Manual label"
        }
    }
}

enum WellnessLensKind: String, Codable, CaseIterable, Identifiable {
    case glowSkin
    case hormoneBalance
    case gutComfort
    case energyMood
    case bodyCompositionStrength

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glowSkin: "Glow & Skin"
        case .hormoneBalance: "Hormone Balance"
        case .gutComfort: "Gut Comfort"
        case .energyMood: "Energy & Mood"
        case .bodyCompositionStrength: "Body Composition & Strength"
        }
    }

    var icon: String {
        switch self {
        case .glowSkin: "sparkles"
        case .hormoneBalance: "waveform.path.ecg"
        case .gutComfort: "leaf"
        case .energyMood: "bolt.heart"
        case .bodyCompositionStrength: "figure.strengthtraining.traditional"
        }
    }
}

enum ConfidenceLevel: String, Codable, CaseIterable {
    case high
    case medium
    case low

    var title: String { rawValue.capitalized }
}

enum UserGoal: String, Codable, CaseIterable, Identifiable {
    case clearSkin
    case steadyEnergy
    case gutCalm
    case hormoneSupport
    case leanStrength
    case deBloat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clearSkin: "Clearer skin"
        case .steadyEnergy: "Steadier energy"
        case .gutCalm: "Calmer digestion"
        case .hormoneSupport: "Hormone support"
        case .leanStrength: "Lean strength"
        case .deBloat: "Less bloating"
        }
    }
}

enum SensitivityFlag: String, Codable, CaseIterable, Identifiable {
    case fragranceSensitive
    case caffeineSensitive
    case sugarSensitive
    case acneProne
    case drySkin
    case reactiveDigestion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fragranceSensitive: "Fragrance sensitive"
        case .caffeineSensitive: "Caffeine sensitive"
        case .sugarSensitive: "Sugar sensitive"
        case .acneProne: "Acne-prone"
        case .drySkin: "Dry skin"
        case .reactiveDigestion: "Reactive digestion"
        }
    }
}

enum DietStyle: String, Codable, CaseIterable, Identifiable {
    case omnivore
    case pescatarian
    case vegetarian
    case dairyLight
    case highProtein
    case flexitarian

    var id: String { rawValue }

    var title: String {
        switch self {
        case .omnivore: "Omnivore"
        case .pescatarian: "Pescatarian"
        case .vegetarian: "Vegetarian"
        case .dairyLight: "Dairy-light"
        case .highProtein: "High-protein"
        case .flexitarian: "Flexitarian"
        }
    }
}

enum SkinConcern: String, Codable, CaseIterable, Identifiable {
    case blemishes
    case sensitivity
    case dullness
    case dryness
    case texture

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blemishes: "Blemishes"
        case .sensitivity: "Sensitivity"
        case .dullness: "Dullness"
        case .dryness: "Dryness"
        case .texture: "Texture"
        }
    }
}

enum LifeStage: String, Codable, CaseIterable, Identifiable {
    case everyDay
    case highStress
    case postpartumAware
    case perimenopauseAware

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyDay: "Everyday wellness"
        case .highStress: "High-stress season"
        case .postpartumAware: "Postpartum-aware"
        case .perimenopauseAware: "Perimenopause-aware"
        }
    }
}

enum IngredientTag: String, Codable, CaseIterable, Hashable {
    case proteinDense
    case probiotic
    case fiberSupport
    case sugarSpike
    case sugarAlcohol
    case stimulant
    case ultraProcessed
    case collagen
    case omegaSupport
    case niacinamide
    case peptide
    case hyaluronicAcid
    case retinoid
    case fragrance
    case alcoholDrying
    case harshSurfactants
    case mineralSPF
    case antioxidantBlend
    case emulsifierHeavy
}

struct UserContext: Codable, Hashable {
    var goals: [UserGoal]
    var sensitivities: [SensitivityFlag]
    var dietStyle: DietStyle
    var skinConcerns: [SkinConcern]
    var lifeStage: LifeStage
    var optInCycleAware: Bool

    static let starter = UserContext(
        goals: [.clearSkin, .steadyEnergy, .gutCalm],
        sensitivities: [.fragranceSensitive],
        dietStyle: .flexitarian,
        skinConcerns: [.blemishes, .dryness],
        lifeStage: .everyDay,
        optInCycleAware: false
    )
}

struct ScanInput: Codable, Hashable {
    var sourceType: ScanSource
    var barcode: String?
    var capturedImageRef: String?
    var rawText: String?
    var productTypeHint: ProductType?
    var locale: String
}

struct Ingredient: Codable, Hashable, Identifiable {
    var name: String

    var id: String { name }
}

struct ProductCandidate: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var brand: String
    var productType: ProductType
    var barcode: String?
    var headline: String
    var ingredients: [Ingredient]
    var claims: [String]
    var tags: [IngredientTag]
    var alternativeIDs: [String]
    var notes: [String]
    var lookupTokens: [String]
}

struct LensScore: Codable, Hashable, Identifiable {
    var id: WellnessLensKind { lens }
    var lens: WellnessLensKind
    var score: Int
    var summary: String
}

struct ReasonItem: Codable, Hashable, Identifiable {
    enum Impact: String, Codable, Hashable {
        case positive
        case caution
        case neutral
    }

    var id = UUID()
    var title: String
    var detail: String
    var impact: Impact
}

struct AlternativeSuggestion: Codable, Hashable, Identifiable {
    var id: String
    var productName: String
    var productID: String
    var whyBetter: String
    var improvedLenses: [WellnessLensKind]
}

struct ScanAnalysis: Codable, Hashable, Identifiable {
    var id = UUID()
    var createdAt: Date
    var resolvedProduct: ProductCandidate
    var source: ScanSource
    var productType: ProductType
    var lensScores: [LensScore]
    var overallSummary: String
    var topReasons: [ReasonItem]
    var warnings: [String]
    var alternatives: [AlternativeSuggestion]
    var confidence: ConfidenceLevel
    var disclaimer: String
}

struct ScanRecord: Codable, Hashable, Identifiable {
    var id = UUID()
    var createdAt: Date
    var analysis: ScanAnalysis
    var isFavorite: Bool = false
}

struct CheckInEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var createdAt: Date
    var energy: Int
    var skin: Int
    var bloatingRelief: Int
    var cravingControl: Int
    var mood: Int
    var note: String
}

struct WeeklyInsight: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var summary: String
    var callToAction: String
}

struct ScoreDelta: Codable, Hashable, Identifiable {
    var id: WellnessLensKind { lens }
    var lens: WellnessLensKind
    var leftScore: Int
    var rightScore: Int

    var delta: Int {
        rightScore - leftScore
    }
}

struct ProductComparison: Codable, Hashable, Identifiable {
    var id = UUID()
    var left: ScanAnalysis
    var right: ScanAnalysis
    var deltas: [ScoreDelta]
}

enum SubscriptionStatus: String, Codable, CaseIterable {
    case free
    case plus
    case pro

    var title: String {
        switch self {
        case .free: "Free"
        case .plus: "Plus"
        case .pro: "Pro"
        }
    }
}

enum DemoScenarioPackKind: String, Codable, CaseIterable, Identifiable {
    case food
    case supplement
    case skincarePersonalCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: "Food & Drink"
        case .supplement: "Supplements"
        case .skincarePersonalCare: "Skincare & Personal Care"
        }
    }

    var subtitle: String {
        switch self {
        case .food: "Pantry reads for energy, gut calm, and hormone-friendly swaps."
        case .supplement: "Directional reads for capsules, gummies, and daily stacks."
        case .skincarePersonalCare: "Vanity scans for barrier support, glow, and sensitivity risk."
        }
    }

    var icon: String {
        switch self {
        case .food: "fork.knife"
        case .supplement: "pills.fill"
        case .skincarePersonalCare: "sparkles"
        }
    }
}

struct DemoScenario: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var scanInput: ScanInput
    var productType: ProductType
    var expectedHighlight: String
    var expectedLensBias: WellnessLensKind
}

struct DemoScenarioPack: Codable, Hashable, Identifiable {
    var kind: DemoScenarioPackKind
    var scenarios: [DemoScenario]

    var id: DemoScenarioPackKind { kind }
    var title: String { kind.title }
    var subtitle: String { kind.subtitle }
    var icon: String { kind.icon }
}

enum SampleCatalog {
    static let products: [ProductCandidate] = [
        ProductCandidate(
            id: "balanced-protein-yogurt",
            name: "Balanced Protein Yogurt",
            brand: "Glow Pantry",
            productType: .food,
            barcode: "850000001",
            headline: "High-protein, probiotic snack with steady energy support.",
            ingredients: ["Cultured milk", "Whey protein isolate", "Blueberries", "Chia fiber"].map(Ingredient.init),
            claims: ["15g protein", "Live cultures", "Low added sugar"],
            tags: [.proteinDense, .probiotic, .fiberSupport, .antioxidantBlend],
            alternativeIDs: ["gut-calm-oat-bar", "probiotic-complex-capsules"],
            notes: ["Works well for satiety and smoother energy."],
            lookupTokens: ["yogurt", "protein yogurt", "live cultures", "blueberry", "chia", "cultured milk"]
        ),
        ProductCandidate(
            id: "spark-rush-energy-drink",
            name: "Spark Rush Energy Drink",
            brand: "Rush Lab",
            productType: .food,
            barcode: "850000002",
            headline: "Fast buzz, but rougher on hormone and gut stability.",
            ingredients: ["Carbonated water", "Cane sugar", "Caffeine", "Natural flavors"].map(Ingredient.init),
            claims: ["Zero effort energy", "Fast focus"],
            tags: [.stimulant, .sugarSpike, .ultraProcessed],
            alternativeIDs: ["balanced-protein-yogurt", "gut-calm-oat-bar"],
            notes: ["Can trigger crashes and amplify jitter if caffeine-sensitive."],
            lookupTokens: ["energy drink", "caffeine", "spark rush", "cane sugar", "focus drink"]
        ),
        ProductCandidate(
            id: "gut-calm-oat-bar",
            name: "Gut Calm Oat Bar",
            brand: "Daily Ritual",
            productType: .food,
            barcode: "850000003",
            headline: "A balanced pantry swap with fiber-forward support.",
            ingredients: ["Oats", "Almond butter", "Flaxseed", "Cinnamon"].map(Ingredient.init),
            claims: ["5g fiber", "No sugar alcohols"],
            tags: [.fiberSupport, .antioxidantBlend],
            alternativeIDs: ["balanced-protein-yogurt"],
            notes: ["A good mid-afternoon swap when bloating is a concern."],
            lookupTokens: ["oat bar", "flaxseed", "almond butter", "daily ritual"]
        ),
        ProductCandidate(
            id: "collagen-complex-gummies",
            name: "Collagen Complex Gummies",
            brand: "Beauty Within",
            productType: .supplement,
            barcode: "850000004",
            headline: "Helpful for beauty goals, but sugar load softens the fit.",
            ingredients: ["Collagen peptides", "Cane sugar", "Citrus flavor", "Biotin"].map(Ingredient.init),
            claims: ["Hair + skin support", "Biotin blend"],
            tags: [.collagen, .sugarSpike],
            alternativeIDs: ["probiotic-complex-capsules"],
            notes: ["Better used occasionally than as a daily candy-like routine."],
            lookupTokens: ["collagen gummies", "biotin", "beauty within", "citrus flavor"]
        ),
        ProductCandidate(
            id: "probiotic-complex-capsules",
            name: "Probiotic Complex Capsules",
            brand: "Inner Balance",
            productType: .supplement,
            barcode: "850000005",
            headline: "A cleaner supplement profile for gut calm and steadier routines.",
            ingredients: ["Lactobacillus blend", "Bifidobacterium blend", "Vegetable capsule"].map(Ingredient.init),
            claims: ["Digestive support", "No added sweeteners"],
            tags: [.probiotic, .fiberSupport],
            alternativeIDs: ["balanced-protein-yogurt"],
            notes: ["Pairs well with food-first routines."],
            lookupTokens: ["probiotic", "capsules", "digestive support", "lactobacillus", "bifidobacterium"]
        ),
        ProductCandidate(
            id: "barrier-support-serum",
            name: "Barrier Support Serum",
            brand: "Studio Skin",
            productType: .skincare,
            barcode: "850000006",
            headline: "Strong glow support with low-irritation ingredients.",
            ingredients: ["Niacinamide", "Peptides", "Hyaluronic acid", "Panthenol"].map(Ingredient.init),
            claims: ["Barrier support", "Hydration", "Glow"],
            tags: [.niacinamide, .peptide, .hyaluronicAcid],
            alternativeIDs: ["mineral-shield-spf", "gentle-cloud-cleanser"],
            notes: ["Great anchor product for sensitivity-aware routines."],
            lookupTokens: ["serum", "niacinamide", "peptides", "hyaluronic", "barrier support"]
        ),
        ProductCandidate(
            id: "gentle-cloud-cleanser",
            name: "Gentle Cloud Cleanser",
            brand: "Quiet Ritual",
            productType: .personalCare,
            barcode: "850000007",
            headline: "A softer cleanse that stays compatible with reactive skin.",
            ingredients: ["Glycerin", "Coco glucoside", "Panthenol", "Oat extract"].map(Ingredient.init),
            claims: ["Fragrance-free", "Gentle cleanse"],
            tags: [.fiberSupport],
            alternativeIDs: ["barrier-support-serum"],
            notes: ["Good replacement when stripping cleansers show up in the routine."],
            lookupTokens: ["cleanser", "fragrance-free", "glycerin", "oat extract", "gentle cloud"]
        ),
        ProductCandidate(
            id: "fragrance-burst-cleanser",
            name: "Fragrance Burst Cleanser",
            brand: "Glow Splash",
            productType: .personalCare,
            barcode: "850000008",
            headline: "Looks luxe, but can conflict with sensitivity and barrier goals.",
            ingredients: ["Sodium laureth sulfate", "Fragrance", "Alcohol denat", "Colorants"].map(Ingredient.init),
            claims: ["Fresh-scented", "Deep clean"],
            tags: [.fragrance, .alcoholDrying, .harshSurfactants],
            alternativeIDs: ["gentle-cloud-cleanser", "barrier-support-serum"],
            notes: ["Higher irritation risk for dry or acne-prone users."],
            lookupTokens: ["fragrance", "deep clean", "alcohol denat", "sodium laureth sulfate", "glow splash"]
        ),
        ProductCandidate(
            id: "mineral-shield-spf",
            name: "Mineral Shield SPF 40",
            brand: "Daylight Theory",
            productType: .skincare,
            barcode: "850000009",
            headline: "A strong daytime swap for glow and barrier consistency.",
            ingredients: ["Zinc oxide", "Squalane", "Green tea extract", "Glycerin"].map(Ingredient.init),
            claims: ["Mineral SPF", "Barrier-friendly"],
            tags: [.mineralSPF, .antioxidantBlend, .hyaluronicAcid],
            alternativeIDs: ["barrier-support-serum"],
            notes: ["Helps support glow while protecting the skin barrier."],
            lookupTokens: ["spf", "mineral shield", "zinc oxide", "green tea extract"]
        )
    ]
}

enum DemoScenarioCatalog {
    static let packs: [DemoScenarioPack] = [
        DemoScenarioPack(
            kind: .food,
            scenarios: [
                DemoScenario(
                    id: "food-balanced-breakfast",
                    title: "Steady breakfast read",
                    subtitle: "Run a clean pantry scan on a protein + probiotic snack.",
                    scanInput: ScanInput(
                        sourceType: .manualBarcode,
                        barcode: "850000001",
                        capturedImageRef: nil,
                        rawText: nil,
                        productTypeHint: .food,
                        locale: "en_US"
                    ),
                    productType: .food,
                    expectedHighlight: "Strong satiety and smoother energy support.",
                    expectedLensBias: .energyMood
                ),
                DemoScenario(
                    id: "food-energy-drink-crash",
                    title: "Energy drink reality check",
                    subtitle: "See how sugar and caffeine pressure the calmer lenses.",
                    scanInput: ScanInput(
                        sourceType: .manualBarcode,
                        barcode: "850000002",
                        capturedImageRef: nil,
                        rawText: nil,
                        productTypeHint: .food,
                        locale: "en_US"
                    ),
                    productType: .food,
                    expectedHighlight: "Fast buzz, but a rougher fit for hormones and gut comfort.",
                    expectedLensBias: .hormoneBalance
                ),
                DemoScenario(
                    id: "food-oat-bar-label",
                    title: "Fiber-forward label fallback",
                    subtitle: "Use text-only analysis to simulate a clean ingredient label.",
                    scanInput: ScanInput(
                        sourceType: .manualLabel,
                        barcode: nil,
                        capturedImageRef: nil,
                        rawText: "oats, almond butter, flaxseed, cinnamon",
                        productTypeHint: .food,
                        locale: "en_US"
                    ),
                    productType: .food,
                    expectedHighlight: "Fiber-forward support for calmer digestion and steadier afternoons.",
                    expectedLensBias: .gutComfort
                )
            ]
        ),
        DemoScenarioPack(
            kind: .supplement,
            scenarios: [
                DemoScenario(
                    id: "supplement-collagen-gummies",
                    title: "Beauty gummies check",
                    subtitle: "A glow-facing supplement with a softer daily fit.",
                    scanInput: ScanInput(
                        sourceType: .manualBarcode,
                        barcode: "850000004",
                        capturedImageRef: nil,
                        rawText: nil,
                        productTypeHint: .supplement,
                        locale: "en_US"
                    ),
                    productType: .supplement,
                    expectedHighlight: "Beauty support is present, but sugar load weakens the read.",
                    expectedLensBias: .glowSkin
                ),
                DemoScenario(
                    id: "supplement-probiotic-capsules",
                    title: "Calmer gut stack",
                    subtitle: "A cleaner capsule profile for digestion-aware routines.",
                    scanInput: ScanInput(
                        sourceType: .manualBarcode,
                        barcode: "850000005",
                        capturedImageRef: nil,
                        rawText: nil,
                        productTypeHint: .supplement,
                        locale: "en_US"
                    ),
                    productType: .supplement,
                    expectedHighlight: "Clean capsule profile that reinforces gut calm.",
                    expectedLensBias: .gutComfort
                ),
                DemoScenario(
                    id: "supplement-probiotic-label",
                    title: "Capsule label fallback",
                    subtitle: "Simulate an OCR-assisted supplement read with ingredient text only.",
                    scanInput: ScanInput(
                        sourceType: .manualLabel,
                        barcode: nil,
                        capturedImageRef: nil,
                        rawText: "lactobacillus blend, bifidobacterium blend, vegetable capsule",
                        productTypeHint: .supplement,
                        locale: "en_US"
                    ),
                    productType: .supplement,
                    expectedHighlight: "A clean fallback flow that still lands on gut support.",
                    expectedLensBias: .gutComfort
                )
            ]
        ),
        DemoScenarioPack(
            kind: .skincarePersonalCare,
            scenarios: [
                DemoScenario(
                    id: "topical-barrier-serum",
                    title: "Barrier serum glow read",
                    subtitle: "A premium topical scan with high barrier alignment.",
                    scanInput: ScanInput(
                        sourceType: .manualBarcode,
                        barcode: "850000006",
                        capturedImageRef: nil,
                        rawText: nil,
                        productTypeHint: .skincare,
                        locale: "en_US"
                    ),
                    productType: .skincare,
                    expectedHighlight: "Strong glow support with low-irritation ingredients.",
                    expectedLensBias: .glowSkin
                ),
                DemoScenario(
                    id: "topical-fragrance-cleanser",
                    title: "Fragrance friction check",
                    subtitle: "A personal care scan that shows barrier and sensitivity risk clearly.",
                    scanInput: ScanInput(
                        sourceType: .manualBarcode,
                        barcode: "850000008",
                        capturedImageRef: nil,
                        rawText: nil,
                        productTypeHint: .personalCare,
                        locale: "en_US"
                    ),
                    productType: .personalCare,
                    expectedHighlight: "High fragrance and surfactant friction for reactive skin.",
                    expectedLensBias: .glowSkin
                ),
                DemoScenario(
                    id: "topical-serum-label",
                    title: "Actives-only label read",
                    subtitle: "Simulate an OCR label flow for a glow-facing serum.",
                    scanInput: ScanInput(
                        sourceType: .manualLabel,
                        barcode: nil,
                        capturedImageRef: nil,
                        rawText: "niacinamide, peptides, hyaluronic acid, panthenol",
                        productTypeHint: .skincare,
                        locale: "en_US"
                    ),
                    productType: .skincare,
                    expectedHighlight: "OCR-style fallback still lands on the barrier-support story.",
                    expectedLensBias: .glowSkin
                )
            ]
        )
    ]

    static var featured: [DemoScenario] {
        packs.flatMap(\.scenarios)
    }

    static func scenario(id: String?) -> DemoScenario? {
        guard let id else { return nil }
        return featured.first(where: { $0.id == id })
    }
}

struct AnalysisEngine {
    private let baseScore = 60

    func analyze(
        product: ProductCandidate,
        userContext: UserContext,
        source: ScanSource,
        confidence: ConfidenceLevel,
        catalog: [ProductCandidate]
    ) -> ScanAnalysis {
        let lensScores = WellnessLensKind.allCases.map { lens in
            score(for: lens, product: product, userContext: userContext)
        }
        let overallSummary = buildOverallSummary(product: product, lensScores: lensScores)
        let topReasons = collectTopReasons(from: lensScores, product: product, userContext: userContext)
        let warnings = buildWarnings(product: product, userContext: userContext, confidence: confidence)
        let alternatives = buildAlternatives(for: product, userContext: userContext, currentScores: lensScores, catalog: catalog)

        return ScanAnalysis(
            createdAt: .now,
            resolvedProduct: product,
            source: source,
            productType: product.productType,
            lensScores: lensScores,
            overallSummary: overallSummary,
            topReasons: topReasons,
            warnings: warnings,
            alternatives: alternatives,
            confidence: confidence,
            disclaimer: "WellnessLens offers consumer wellness guidance only. It does not diagnose, treat, or replace medical advice."
        )
    }

    func compare(_ left: ScanAnalysis, _ right: ScanAnalysis) -> ProductComparison {
        let deltas = WellnessLensKind.allCases.map { lens in
            let leftScore = left.lensScores.first(where: { $0.lens == lens })?.score ?? 0
            let rightScore = right.lensScores.first(where: { $0.lens == lens })?.score ?? 0
            return ScoreDelta(lens: lens, leftScore: leftScore, rightScore: rightScore)
        }
        return ProductComparison(left: left, right: right, deltas: deltas)
    }

    private func score(for lens: WellnessLensKind, product: ProductCandidate, userContext: UserContext) -> LensScore {
        var score = baseScore
        var positiveHits = 0
        var cautionHits = 0

        for tag in product.tags {
            let delta = adjustment(for: tag, lens: lens)
            score += delta
            if delta > 0 { positiveHits += 1 }
            if delta < 0 { cautionHits += 1 }
        }

        score += userContextAdjustment(for: lens, product: product, userContext: userContext)
        score = min(95, max(15, score))

        let summary: String
        switch score {
        case 80...95:
            summary = "Strong fit"
        case 65...79:
            summary = "Solid fit"
        case 50...64:
            summary = "Mixed fit"
        default:
            summary = cautionHits > positiveHits ? "Friction likely" : "Needs context"
        }

        return LensScore(lens: lens, score: score, summary: summary)
    }

    private func adjustment(for tag: IngredientTag, lens: WellnessLensKind) -> Int {
        switch (tag, lens) {
        case (.proteinDense, .energyMood): 8
        case (.proteinDense, .bodyCompositionStrength): 12
        case (.proteinDense, .hormoneBalance): 6
        case (.probiotic, .gutComfort): 12
        case (.probiotic, .energyMood): 3
        case (.fiberSupport, .gutComfort): 10
        case (.fiberSupport, .energyMood): 6
        case (.fiberSupport, .hormoneBalance): 8
        case (.fiberSupport, .bodyCompositionStrength): 5
        case (.sugarSpike, .energyMood): -10
        case (.sugarSpike, .hormoneBalance): -10
        case (.sugarSpike, .glowSkin): -8
        case (.sugarSpike, .bodyCompositionStrength): -6
        case (.sugarAlcohol, .gutComfort): -10
        case (.stimulant, .energyMood): -7
        case (.stimulant, .hormoneBalance): -6
        case (.ultraProcessed, .hormoneBalance): -8
        case (.ultraProcessed, .gutComfort): -6
        case (.ultraProcessed, .energyMood): -6
        case (.ultraProcessed, .glowSkin): -6
        case (.collagen, .glowSkin): 6
        case (.collagen, .bodyCompositionStrength): 5
        case (.omegaSupport, .hormoneBalance): 8
        case (.omegaSupport, .glowSkin): 4
        case (.niacinamide, .glowSkin): 12
        case (.peptide, .glowSkin): 8
        case (.hyaluronicAcid, .glowSkin): 10
        case (.retinoid, .glowSkin): 12
        case (.fragrance, .glowSkin): -12
        case (.alcoholDrying, .glowSkin): -7
        case (.harshSurfactants, .glowSkin): -8
        case (.mineralSPF, .glowSkin): 10
        case (.antioxidantBlend, .glowSkin): 10
        case (.antioxidantBlend, .energyMood): 4
        case (.emulsifierHeavy, .gutComfort): -7
        default: 0
        }
    }

    private func userContextAdjustment(for lens: WellnessLensKind, product: ProductCandidate, userContext: UserContext) -> Int {
        var adjustment = 0

        for goal in userContext.goals {
            switch (goal, lens) {
            case (.clearSkin, .glowSkin) where product.tags.contains(.niacinamide) || product.tags.contains(.retinoid):
                adjustment += 6
            case (.steadyEnergy, .energyMood) where product.tags.contains(.proteinDense) || product.tags.contains(.fiberSupport):
                adjustment += 5
            case (.steadyEnergy, .energyMood) where product.tags.contains(.sugarSpike):
                adjustment -= 4
            case (.gutCalm, .gutComfort) where product.tags.contains(.probiotic) || product.tags.contains(.fiberSupport):
                adjustment += 6
            case (.deBloat, .gutComfort) where product.tags.contains(.sugarAlcohol):
                adjustment -= 5
            case (.hormoneSupport, .hormoneBalance) where product.tags.contains(.fiberSupport) || product.tags.contains(.omegaSupport):
                adjustment += 5
            case (.leanStrength, .bodyCompositionStrength) where product.tags.contains(.proteinDense):
                adjustment += 6
            default:
                break
            }
        }

        for sensitivity in userContext.sensitivities {
            switch sensitivity {
            case .fragranceSensitive where lens == .glowSkin && product.tags.contains(.fragrance):
                adjustment -= 8
            case .caffeineSensitive where lens == .energyMood && product.tags.contains(.stimulant):
                adjustment -= 6
            case .sugarSensitive where (lens == .energyMood || lens == .hormoneBalance) && product.tags.contains(.sugarSpike):
                adjustment -= 6
            case .acneProne where lens == .glowSkin && (product.tags.contains(.sugarSpike) || product.tags.contains(.fragrance)):
                adjustment -= 5
            case .drySkin where lens == .glowSkin && product.tags.contains(.alcoholDrying):
                adjustment -= 5
            case .reactiveDigestion where lens == .gutComfort && (product.tags.contains(.sugarAlcohol) || product.tags.contains(.emulsifierHeavy)):
                adjustment -= 6
            default:
                break
            }
        }

        if userContext.lifeStage == .highStress && lens == .energyMood && product.tags.contains(.stimulant) {
            adjustment -= 4
        }

        return adjustment
    }

    private func collectTopReasons(from lensScores: [LensScore], product: ProductCandidate, userContext: UserContext) -> [ReasonItem] {
        var reasons: [ReasonItem] = []

        if product.tags.contains(.proteinDense) {
            reasons.append(ReasonItem(title: "Protein support", detail: "This product supports steadier energy and stronger satiety.", impact: .positive))
        }
        if product.tags.contains(.probiotic) {
            reasons.append(ReasonItem(title: "Gut-friendly signal", detail: "Live cultures or probiotic support can help a calmer digestion profile.", impact: .positive))
        }
        if product.tags.contains(.niacinamide) || product.tags.contains(.peptide) || product.tags.contains(.hyaluronicAcid) {
            reasons.append(ReasonItem(title: "Barrier and glow support", detail: "The topical actives here line up well with glow and barrier goals.", impact: .positive))
        }
        if product.tags.contains(.sugarSpike) {
            reasons.append(ReasonItem(title: "Sugar spike risk", detail: "A sharper sugar load can work against stable energy, calm skin, or hormone-friendly routines.", impact: .caution))
        }
        if product.tags.contains(.fragrance) || product.tags.contains(.alcoholDrying) || product.tags.contains(.harshSurfactants) {
            reasons.append(ReasonItem(title: "Barrier friction", detail: "This formula carries a higher chance of irritation for reactive or dry skin.", impact: .caution))
        }
        if userContext.sensitivities.contains(.fragranceSensitive) && product.tags.contains(.fragrance) {
            reasons.append(ReasonItem(title: "Sensitivity mismatch", detail: "Your profile flags fragrance sensitivity, so this product deserves extra caution.", impact: .caution))
        }

        if reasons.isEmpty, let strongest = lensScores.max(by: { $0.score < $1.score }) {
            reasons.append(ReasonItem(title: "Balanced fit", detail: "This product looks most aligned with your \(strongest.lens.title.lowercased()) goals.", impact: .neutral))
        }

        return Array(reasons.prefix(4))
    }

    private func buildOverallSummary(product: ProductCandidate, lensScores: [LensScore]) -> String {
        let topLens = lensScores.max(by: { $0.score < $1.score })?.lens.title ?? "your daily goals"
        let weakLens = lensScores.min(by: { $0.score < $1.score })?.lens.title ?? "context"
        return "\(product.name) looks strongest for \(topLens.lowercased()), with the most caution around \(weakLens.lowercased())."
    }

    private func buildWarnings(product: ProductCandidate, userContext: UserContext, confidence: ConfidenceLevel) -> [String] {
        var warnings: [String] = []
        if confidence == .low {
            warnings.append("We resolved this scan with limited certainty. Double-check the ingredient list before acting on it.")
        }
        if product.tags.contains(.stimulant) && userContext.sensitivities.contains(.caffeineSensitive) {
            warnings.append("You marked caffeine sensitivity, so this scan may feel rougher than the score alone suggests.")
        }
        if product.tags.contains(.fragrance) && userContext.sensitivities.contains(.fragranceSensitive) {
            warnings.append("Fragrance can be a major irritant for your current profile.")
        }
        return warnings
    }

    private func buildAlternatives(
        for product: ProductCandidate,
        userContext: UserContext,
        currentScores: [LensScore],
        catalog: [ProductCandidate]
    ) -> [AlternativeSuggestion] {
        let currentMap = Dictionary(uniqueKeysWithValues: currentScores.map { ($0.lens, $0.score) })

        return product.alternativeIDs.compactMap { id -> AlternativeSuggestion? in
            guard let alternative = catalog.first(where: { $0.id == id }) else { return nil }
            let altScores = WellnessLensKind.allCases.map { score(for: $0, product: alternative, userContext: userContext) }
            let improvedLenses = altScores.compactMap { alternativeScore -> WellnessLensKind? in
                guard let currentScore = currentMap[alternativeScore.lens] else { return nil }
                return alternativeScore.score >= currentScore + 8 ? alternativeScore.lens : nil
            }
            guard !improvedLenses.isEmpty else { return nil }
            let reasons = improvedLenses.map { $0.title.lowercased() }.joined(separator: ", ")
            return AlternativeSuggestion(
                id: "\(product.id)-\(alternative.id)",
                productName: alternative.name,
                productID: alternative.id,
                whyBetter: "A cleaner swap for \(reasons).",
                improvedLenses: improvedLenses
            )
        }
    }
}

struct WeeklyInsightEngine {
    func generate(history: [ScanRecord], checkIns: [CheckInEntry], now: Date = .now) -> [WeeklyInsight] {
        let calendar = Calendar.current
        let recentHistory = history.filter { calendar.dateComponents([.day], from: $0.createdAt, to: now).day ?? 99 < 7 }
        let recentCheckIns = checkIns.filter { calendar.dateComponents([.day], from: $0.createdAt, to: now).day ?? 99 < 7 }

        guard !recentHistory.isEmpty else {
            return [
                WeeklyInsight(
                    title: "Start with a few scans",
                    summary: "Your weekly inside-out story appears once you build a little pantry + vanity history.",
                    callToAction: "Scan three products you use this week."
                )
            ]
        }

        let allLensScores = Dictionary(grouping: recentHistory.flatMap(\.analysis.lensScores), by: \.lens)
        let averageByLens = allLensScores.mapValues { scores in
            Int(scores.map(\.score).average.rounded())
        }

        let strongestLens = averageByLens.max(by: { $0.value < $1.value })
        let weakestLens = averageByLens.min(by: { $0.value < $1.value })

        var insights: [WeeklyInsight] = []

        if let strongestLens {
            insights.append(
                WeeklyInsight(
                    title: "\(strongestLens.key.title) is trending well",
                    summary: "Your recent scans average \(strongestLens.value), which suggests your current choices are lining up here.",
                    callToAction: "Keep anchoring routines around the products that scored well in this lens."
                )
            )
        }

        if let weakestLens, weakestLens.value < 58 {
            insights.append(
                WeeklyInsight(
                    title: "Watch your \(weakestLens.key.title.lowercased()) lens",
                    summary: "This was the softest area in the last week, so a couple of deliberate swaps could move the needle fast.",
                    callToAction: "Use the compare flow on your lowest-scoring recent products."
                )
            )
        }

        if !recentCheckIns.isEmpty {
            let averageEnergy = recentCheckIns.map(\.energy).average
            let averageBloatingRelief = recentCheckIns.map(\.bloatingRelief).average

            if averageEnergy < 3.2 {
                insights.append(
                    WeeklyInsight(
                        title: "Energy looks uneven",
                        summary: "Your check-ins suggest inconsistent energy this week. Double-check stimulant-heavy scans against your routine.",
                        callToAction: "Compare any caffeine-forward products with higher protein or fiber swaps."
                    )
                )
            }

            if averageBloatingRelief < 3.0 {
                insights.append(
                    WeeklyInsight(
                        title: "Gut calm needs protection",
                        summary: "Bloating relief scores were softer this week. Sugar alcohols or ultra-processed snacks may be part of the pattern.",
                        callToAction: "Favor products with fiber support or probiotic signals in the next few days."
                    )
                )
            }
        }

        return Array(insights.prefix(3))
    }
}

extension Array where Element == Double {
    fileprivate var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

extension Array where Element == Int {
    fileprivate var average: Double {
        guard !isEmpty else { return 0 }
        return Double(reduce(0, +)) / Double(count)
    }
}
