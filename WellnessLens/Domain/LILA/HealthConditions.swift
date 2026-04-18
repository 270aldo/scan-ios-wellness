import Foundation

extension LILADomain {
    enum HealthCondition: String, Codable, CaseIterable, Identifiable, Sendable {
        case pcos
        case endometriosis
        case hypothyroid
        case hyperthyroid
        case hashimotos
        case insulinResistance
        case type1Diabetes
        case type2Diabetes
        case gestationalDiabetes
        case ibs
        case ibd
        case celiac
        case nonCeliacGlutenSensitivity
        case sibo
        case gerd
        case histamineIntolerance
        case fodmapSensitivity
        case eczema
        case psoriasis
        case rosacea
        case acneModerate
        case acneSevere
        case hormonalAcne
        case melasma
        case ironDeficiencyAnemia
        case vitaminDDeficiency
        case b12Deficiency
        case migraine
        case menstrualMigraine
        case autoimmuneGeneric
        case hypertension
        case highCholesterol
        case anxiety
        case depression
        case pmdd
        case edHistory

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .pcos: "SOP / PCOS"
            case .endometriosis: "Endometriosis"
            case .hypothyroid: "Hipotiroidismo"
            case .hyperthyroid: "Hipertiroidismo"
            case .hashimotos: "Hashimoto"
            case .insulinResistance: "Resistencia a la insulina"
            case .type1Diabetes: "Diabetes tipo 1"
            case .type2Diabetes: "Diabetes tipo 2"
            case .gestationalDiabetes: "Diabetes gestacional"
            case .ibs: "Colon irritable"
            case .ibd: "EII (Crohn / CU)"
            case .celiac: "Celiaquía"
            case .nonCeliacGlutenSensitivity: "Sensibilidad al gluten"
            case .sibo: "SIBO"
            case .gerd: "Reflujo"
            case .histamineIntolerance: "Intolerancia a histamina"
            case .fodmapSensitivity: "Sensibilidad a FODMAPs"
            case .eczema: "Eczema"
            case .psoriasis: "Psoriasis"
            case .rosacea: "Rosácea"
            case .acneModerate: "Acné moderado"
            case .acneSevere: "Acné severo"
            case .hormonalAcne: "Acné hormonal"
            case .melasma: "Melasma"
            case .ironDeficiencyAnemia: "Anemia por deficiencia de hierro"
            case .vitaminDDeficiency: "Deficiencia de vitamina D"
            case .b12Deficiency: "Deficiencia de B12"
            case .migraine: "Migraña"
            case .menstrualMigraine: "Migraña menstrual"
            case .autoimmuneGeneric: "Condición autoinmune"
            case .hypertension: "Hipertensión"
            case .highCholesterol: "Colesterol alto"
            case .anxiety: "Ansiedad"
            case .depression: "Depresión"
            case .pmdd: "TDPM"
            case .edHistory: "Historial de TCA"
            }
        }

        var requiresGuardrails: Bool {
            switch self {
            case .edHistory, .type1Diabetes, .type2Diabetes, .gestationalDiabetes, .celiac:
                true
            default:
                false
            }
        }
    }

    enum Sensitivity: String, Codable, CaseIterable, Identifiable, Sendable {
        case fragranceSensitive
        case caffeineSensitive
        case sugarSensitive
        case saltSensitive
        case alcoholSensitive
        case dairySensitive
        case glutenSensitive
        case spicyFoodSensitive
        case histamineSensitive
        case sulfiteSensitive
        case acneProne
        case reactiveSkin
        case drySkinProne
        case reactiveDigestion
        case bloatingProne
        case migraineTriggerSensitive

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .fragranceSensitive: "Sensible a fragancias"
            case .caffeineSensitive: "Sensible a cafeína"
            case .sugarSensitive: "Sensible al azúcar"
            case .saltSensitive: "Sensible al sodio"
            case .alcoholSensitive: "Sensible al alcohol"
            case .dairySensitive: "Sensible a lácteos"
            case .glutenSensitive: "Sensible al gluten"
            case .spicyFoodSensitive: "Sensible al picante"
            case .histamineSensitive: "Sensible a histamina"
            case .sulfiteSensitive: "Sensible a sulfitos"
            case .acneProne: "Propensa al acné"
            case .reactiveSkin: "Piel reactiva"
            case .drySkinProne: "Piel seca"
            case .reactiveDigestion: "Digestión reactiva"
            case .bloatingProne: "Propensa a inflamación"
            case .migraineTriggerSensitive: "Sensible a detonantes de migraña"
            }
        }
    }

    enum DietStyle: String, Codable, CaseIterable, Identifiable, Sendable {
        case omnivore
        case flexitarian
        case pescatarian
        case vegetarian
        case vegan
        case keto
        case paleo
        case mediterranean
        case lowCarb
        case highProtein
        case lowFodmap
        case glutenFree
        case dairyLight
        case dash
        case intuitiveEating
        case noRestrictions

        var id: String { rawValue }
    }

    struct CookingContext: Codable, Hashable, Sendable {
        var homeCookingFrequency: CookingFrequency
        var typicalMealContext: Set<MealContext>
        var budgetTier: BudgetTier
        var cuisinePreferences: Set<CuisinePreference>

        init(
            homeCookingFrequency: CookingFrequency = .mixed,
            typicalMealContext: Set<MealContext> = [.home],
            budgetTier: BudgetTier = .moderate,
            cuisinePreferences: Set<CuisinePreference> = []
        ) {
            self.homeCookingFrequency = homeCookingFrequency
            self.typicalMealContext = typicalMealContext
            self.budgetTier = budgetTier
            self.cuisinePreferences = cuisinePreferences
        }
    }

    enum CookingFrequency: String, Codable, Sendable {
        case alwaysHome
        case mostlyHome
        case mixed
        case mostlyOut
        case alwaysOut
    }

    enum MealContext: String, Codable, Sendable {
        case home
        case office
        case restaurant
        case travel
        case onTheGo
    }

    enum BudgetTier: String, Codable, Sendable {
        case budget
        case moderate
        case comfortable
        case premium
    }

    enum CuisinePreference: String, Codable, CaseIterable, Sendable {
        case mexican
        case mediterranean
        case asian
        case italian
        case indian
        case middleEastern
        case latinAmerican
        case american
        case japanese
        case other
    }
}
