import Foundation

struct StoredScanVerdict: Codable, Hashable, Identifiable {
    var id: String { scanEventID }
    var scanEventID: String
    var verdict: LILADomain.ScanVerdict
    var createdAt: Date

    init(scanEventID: String, verdict: LILADomain.ScanVerdict, createdAt: Date? = nil) {
        self.scanEventID = scanEventID
        self.verdict = verdict
        self.createdAt = createdAt ?? verdict.createdAt
    }
}

extension UserProfile {
    func lilaContext(biometrics: BiometricsSnapshot? = nil) -> LILADomain.UserContext {
        var goals: [LILADomain.WellnessGoal] = userContext.goals.compactMap(\.lilaGoal)
        if goals.isEmpty {
            goals = nutritionPriorities.compactMap(\.fallbackLILAGoal)
        }

        var sensitivities = Set(userContext.sensitivities.compactMap(\.lilaSensitivity))
        if frictions.contains(.reactiveSkin) {
            sensitivities.insert(.reactiveSkin)
        }
        if frictions.contains(.bloating) {
            sensitivities.insert(.bloatingProne)
        }

        let baseContext = LILADomain.UserContext(
            identity: LILADomain.Identity(
                age: ageRange.typicalAge,
                displayName: nil,
                heightCm: nil,
                weightKg: nil,
                locale: Locale.current.identifier,
                timeZoneIdentifier: TimeZone.current.identifier
            ),
            biology: userContext.lifeStage.lilaBiology(optedIntoCycle: userContext.optInCycleAware),
            fitness: userContext.goals.lilaFitnessProfile(),
            conditions: [],
            sensitivities: sensitivities,
            allergies: [],
            dietStyle: userContext.dietStyle.lilaDietStyle,
            goals: LILADomain.PrioritizedGoals(
                primary: Array(goals.prefix(3)),
                secondary: Array(goals.dropFirst(3).prefix(3)),
                emotionalAnchor: frictions.first?.strategistSummary
            ),
            cooking: LILADomain.CookingContext(
                homeCookingFrequency: restaurantFrequency.lilaCookingFrequency,
                typicalMealContext: restaurantFrequency.lilaMealContexts,
                budgetTier: .moderate,
                cuisinePreferences: []
            ),
            dataSync: LILADomain.DataSyncPreferences(
                healthKitEnabled: consentFlags.healthDataProcessing,
                cycleTrackingOptIn: userContext.optInCycleAware,
                workoutsOptIn: consentFlags.healthDataProcessing,
                hrvAndRecoveryOptIn: consentFlags.healthDataProcessing,
                sleepOptIn: consentFlags.healthDataProcessing,
                nutritionWriteBackOptIn: false,
                analyticsOptIn: consentFlags.analytics,
                cloudSyncEnabled: false
            ),
            personalNote: frictions.first?.strategistSummary,
            lastUpdated: .now
        )

        return baseContext.applying(biometrics: biometrics)
    }

    func scanContext(biometrics: BiometricsSnapshot? = nil) -> ScanContext? {
        let phase = lilaContext(biometrics: biometrics).biology.currentPhase.flatMap { phase -> ScanCyclePhase? in
            switch phase {
            case .menstrual:
                .menstrual
            case .follicular:
                .follicular
            case .ovulatory:
                .ovulatory
            case .luteal:
                .luteal
            }
        }

        let normalized = ScanContext(
            cyclePhase: phase,
            isInAnabolicWindow: biometrics?.trainingLoad?.isInAnabolicWindow,
            sleepHours: biometrics?.sleepHours,
            hrvMilliseconds: biometrics?.hrvMilliseconds,
            restingHeartRate: biometrics?.restingHeartRate,
            wristTemperatureDeltaCelsius: biometrics?.wristTemperatureDeltaCelsius
        )

        return normalized.isEmpty ? nil : normalized
    }
}

extension UserContext {
    func lilaContext(
        ageRange: AgeRange = .thirties,
        restaurantFrequency: RestaurantFrequency = .balanced,
        consentFlags: ConsentFlags = .starter,
        biometrics: BiometricsSnapshot? = nil
    ) -> LILADomain.UserContext {
        UserProfile(
            userContext: self,
            frictions: [],
            guidanceStyle: .calmAndDirect,
            eatingRhythm: .flexible,
            supplementStyle: .simple,
            memoryEnabled: true,
            ageRange: ageRange,
            restaurantFrequency: restaurantFrequency,
            nutritionPriorities: [],
            consentFlags: consentFlags,
            createdAt: .now
        ).lilaContext(biometrics: biometrics)
    }
}

extension ScanAnalysis {
    func lilaVerdict(
        context: LILADomain.UserContext,
        biometrics: BiometricsSnapshot? = nil,
        scanContext: ScanContext? = nil
    ) -> LILADomain.ScanVerdict {
        let dominantLens = lensScores.max(by: { $0.score < $1.score })?.lens.lilaLens ?? .energyAndMood
        let score = Int(Double(lensScores.map(\.score).reduce(0, +)) / Double(max(lensScores.count, 1)))
        let fit = score.lilaFitLevel
        let contextFactors = makeContextFactors(context: context, biometrics: biometrics, scanContext: scanContext)
        let personalizedLensScores = lensScores.map {
            LILADomain.LensScore(
                lens: $0.lens.lilaLens,
                score: $0.score,
                trend: $0.score >= 80 ? .rising : ($0.score < 60 ? .falling : .neutral),
                summary: $0.summary,
                contextApplied: contextFactors[$0.lens.lilaLens, default: []]
            )
        }
        let watchouts = Array(warnings.prefix(2)).map {
            LILADomain.Watchout(
                title: $0,
                detail: topReasons.first(where: { $0.impact == .caution })?.detail ?? overallSummary,
                severity: confidence == .low ? .important : .moderate,
                personalRelevance: context.requiresGuardrails ? .clinical : .personal
            )
        }
        let alternative = alternatives.first.map {
            LILADomain.Alternative(
                productName: $0.productName,
                productID: $0.productID,
                brand: nil,
                whyBetter: $0.whyBetter,
                improvedLenses: $0.improvedLenses.map(\.lilaLens),
                expectedLensDeltas: $0.improvedLenses.map { .init(lens: $0.lilaLens, estimatedChange: 8) }
            )
        }

        let deterministicFactors = Array(topReasons.prefix(3)).map {
            LILADomain.DeterministicFactor(
                rule: "\($0.title): \($0.detail)",
                delta: $0.impact.lilaDelta,
                affectedLens: dominantLens
            )
        }

        return LILADomain.ScanVerdict(
            createdAt: createdAt,
            resolvedProduct: resolvedProduct.lilaResolvedProduct(),
            scanSource: source.lilaScanSource,
            fit: fit,
            confidence: confidence.lilaConfidence,
            headline: fit.headline(productName: resolvedProduct.name, context: context),
            primaryReason: topReasons.first?.detail ?? overallSummary,
            lensScores: personalizedLensScores,
            watchouts: watchouts,
            betterSwap: alternative,
            trackPrompt: LILADomain.FollowUpPrompt(
                triggerAfterHours: hasAnabolicWindowContext(biometrics: biometrics, scanContext: scanContext) ? 2 : 3,
                questionText: source.followUpPrompt,
                targetLens: dominantLens,
                expectedResponseType: .openText
            ),
            evidenceTier: confidence == .high ? .high : .emerging,
            reasoningBreakdown: LILADomain.ReasoningBreakdown(
                deterministicFactors: deterministicFactors,
                agentInsights: [],
                userHistoryFactors: [],
                totalAdjustments: deterministicFactors.reduce(0, { $0 + $1.delta })
            ),
            disclaimer: disclaimer,
            sources: [
                LILADomain.EvidenceSource(
                    title: "Legacy deterministic scoring engine",
                    organization: "WellnessLens",
                    tier: confidence == .high ? .high : .emerging
                )
            ]
        )
    }
}

extension AnalysisEnvelope {
    func lilaVerdict(
        fallbackAnalysis: ScanAnalysis?,
        context: LILADomain.UserContext,
        biometrics: BiometricsSnapshot? = nil,
        scanContext: ScanContext? = nil
    ) -> LILADomain.ScanVerdict {
        let fallbackProduct = resolvedProduct?.lilaResolvedProduct()
            ?? fallbackAnalysis?.resolvedProduct.lilaResolvedProduct()
            ?? LILADomain.ResolvedProduct(
                id: analysisID,
                canonicalProductID: nil,
                name: entityType == .supplement ? "Supplement scan" : "Structured scan",
                brand: nil,
                category: entityType.lilaProductCategory,
                barcode: nil,
                ingredients: [],
                nutrition: nil,
                skincare: nil,
                resolutionSource: .agentInferred,
                headline: whyToday.first,
                imageURL: nil
            )
        let dominantLens = lensScores.dominantLILALens
        let contextFactors = makeContextFactors(context: context, biometrics: biometrics, scanContext: scanContext)
        let verdict = LILADomain.ScanVerdict(
            createdAt: timestamp,
            resolvedProduct: fallbackProduct,
            scanSource: inputType.lilaScanSource,
            fit: verdict.lilaFitLevel,
            confidence: confidence.lilaConfidence,
            headline: verdict.lilaFitLevel.headline(productName: fallbackProduct.name, context: context),
            primaryReason: whyToday.first ?? recommendedActions.first ?? "Directional guidance based on the current scan.",
            lensScores: lensScores.lilaLensScores(contextFactors: contextFactors),
            watchouts: Array(redFlags.prefix(2)).map {
                LILADomain.Watchout(
                    title: $0,
                    detail: redFlags.joined(separator: " "),
                    severity: medicalSafety.riskLevel.lilaSeverity,
                    personalRelevance: medicalSafety.riskLevel == .high ? .clinical : .personal
                )
            },
            betterSwap: swapSuggestions.first.map {
                LILADomain.Alternative(
                    productName: $0.title,
                    whyBetter: $0.reason,
                    improvedLenses: dominantLens.map { [$0] } ?? [],
                    expectedLensDeltas: dominantLens.map { [.init(lens: $0, estimatedChange: $0 == dominantLens ? 6 : 4)] } ?? []
                )
            },
            trackPrompt: followUpPrompt.isEmpty ? nil : LILADomain.FollowUpPrompt(
                triggerAfterHours: hasAnabolicWindowContext(biometrics: biometrics, scanContext: scanContext) ? 2 : 3,
                questionText: followUpPrompt,
                targetLens: dominantLens ?? .energyAndMood,
                expectedResponseType: .openText
            ),
            evidenceTier: patternContext.usedHistory ? .personalPattern : (confidence >= 0.8 ? .high : .emerging),
            reasoningBreakdown: LILADomain.ReasoningBreakdown(
                deterministicFactors: (greenFlags.map { ($0, 4) } + redFlags.map { ($0, -4) }).map {
                    LILADomain.DeterministicFactor(rule: $0.0, delta: $0.1, affectedLens: dominantLens ?? .energyAndMood)
                },
                agentInsights: [
                    .init(
                        insight: whyToday.first ?? "Structured explanation available.",
                        modelUsed: "AnalysisEnvelope",
                        confidenceScore: confidence
                    )
                ],
                userHistoryFactors: patternContext.usedHistory && patternContext.relevantPattern != nil
                    ? [.init(pattern: patternContext.relevantPattern ?? "", scansReferenced: 1)]
                    : [],
                totalAdjustments: (greenFlags.count * 4) - (redFlags.count * 4)
            ),
            disclaimer: medicalSafety.disclaimerNeeded
                ? "This is wellness guidance, not medical diagnosis or treatment advice."
                : "Directional wellness guidance only.",
            sources: [
                LILADomain.EvidenceSource(
                    title: "Structured scan analysis",
                    organization: "WellnessLens",
                    tier: patternContext.usedHistory ? .personalPattern : .emerging
                )
            ]
        )

        return fallbackAnalysis.map { _ in verdict } ?? verdict
    }
}

extension LILADomain.ScanVerdict {
    func analysisEnvelope() -> AnalysisEnvelope {
        let structuredScores = StructuredLensScores(
            skin: lensScore(for: .glowAndSkin),
            hormones: lensScore(for: .hormoneBalance),
            gut: lensScore(for: .gutComfort),
            energy: lensScore(for: .energyAndMood),
            bodyComp: lensScore(for: .bodyCompositionAndStrength)
        )
        let redFlags = watchouts.map(\.title)
        let greenFlags = reasoningBreakdown.deterministicFactors
            .filter { $0.delta > 0 }
            .map(\.rule)
        let recommendedActions = [betterSwap.map { "Try \($0.productName)." }, trackPrompt?.questionText]
            .compactMap { $0 }

        return AnalysisEnvelope(
            analysisID: id.uuidString,
            timestamp: createdAt,
            inputType: scanSource.analysisInputType,
            entityType: resolvedProduct.category.analysisEntityType,
            verdict: fit.analysisVerdict,
            overallScore: overallScore,
            lensScores: structuredScores,
            whyToday: [headline, primaryReason].filter { !$0.isEmpty },
            greenFlags: Array(greenFlags.prefix(4)),
            redFlags: Array(redFlags.prefix(4)),
            recommendedActions: Array(recommendedActions.prefix(4)),
            swapSuggestions: betterSwap.map {
                [SwapSuggestion(title: $0.productName, reason: $0.whyBetter, priority: .high)]
            } ?? [],
            followUpPrompt: trackPrompt?.questionText ?? "Did this feel supportive a few hours later?",
            confidence: confidence.numericValue,
            medicalSafety: MedicalSafety(
                isMedicalAdvice: false,
                disclaimerNeeded: true,
                riskLevel: watchouts.contains(where: { $0.personalRelevance == .clinical }) ? .high : (watchouts.isEmpty ? .low : .medium)
            ),
            patternContext: PatternContext(
                usedHistory: !reasoningBreakdown.userHistoryFactors.isEmpty,
                relevantPattern: reasoningBreakdown.userHistoryFactors.first?.pattern
            )
        )
    }

    var overallScore: Int {
        let scores = lensScores.map(\.score)
        guard !scores.isEmpty else { return 0 }
        return Int(Double(scores.reduce(0, +)) / Double(scores.count))
    }

    func lensScore(for lens: LILADomain.WellnessLens) -> Int {
        lensScores.first(where: { $0.lens == lens })?.score ?? 0
    }
}

private extension UserGoal {
    var lilaGoal: LILADomain.WellnessGoal? {
        switch self {
        case .clearSkin: .clearerSkin
        case .steadyEnergy: .steadierEnergy
        case .gutCalm: .calmerDigestion
        case .hormoneSupport: .hormonalBalance
        case .leanStrength: .leanStrength
        case .deBloat: .lessBloating
        }
    }
}

private extension DailyNutritionPriority {
    var fallbackLILAGoal: LILADomain.WellnessGoal? {
        switch self {
        case .energy: .steadierEnergy
        case .digestion: .calmerDigestion
        case .skin: .clearerSkin
        case .hormones: .hormonalBalance
        case .bodyComposition: .bodyRecomposition
        }
    }
}

private extension SensitivityFlag {
    var lilaSensitivity: LILADomain.Sensitivity? {
        switch self {
        case .fragranceSensitive: .fragranceSensitive
        case .caffeineSensitive: .caffeineSensitive
        case .sugarSensitive: .sugarSensitive
        case .acneProne: .acneProne
        case .drySkin: .drySkinProne
        case .reactiveDigestion: .reactiveDigestion
        }
    }
}

private extension DietStyle {
    var lilaDietStyle: LILADomain.DietStyle {
        switch self {
        case .omnivore: .omnivore
        case .pescatarian: .pescatarian
        case .vegetarian: .vegetarian
        case .dairyLight: .dairyLight
        case .highProtein: .highProtein
        case .flexitarian: .flexitarian
        }
    }
}

private extension AgeRange {
    var typicalAge: Int {
        switch self {
        case .twenties: 27
        case .thirties: 35
        case .forties: 45
        case .fiftiesPlus: 56
        }
    }
}

private extension RestaurantFrequency {
    var lilaCookingFrequency: LILADomain.CookingFrequency {
        switch self {
        case .mostlyHome: .mostlyHome
        case .balanced: .mixed
        case .oftenOut: .mostlyOut
        }
    }

    var lilaMealContexts: Set<LILADomain.MealContext> {
        switch self {
        case .mostlyHome: [.home]
        case .balanced: [.home, .restaurant]
        case .oftenOut: [.restaurant, .onTheGo]
        }
    }
}

private extension LifeStage {
    func lilaBiology(optedIntoCycle: Bool) -> LILADomain.FemaleBiologyState {
        switch self {
        case .postpartumAware:
            .postpartum(.init(weeksPostpartum: 12, breastfeeding: false, notes: "Migrated from legacy life stage."))
        case .perimenopauseAware:
            .perimenopause(.init(symptoms: [], onHormoneTherapy: false, notes: "Migrated from legacy life stage."))
        case .highStress, .everyDay:
            optedIntoCycle ? .regularCycle(.init(source: .unknown)) : .unknown
        }
    }
}

private extension Array where Element == UserGoal {
    func lilaFitnessProfile() -> LILADomain.FitnessProfile {
        var modalities: Set<LILADomain.TrainingModality> = []
        var goals: [LILADomain.FitnessGoal] = []

        if contains(.leanStrength) {
            modalities.insert(.resistanceTraining)
            goals.append(contentsOf: [.leanMuscleGain, .strength])
        }
        if contains(.steadyEnergy) {
            modalities.insert(.walking)
            goals.append(.recovery)
        }
        if contains(.hormoneSupport) {
            modalities.insert(.pilates)
            goals.append(.hormonalBalance)
        }

        return LILADomain.FitnessProfile(
            modalities: modalities,
            primaryModality: modalities.first,
            frequencyPerWeek: modalities.isEmpty ? 0 : 3,
            typicalDurationMin: modalities.isEmpty ? 0 : 45,
            intensity: modalities.contains(.resistanceTraining) ? .moderate : .low,
            goals: goals,
            trainingWindow: .flexible,
            equipment: modalities.contains(.resistanceTraining) ? [.dumbbells] : [.bodyweight],
            experience: .beginner,
            limitations: [],
            preferredRestDays: [],
            currentLoadFromHealthKit: nil
        )
    }
}

private extension ProductCandidate {
    func lilaResolvedProduct() -> LILADomain.ResolvedProduct {
        LILADomain.ResolvedProduct(
            id: id,
            canonicalProductID: resolution?.canonicalProductID,
            resolutionSemantics: resolvedResolutionSemantics,
            name: name,
            brand: brand,
            category: productType.lilaProductCategory,
            barcode: barcode,
            ingredients: ingredients.map(\.name),
            nutrition: resolution?.nutritionSnapshot?.lilaNutritionProfile(for: self) ?? inferredNutritionProfile(),
            skincare: inferredSkincareProfile(),
            resolutionSource: resolution?.source.lilaResolutionSource ?? .localCatalog,
            headline: headline,
            imageURL: nil
        )
    }

    func inferredNutritionProfile() -> LILADomain.NutritionProfile? {
        guard productType == .food || productType == .supplement else { return nil }

        var macros = LILADomain.Macros(energyKcal: 160, proteinG: 6, carbsG: 18, fatG: 5)
        var micros = LILADomain.Micronutrients()
        var addedSugars: Double?
        var caffeine: Double?
        var fiber: Double?
        var dietaryFlags: Set<LILADomain.DietaryFlag> = []
        var additives: [LILADomain.Additive] = []
        var novaGroup: LILADomain.NOVAGroup? = .processed

        for tag in tags {
            switch tag {
            case .proteinDense, .collagen:
                macros.proteinG += 16
                dietaryFlags.insert(.highProtein)
            case .fiberSupport:
                fiber = max(fiber ?? 0, 7)
                dietaryFlags.insert(.highFiber)
            case .sugarSpike, .sugarAlcohol:
                addedSugars = max(addedSugars ?? 0, 12)
                novaGroup = .ultraProcessed
            case .stimulant:
                caffeine = max(caffeine ?? 0, 120)
            case .omegaSupport:
                micros.omega3Mg = max(micros.omega3Mg ?? 0, 400)
            case .ultraProcessed, .emulsifierHeavy:
                novaGroup = .ultraProcessed
                additives.append(
                    .init(
                        id: "ultra-processed-\(tag.rawValue)",
                        name: tag.rawValue,
                        category: .other,
                        riskTier: .watchful
                    )
                )
            default:
                break
            }
        }

        return LILADomain.NutritionProfile(
            macros: macros,
            micros: micros,
            caffeineMg: caffeine,
            alcoholPercent: nil,
            addedSugarsG: addedSugars,
            freeSugarsG: addedSugars,
            saturatedFatG: nil,
            transFatG: nil,
            sodiumMg: nil,
            fiberG: fiber,
            glycemicIndex: tags.contains(.sugarSpike) ? 70 : nil,
            glycemicLoad: tags.contains(.sugarSpike) ? 18 : nil,
            nutriScore: tags.contains(.ultraProcessed) ? .d : .b,
            novaGroup: novaGroup,
            additives: additives,
            allergens: [],
            dietaryFlags: dietaryFlags,
            servingSize: .init(amount: 1, unit: .serving, description: "Default serving")
        )
    }

    func inferredSkincareProfile() -> LILADomain.SkincareProfile? {
        guard productType == .skincare || productType == .haircare || productType == .personalCare else { return nil }

        let actives = tags.compactMap { tag -> LILADomain.CosmeticActive? in
            switch tag {
            case .niacinamide: .niacinamide
            case .peptide: .peptides
            case .hyaluronicAcid: .hyaluronicAcid
            case .retinoid: .retinoid
            case .mineralSPF: .mineralSPF
            default: nil
            }
        }

        return LILADomain.SkincareProfile(
            activeIngredients: actives,
            barrierFriendly: !tags.contains(.harshSurfactants),
            fragrancePresent: tags.contains(.fragrance),
            alcoholDryingPresent: tags.contains(.alcoholDrying),
            comedogenicRisk: tags.contains(.fragrance) ? .moderate : .low,
            pregnancySafe: !tags.contains(.retinoid)
        )
    }
}

private extension ProductResolutionSource {
    var lilaResolutionSource: LILADomain.ResolutionSource {
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
    func lilaNutritionProfile(for product: ProductCandidate) -> LILADomain.NutritionProfile {
        var dietaryFlags: Set<LILADomain.DietaryFlag> = []
        if let proteinGPer100g, proteinGPer100g >= 10 {
            dietaryFlags.insert(.highProtein)
        }
        if let fiberGPer100g, fiberGPer100g >= 5 {
            dietaryFlags.insert(.highFiber)
        }
        if let sugarsGPer100g, sugarsGPer100g <= 3 {
            dietaryFlags.insert(.sugarFree)
        }

        return LILADomain.NutritionProfile(
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
            allergens: product.allergensFromIngredients,
            dietaryFlags: dietaryFlags,
            servingSize: nil
        )
    }
}

private extension ProductCandidate {
    var allergensFromIngredients: Set<LILADomain.Allergen> {
        let text = ingredients.map(\.name).joined(separator: " ").lowercased()
        var allergens: Set<LILADomain.Allergen> = []
        if text.contains("milk") || text.contains("dairy") || text.contains("yogurt") || text.contains("whey") {
            allergens.insert(.dairy)
        }
        if text.contains("soy") {
            allergens.insert(.soy)
        }
        if text.contains("peanut") {
            allergens.insert(.peanuts)
        }
        if text.contains("almond") || text.contains("cashew") || text.contains("walnut") {
            allergens.insert(.treeNuts)
        }
        if text.contains("wheat") || text.contains("gluten") {
            allergens.insert(.wheat)
            allergens.insert(.gluten)
        }
        return allergens
    }
}

private extension ProductType {
    var lilaProductCategory: LILADomain.ProductCategory {
        switch self {
        case .food: .foodAndDrink
        case .supplement: .supplement
        case .skincare: .skincare
        case .haircare: .haircare
        case .personalCare: .personalCare
        }
    }
}

private extension AnalysisEntityType {
    var lilaProductCategory: LILADomain.ProductCategory {
        switch self {
        case .supplement: .supplement
        case .product, .meal, .menuItem: .foodAndDrink
        }
    }
}

private extension ScanSource {
    var lilaScanSource: LILADomain.ScanSource {
        switch self {
        case .liveBarcode: .liveBarcode
        case .manualBarcode: .manualBarcode
        case .labelPhoto: .labelPhoto
        case .mealPhoto: .mealPhoto
        case .menuPhoto: .menuPhoto
        case .manualLabel: .manualLabel
        }
    }

    var followUpPrompt: String {
        switch self {
        case .mealPhoto, .menuPhoto:
            "How did this meal feel 2-3 hours later?"
        case .liveBarcode, .manualBarcode, .labelPhoto, .manualLabel:
            "Did this choice support the outcome you wanted today?"
        }
    }
}

private extension AnalysisInputType {
    var lilaScanSource: LILADomain.ScanSource {
        switch self {
        case .barcode: .manualBarcode
        case .labelPhoto: .labelPhoto
        case .mealPhoto: .mealPhoto
        case .menuPhoto: .menuPhoto
        case .manual: .manualLabel
        }
    }
}

private extension LILADomain.ScanSource {
    var analysisInputType: AnalysisInputType {
        switch self {
        case .liveBarcode, .manualBarcode:
            .barcode
        case .labelPhoto:
            .labelPhoto
        case .mealPhoto:
            .mealPhoto
        case .menuPhoto:
            .menuPhoto
        case .manualLabel, .voiceLog:
            .manual
        }
    }
}

private extension LILADomain.ProductCategory {
    var analysisEntityType: AnalysisEntityType {
        switch self {
        case .supplement:
            .supplement
        case .foodAndDrink:
            .product
        case .skincare, .haircare, .personalCare:
            .product
        }
    }
}

private extension WellnessLensKind {
    var lilaLens: LILADomain.WellnessLens {
        switch self {
        case .glowSkin: .glowAndSkin
        case .hormoneBalance: .hormoneBalance
        case .gutComfort: .gutComfort
        case .energyMood: .energyAndMood
        case .bodyCompositionStrength: .bodyCompositionAndStrength
        }
    }
}

private extension StructuredLensScores {
    var dominantLILALens: LILADomain.WellnessLens? {
        let mapping: [(LILADomain.WellnessLens, Int)] = [
            (.glowAndSkin, skin),
            (.hormoneBalance, hormones),
            (.gutComfort, gut),
            (.energyAndMood, energy),
            (.bodyCompositionAndStrength, bodyComp)
        ]
        return mapping.max(by: { $0.1 < $1.1 })?.0
    }

    func lilaLensScores(
        contextFactors: [LILADomain.WellnessLens: [LILADomain.ContextFactor]] = [:]
    ) -> [LILADomain.LensScore] {
        [
            LILADomain.LensScore(lens: .glowAndSkin, score: skin, trend: skin >= 80 ? .rising : .neutral, summary: "Skin support read.", contextApplied: contextFactors[.glowAndSkin, default: []]),
            LILADomain.LensScore(lens: .hormoneBalance, score: hormones, trend: hormones >= 80 ? .rising : .neutral, summary: "Hormone-support read.", contextApplied: contextFactors[.hormoneBalance, default: []]),
            LILADomain.LensScore(lens: .gutComfort, score: gut, trend: gut >= 80 ? .rising : .neutral, summary: "Gut comfort read.", contextApplied: contextFactors[.gutComfort, default: []]),
            LILADomain.LensScore(lens: .energyAndMood, score: energy, trend: energy >= 80 ? .rising : .neutral, summary: "Energy-support read.", contextApplied: contextFactors[.energyAndMood, default: []]),
            LILADomain.LensScore(lens: .bodyCompositionAndStrength, score: bodyComp, trend: bodyComp >= 80 ? .rising : .neutral, summary: "Body-composition read.", contextApplied: contextFactors[.bodyCompositionAndStrength, default: []])
        ]
    }
}

private extension ConfidenceLevel {
    var lilaConfidence: LILADomain.Confidence {
        switch self {
        case .high: .high
        case .medium: .medium
        case .low: .low
        }
    }
}

private extension Double {
    var lilaConfidence: LILADomain.Confidence {
        switch self {
        case 0.85...: .high
        case 0.6..<0.85: .medium
        case 0.3..<0.6: .low
        default: .insufficient
        }
    }
}

private extension AnalysisVerdict {
    var lilaFitLevel: LILADomain.FitLevel {
        switch self {
        case .good: .greatFit
        case .adjust: .occasional
        case .avoid: .skip
        case .needsMoreInfo: .unclear
        }
    }
}

private extension LILADomain.FitLevel {
    var analysisVerdict: AnalysisVerdict {
        switch self {
        case .greatFit, .goodFit: .good
        case .occasional: .adjust
        case .skip: .avoid
        case .unclear: .needsMoreInfo
        }
    }

    func headline(productName: String, context: LILADomain.UserContext) -> String {
        switch self {
        case .greatFit:
            return "\(productName) sí suma para tu contexto de hoy"
        case .goodFit:
            return "\(productName) se ve compatible con tu día de hoy"
        case .occasional:
            return "\(productName) va mejor como algo ocasional hoy"
        case .skip:
            return "Mejor no \(productName.lowercased()) hoy"
        case .unclear:
            return "No hay claridad suficiente sobre \(productName)"
        }
    }
}

private extension Int {
    var lilaFitLevel: LILADomain.FitLevel {
        switch self {
        case 85...: .greatFit
        case 70..<85: .goodFit
        case 50..<70: .occasional
        default: .skip
        }
    }
}

private extension ReasonItem.Impact {
    var lilaDelta: Int {
        switch self {
        case .positive: 6
        case .caution: -6
        case .neutral: 0
        }
    }
}

private extension SafetyRiskLevel {
    var lilaSeverity: LILADomain.WatchoutSeverity {
        switch self {
        case .low: .gentle
        case .medium: .moderate
        case .high: .important
        }
    }
}

private extension LILADomain.UserContext {
    func applying(biometrics: BiometricsSnapshot?) -> LILADomain.UserContext {
        guard let biometrics else { return self }
        var updated = self

        if let cycleState = biometrics.cycleState,
           updated.dataSync.cycleTrackingOptIn {
            switch updated.biology {
            case .regularCycle:
                updated.biology = .regularCycle(cycleState)
            case .tryingToConceive:
                updated.biology = .tryingToConceive(cycleState)
            case .unknown:
                updated.biology = .regularCycle(cycleState)
            case .irregularCycle, .hormonalContraception, .pregnant, .postpartum, .perimenopause, .menopause:
                break
            }
        }

        if let trainingLoad = biometrics.trainingLoad {
            updated.fitness.currentLoadFromHealthKit = trainingLoad
        }

        updated.lastUpdated = biometrics.capturedAt
        return updated
    }
}

private func makeContextFactors(
    context: LILADomain.UserContext,
    biometrics: BiometricsSnapshot?,
    scanContext: ScanContext? = nil
) -> [LILADomain.WellnessLens: [LILADomain.ContextFactor]] {
    var factors: [LILADomain.WellnessLens: [LILADomain.ContextFactor]] = [:]

    for goal in context.goals.primary {
        let factor = LILADomain.ContextFactor(
            label: goal.displayTitle,
            direction: .boost,
            explanation: "Primary goal weighting keeps this lens more important in today's verdict."
        )
        factors[goal.primaryLens, default: []].append(factor)
    }

    if let phaseLabel = resolvedCyclePhaseLabel(context: context, biometrics: biometrics, scanContext: scanContext) {
        factors[.hormoneBalance, default: []].append(
            .init(
                label: phaseLabel,
                direction: .boost,
                explanation: "Cycle-aware context is available, so hormone-fit signals carry more weight."
            )
        )
    }

    if hasAnabolicWindowContext(biometrics: biometrics, scanContext: scanContext) {
        factors[.bodyCompositionAndStrength, default: []].append(
            .init(
                label: "Post-workout window",
                direction: .boost,
                explanation: "A recent workout makes recovery and protein-support signals more relevant."
            )
        )
    }

    if let sleepHours = biometrics?.sleepHours ?? scanContext?.sleepHours, sleepHours < 6 {
        factors[.energyAndMood, default: []].append(
            .init(
                label: "Short sleep",
                direction: .reduce,
                explanation: "Low sleep raises the bar for energy-stability recommendations."
            )
        )
    }

    return factors
}

private func resolvedCyclePhaseLabel(
    context: LILADomain.UserContext,
    biometrics: BiometricsSnapshot?,
    scanContext: ScanContext?
) -> String? {
    if let phase = biometrics?.cycleState?.currentPhase ?? context.biology.currentPhase {
        return phase.displayTitle
    }
    return scanContext?.cyclePhase?.displayTitle
}

private func hasAnabolicWindowContext(
    biometrics: BiometricsSnapshot?,
    scanContext: ScanContext?
) -> Bool {
    biometrics?.trainingLoad?.isInAnabolicWindow == true || scanContext?.isInAnabolicWindow == true
}

private extension ScanCyclePhase {
    var displayTitle: String {
        switch self {
        case .menstrual: "Menstrual"
        case .follicular: "Folicular"
        case .ovulatory: "Ovulatoria"
        case .luteal: "Lútea"
        }
    }
}
