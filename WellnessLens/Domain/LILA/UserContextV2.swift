import Foundation

enum LILADomain {}

extension LILADomain {
    struct UserContext: Codable, Hashable, Sendable {
        var identity: Identity
        var biology: FemaleBiologyState
        var fitness: FitnessProfile
        var conditions: Set<HealthCondition>
        var sensitivities: Set<Sensitivity>
        var allergies: Set<Allergen>
        var dietStyle: DietStyle
        var goals: PrioritizedGoals
        var cooking: CookingContext
        var dataSync: DataSyncPreferences
        var personalNote: String?
        var lastUpdated: Date

        static let starter = UserContext(
            identity: .empty,
            biology: .unknown,
            fitness: .empty,
            conditions: [],
            sensitivities: [],
            allergies: [],
            dietStyle: .noRestrictions,
            goals: .empty,
            cooking: CookingContext(),
            dataSync: DataSyncPreferences(),
            personalNote: nil,
            lastUpdated: .now
        )

        var hasCompletedOnboarding: Bool {
            !goals.primary.isEmpty
        }

        var requiresGuardrails: Bool {
            biology.requiresClinicalGuardrails || conditions.contains(where: \.requiresGuardrails)
        }

        var cycleAwareEnabled: Bool {
            dataSync.cycleTrackingOptIn && biology.currentPhase != nil
        }
    }

    struct Identity: Codable, Hashable, Sendable {
        var age: Int?
        var displayName: String?
        var heightCm: Double?
        var weightKg: Double?
        var locale: String
        var timeZoneIdentifier: String

        static let empty = Identity(
            age: nil,
            displayName: nil,
            heightCm: nil,
            weightKg: nil,
            locale: Locale.current.identifier,
            timeZoneIdentifier: TimeZone.current.identifier
        )

        var bmi: Double? {
            guard let heightCm, let weightKg, heightCm > 0 else { return nil }
            let heightM = heightCm / 100
            return weightKg / (heightM * heightM)
        }

        var ageGroup: AgeGroup? {
            guard let age else { return nil }
            return AgeGroup.from(age: age)
        }
    }

    enum AgeGroup: String, Codable, Sendable {
        case under25
        case twentyFiveTo34
        case thirtyFiveTo44
        case fortyFiveTo54
        case fiftyFiveTo64
        case sixtyFivePlus

        static func from(age: Int) -> AgeGroup {
            switch age {
            case ..<25: .under25
            case 25...34: .twentyFiveTo34
            case 35...44: .thirtyFiveTo44
            case 45...54: .fortyFiveTo54
            case 55...64: .fiftyFiveTo64
            default: .sixtyFivePlus
            }
        }
    }

    struct PrioritizedGoals: Codable, Hashable, Sendable {
        var primary: [WellnessGoal]
        var secondary: [WellnessGoal]
        var emotionalAnchor: String?

        static let empty = PrioritizedGoals(primary: [], secondary: [], emotionalAnchor: nil)

        init(
            primary: [WellnessGoal] = [],
            secondary: [WellnessGoal] = [],
            emotionalAnchor: String? = nil
        ) {
            self.primary = Array(primary.prefix(3))
            self.secondary = secondary
            self.emotionalAnchor = emotionalAnchor
        }
    }

    enum WellnessGoal: String, Codable, CaseIterable, Identifiable, Sendable {
        case clearerSkin
        case calmerSkin
        case glowingSkin
        case antiAging
        case calmerDigestion
        case lessBloating
        case regularDigestion
        case steadierEnergy
        case morningEnergy
        case afternoonEnergy
        case calmerMind
        case betterSleep
        case lessStress
        case betterFocus
        case cycleRegularity
        case pmsRelief
        case perimenopauseSupport
        case postpartumRecovery
        case leanStrength
        case fatLoss
        case bodyRecomposition
        case maintainWeight
        case athleticPerformance
        case consistency
        case recovery
        case hormonalBalance
        case boneDensity
        case cardiovascularHealth
        case metabolicHealth

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .clearerSkin: "Piel más limpia"
            case .calmerSkin: "Piel más calmada"
            case .glowingSkin: "Piel luminosa"
            case .antiAging: "Anti-edad"
            case .calmerDigestion: "Digestión tranquila"
            case .lessBloating: "Menos inflamación"
            case .regularDigestion: "Digestión regular"
            case .steadierEnergy: "Energía estable"
            case .morningEnergy: "Despertar con energía"
            case .afternoonEnergy: "Evitar bajones"
            case .calmerMind: "Mente tranquila"
            case .betterSleep: "Dormir mejor"
            case .lessStress: "Reducir estrés"
            case .betterFocus: "Mejor enfoque"
            case .cycleRegularity: "Regularidad del ciclo"
            case .pmsRelief: "Aliviar PMS"
            case .perimenopauseSupport: "Apoyo perimenopausia"
            case .postpartumRecovery: "Recuperación postparto"
            case .leanStrength: "Fuerza magra"
            case .fatLoss: "Reducir grasa"
            case .bodyRecomposition: "Recomposición"
            case .maintainWeight: "Mantener peso"
            case .athleticPerformance: "Rendimiento atlético"
            case .consistency: "Consistencia"
            case .recovery: "Mejor recuperación"
            case .hormonalBalance: "Balance hormonal"
            case .boneDensity: "Densidad ósea"
            case .cardiovascularHealth: "Salud cardiovascular"
            case .metabolicHealth: "Salud metabólica"
            }
        }

        var primaryLens: WellnessLens {
            switch self {
            case .clearerSkin, .calmerSkin, .glowingSkin, .antiAging:
                .glowAndSkin
            case .calmerDigestion, .lessBloating, .regularDigestion:
                .gutComfort
            case .steadierEnergy, .morningEnergy, .afternoonEnergy,
                 .calmerMind, .betterSleep, .lessStress, .betterFocus:
                .energyAndMood
            case .cycleRegularity, .pmsRelief, .perimenopauseSupport,
                 .postpartumRecovery, .hormonalBalance:
                .hormoneBalance
            case .leanStrength, .fatLoss, .bodyRecomposition,
                 .maintainWeight, .athleticPerformance, .consistency,
                 .recovery, .boneDensity, .cardiovascularHealth, .metabolicHealth:
                .bodyCompositionAndStrength
            }
        }
    }

    struct DataSyncPreferences: Codable, Hashable, Sendable {
        var healthKitEnabled: Bool
        var cycleTrackingOptIn: Bool
        var workoutsOptIn: Bool
        var hrvAndRecoveryOptIn: Bool
        var sleepOptIn: Bool
        var nutritionWriteBackOptIn: Bool
        var analyticsOptIn: Bool
        var cloudSyncEnabled: Bool

        init(
            healthKitEnabled: Bool = false,
            cycleTrackingOptIn: Bool = false,
            workoutsOptIn: Bool = false,
            hrvAndRecoveryOptIn: Bool = false,
            sleepOptIn: Bool = false,
            nutritionWriteBackOptIn: Bool = false,
            analyticsOptIn: Bool = false,
            cloudSyncEnabled: Bool = false
        ) {
            self.healthKitEnabled = healthKitEnabled
            self.cycleTrackingOptIn = cycleTrackingOptIn
            self.workoutsOptIn = workoutsOptIn
            self.hrvAndRecoveryOptIn = hrvAndRecoveryOptIn
            self.sleepOptIn = sleepOptIn
            self.nutritionWriteBackOptIn = nutritionWriteBackOptIn
            self.analyticsOptIn = analyticsOptIn
            self.cloudSyncEnabled = cloudSyncEnabled
        }
    }

    enum WellnessLens: String, Codable, CaseIterable, Identifiable, Sendable {
        case glowAndSkin
        case hormoneBalance
        case gutComfort
        case energyAndMood
        case bodyCompositionAndStrength

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .glowAndSkin: "Piel & Glow"
            case .hormoneBalance: "Balance hormonal"
            case .gutComfort: "Digestión"
            case .energyAndMood: "Energía & Ánimo"
            case .bodyCompositionAndStrength: "Cuerpo & Fuerza"
            }
        }
    }
}
