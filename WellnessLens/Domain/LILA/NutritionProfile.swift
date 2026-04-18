import Foundation

extension LILADomain {
    struct NutritionProfile: Codable, Hashable, Sendable {
        var macros: Macros
        var micros: Micronutrients
        var caffeineMg: Double?
        var alcoholPercent: Double?
        var addedSugarsG: Double?
        var freeSugarsG: Double?
        var saturatedFatG: Double?
        var transFatG: Double?
        var sodiumMg: Double?
        var fiberG: Double?
        var glycemicIndex: Int?
        var glycemicLoad: Double?
        var nutriScore: NutriScore?
        var novaGroup: NOVAGroup?
        var additives: [Additive]
        var allergens: Set<Allergen>
        var dietaryFlags: Set<DietaryFlag>
        var servingSize: ServingSize?

        static let empty = NutritionProfile(
            macros: .empty,
            micros: .empty,
            caffeineMg: nil,
            alcoholPercent: nil,
            addedSugarsG: nil,
            freeSugarsG: nil,
            saturatedFatG: nil,
            transFatG: nil,
            sodiumMg: nil,
            fiberG: nil,
            glycemicIndex: nil,
            glycemicLoad: nil,
            nutriScore: nil,
            novaGroup: nil,
            additives: [],
            allergens: [],
            dietaryFlags: [],
            servingSize: nil
        )
    }

    struct Macros: Codable, Hashable, Sendable {
        var energyKcal: Double
        var proteinG: Double
        var carbsG: Double
        var fatG: Double

        static let empty = Macros(energyKcal: 0, proteinG: 0, carbsG: 0, fatG: 0)

        var proteinDensityPer100Kcal: Double {
            guard energyKcal > 0 else { return 0 }
            return (proteinG / energyKcal) * 100
        }
    }

    struct Micronutrients: Codable, Hashable, Sendable {
        var ironMg: Double?
        var calciumMg: Double?
        var vitaminDMcg: Double?
        var folateMcg: Double?
        var vitaminB12Mcg: Double?
        var magnesiumMg: Double?
        var zincMg: Double?
        var iodineMcg: Double?
        var omega3Mg: Double?
        var cholineMg: Double?

        static let empty = Micronutrients()

        init(
            ironMg: Double? = nil,
            calciumMg: Double? = nil,
            vitaminDMcg: Double? = nil,
            folateMcg: Double? = nil,
            vitaminB12Mcg: Double? = nil,
            magnesiumMg: Double? = nil,
            zincMg: Double? = nil,
            iodineMcg: Double? = nil,
            omega3Mg: Double? = nil,
            cholineMg: Double? = nil
        ) {
            self.ironMg = ironMg
            self.calciumMg = calciumMg
            self.vitaminDMcg = vitaminDMcg
            self.folateMcg = folateMcg
            self.vitaminB12Mcg = vitaminB12Mcg
            self.magnesiumMg = magnesiumMg
            self.zincMg = zincMg
            self.iodineMcg = iodineMcg
            self.omega3Mg = omega3Mg
            self.cholineMg = cholineMg
        }
    }

    enum NutriScore: String, Codable, CaseIterable, Sendable {
        case a, b, c, d, e
    }

    enum NOVAGroup: Int, Codable, CaseIterable, Sendable {
        case unprocessed = 1
        case culinaryIngredient = 2
        case processed = 3
        case ultraProcessed = 4
    }

    struct Additive: Codable, Hashable, Identifiable, Sendable {
        var id: String
        var name: String
        var category: AdditiveCategory
        var riskTier: AdditiveRiskTier
    }

    enum AdditiveCategory: String, Codable, CaseIterable, Sendable {
        case colorant
        case preservative
        case emulsifier
        case sweetener
        case flavorEnhancer
        case acidityRegulator
        case thickener
        case antioxidant
        case other
    }

    enum AdditiveRiskTier: String, Codable, Sendable {
        case low
        case moderate
        case watchful
        case avoid
    }

    enum Allergen: String, Codable, CaseIterable, Sendable {
        case gluten
        case wheat
        case dairy
        case lactose
        case eggs
        case soy
        case peanuts
        case treeNuts
        case fish
        case shellfish
        case sesame
        case corn
    }

    enum DietaryFlag: String, Codable, CaseIterable, Sendable {
        case vegan
        case vegetarian
        case pescatarian
        case glutenFree
        case dairyFree
        case sugarFree
        case keto
        case paleo
        case lowFodmap
        case lowSodium
        case highProtein
        case highFiber
        case pregnancySafe
        case breastfeedingSafe
    }

    struct ServingSize: Codable, Hashable, Sendable {
        var amount: Double
        var unit: ServingUnit
        var description: String?
    }

    enum ServingUnit: String, Codable, CaseIterable, Sendable {
        case grams
        case milliliters
        case ounces
        case cup
        case tablespoon
        case teaspoon
        case piece
        case slice
        case serving
    }

    enum ProductCategory: String, Codable, CaseIterable, Sendable {
        case foodAndDrink
        case supplement
        case skincare
        case haircare
        case personalCare
    }

    struct SkincareProfile: Codable, Hashable, Sendable {
        var activeIngredients: [CosmeticActive]
        var barrierFriendly: Bool?
        var fragrancePresent: Bool
        var alcoholDryingPresent: Bool
        var comedogenicRisk: ComedogenicRisk?
        var pregnancySafe: Bool?

        init(
            activeIngredients: [CosmeticActive] = [],
            barrierFriendly: Bool? = nil,
            fragrancePresent: Bool = false,
            alcoholDryingPresent: Bool = false,
            comedogenicRisk: ComedogenicRisk? = nil,
            pregnancySafe: Bool? = nil
        ) {
            self.activeIngredients = activeIngredients
            self.barrierFriendly = barrierFriendly
            self.fragrancePresent = fragrancePresent
            self.alcoholDryingPresent = alcoholDryingPresent
            self.comedogenicRisk = comedogenicRisk
            self.pregnancySafe = pregnancySafe
        }
    }

    enum CosmeticActive: String, Codable, CaseIterable, Sendable {
        case retinoid
        case niacinamide
        case peptides
        case hyaluronicAcid
        case vitaminC
        case salicylicAcid
        case ceramides
        case squalane
        case mineralSPF
        case chemicalSPF
    }

    enum ComedogenicRisk: String, Codable, Sendable {
        case low
        case moderate
        case high
    }
}
