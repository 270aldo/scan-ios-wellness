import Foundation

extension LILADomain {
    struct FitnessProfile: Codable, Hashable, Sendable {
        var modalities: Set<TrainingModality>
        var primaryModality: TrainingModality?
        var frequencyPerWeek: Int
        var typicalDurationMin: Int
        var intensity: IntensityLevel
        var goals: [FitnessGoal]
        var trainingWindow: TrainingWindow
        var equipment: Set<EquipmentAccess>
        var experience: ExperienceLevel
        var limitations: Set<PhysicalLimitation>
        var preferredRestDays: Set<Weekday>
        var currentLoadFromHealthKit: WeeklyTrainingLoad?

        static let empty = FitnessProfile(
            modalities: [],
            primaryModality: nil,
            frequencyPerWeek: 0,
            typicalDurationMin: 0,
            intensity: .moderate,
            goals: [],
            trainingWindow: .flexible,
            equipment: [],
            experience: .beginner,
            limitations: [],
            preferredRestDays: [],
            currentLoadFromHealthKit: nil
        )

        var isActive: Bool { frequencyPerWeek > 0 }
        var weeklyTrainingMinutes: Int { frequencyPerWeek * typicalDurationMin }

        var volumeTier: VolumeTier {
            switch weeklyTrainingMinutes {
            case 0: .none
            case 1..<75: .low
            case 75..<150: .moderate
            case 150..<300: .high
            default: .athlete
            }
        }
    }

    enum TrainingModality: String, Codable, CaseIterable, Identifiable, Sendable {
        case resistanceTraining
        case strengthTraining
        case hypertrophy
        case hiit
        case cardioSteady
        case running
        case cycling
        case swimming
        case walking
        case yoga
        case pilates
        case dance
        case crossfit
        case functional
        case mobility

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .resistanceTraining: "Entrenamiento con pesas"
            case .strengthTraining: "Fuerza"
            case .hypertrophy: "Hipertrofia"
            case .hiit: "HIIT"
            case .cardioSteady: "Cardio estable"
            case .running: "Running"
            case .cycling: "Ciclismo"
            case .swimming: "Natación"
            case .walking: "Caminar"
            case .yoga: "Yoga"
            case .pilates: "Pilates"
            case .dance: "Danza"
            case .crossfit: "CrossFit"
            case .functional: "Entrenamiento funcional"
            case .mobility: "Movilidad"
            }
        }

        var hasStrongProteinDemand: Bool {
            switch self {
            case .resistanceTraining, .strengthTraining, .hypertrophy, .crossfit, .functional:
                true
            default:
                false
            }
        }
    }

    enum FitnessGoal: String, Codable, CaseIterable, Identifiable, Sendable {
        case fatLoss
        case leanMuscleGain
        case strength
        case endurance
        case mobility
        case toneAndSculpt
        case stressRelief
        case recovery
        case postpartumRecovery
        case perimenopauseSupport
        case boneDensity
        case hormonalBalance

        var id: String { rawValue }
    }

    enum IntensityLevel: String, Codable, CaseIterable, Sendable {
        case low
        case moderate
        case high
        case mixed
    }

    enum VolumeTier: String, Codable, Sendable {
        case none
        case low
        case moderate
        case high
        case athlete
    }

    enum TrainingWindow: String, Codable, CaseIterable, Sendable {
        case earlyMorning
        case morning
        case midday
        case afternoon
        case evening
        case night
        case flexible

        var requiresSpecialTiming: Bool {
            switch self {
            case .earlyMorning, .night:
                true
            default:
                false
            }
        }
    }

    enum EquipmentAccess: String, Codable, CaseIterable, Sendable {
        case fullGym
        case homeGym
        case bodyweight
        case bands
        case dumbbells
        case cardioMachines
    }

    enum ExperienceLevel: String, Codable, CaseIterable, Sendable {
        case beginner
        case intermediate
        case advanced
    }

    enum PhysicalLimitation: String, Codable, CaseIterable, Sendable {
        case pregnancyAware
        case postpartumAware
        case lowBackPain
        case kneePain
        case shoulderPain
        case pelvicFloorRecovery
    }

    enum Weekday: String, Codable, CaseIterable, Sendable {
        case monday
        case tuesday
        case wednesday
        case thursday
        case friday
        case saturday
        case sunday
    }

    struct WeeklyTrainingLoad: Codable, Hashable, Sendable {
        var workoutsCount: Int
        var activeEnergyBurnedKcal: Double?
        var durationMinutes: Int
        var lastWorkoutEndedAt: Date?

        var isInAnabolicWindow: Bool {
            guard let lastWorkoutEndedAt else { return false }
            return Date().timeIntervalSince(lastWorkoutEndedAt) <= 2 * 60 * 60
        }
    }
}
