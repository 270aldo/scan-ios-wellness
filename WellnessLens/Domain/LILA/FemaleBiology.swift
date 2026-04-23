import Foundation

extension LILADomain {
    enum FemaleBiologyState: Codable, Hashable, Sendable {
        case regularCycle(CycleState)
        case irregularCycle(IrregularCycleContext)
        case hormonalContraception(ContraceptionMethod)
        case tryingToConceive(CycleState)
        case pregnant(PregnancyContext)
        case postpartum(PostpartumContext)
        case perimenopause(PerimenopauseContext)
        case menopause(MenopauseContext)
        case unknown

        var displayTitle: String {
            switch self {
            case .regularCycle: "Ciclo regular"
            case .irregularCycle: "Ciclo irregular"
            case .hormonalContraception: "Anticoncepción hormonal"
            case .tryingToConceive: "Buscando embarazo"
            case .pregnant: "Embarazo"
            case .postpartum: "Postparto"
            case .perimenopause: "Perimenopausia"
            case .menopause: "Menopausia"
            case .unknown: "Prefiero no especificar"
            }
        }

        var currentPhase: MenstrualPhase? {
            switch self {
            case let .regularCycle(cycle), let .tryingToConceive(cycle):
                cycle.currentPhase
            case .irregularCycle, .hormonalContraception, .pregnant, .postpartum, .perimenopause, .menopause, .unknown:
                nil
            }
        }

        var requiresClinicalGuardrails: Bool {
            switch self {
            case .pregnant, .postpartum:
                true
            case .regularCycle, .irregularCycle, .hormonalContraception, .tryingToConceive, .perimenopause, .menopause, .unknown:
                false
            }
        }

        var isBreastfeeding: Bool {
            if case let .postpartum(context) = self {
                return context.breastfeeding
            }
            return false
        }
    }

    struct CycleState: Codable, Hashable, Sendable {
        var lastPeriodStart: Date?
        var averageCycleLength: Int
        var averagePeriodLength: Int
        var trackedSymptoms: [SymptomEvent]
        var source: CycleDataSource

        init(
            lastPeriodStart: Date? = nil,
            averageCycleLength: Int = 28,
            averagePeriodLength: Int = 5,
            trackedSymptoms: [SymptomEvent] = [],
            source: CycleDataSource = .unknown
        ) {
            self.lastPeriodStart = lastPeriodStart
            self.averageCycleLength = averageCycleLength
            self.averagePeriodLength = averagePeriodLength
            self.trackedSymptoms = trackedSymptoms
            self.source = source
        }

        func currentDayOfCycle(now: Date = .now, calendar: Calendar = .current) -> Int? {
            guard let lastPeriodStart else { return nil }
            let days = calendar.dateComponents([.day], from: lastPeriodStart, to: now).day ?? 0
            guard days >= 0 else { return nil }
            return (days % averageCycleLength) + 1
        }

        var currentPhase: MenstrualPhase? {
            guard let currentDay = currentDayOfCycle() else { return nil }
            return MenstrualPhase.inferred(dayOfCycle: currentDay, cycleLength: averageCycleLength)
        }

        var recentSymptoms: Set<CycleSymptom> {
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
            return Set(trackedSymptoms.filter { $0.date >= cutoff }.map(\.symptom))
        }
    }

    enum MenstrualPhase: String, Codable, CaseIterable, Sendable {
        case menstrual
        case follicular
        case ovulatory
        case luteal

        var displayTitle: String {
            switch self {
            case .menstrual: "Menstrual"
            case .follicular: "Folicular"
            case .ovulatory: "Ovulatoria"
            case .luteal: "Lútea"
            }
        }

        static func inferred(dayOfCycle: Int, cycleLength: Int) -> MenstrualPhase {
            let menstrualEnd = 5
            let follicularEnd = Int(Double(cycleLength) * 0.43)
            let ovulatoryEnd = Int(Double(cycleLength) * 0.54)

            switch dayOfCycle {
            case ...menstrualEnd:
                return .menstrual
            case (menstrualEnd + 1)...follicularEnd:
                return .follicular
            case (follicularEnd + 1)...ovulatoryEnd:
                return .ovulatory
            default:
                return .luteal
            }
        }
    }

    enum CycleSymptom: String, Codable, CaseIterable, Sendable {
        case bloating
        case cravings
        case breastTenderness
        case moodSwings
        case anxiety
        case irritability
        case fatigue
        case lowEnergy
        case cramps
        case heavyFlow
        case backPain
        case headache
        case migraine
        case acneFlare
        case dryness
        case constipation
        case diarrhea
        case nausea
        case insomnia
        case brainFog
    }

    struct SymptomEvent: Codable, Hashable, Identifiable, Sendable {
        var id: UUID
        var date: Date
        var symptom: CycleSymptom
        var intensity: Intensity

        init(id: UUID = UUID(), date: Date, symptom: CycleSymptom, intensity: Intensity) {
            self.id = id
            self.date = date
            self.symptom = symptom
            self.intensity = intensity
        }
    }

    enum Intensity: Int, Codable, CaseIterable, Sendable {
        case mild = 1
        case moderate = 2
        case strong = 3
    }

    enum CycleDataSource: String, Codable, Sendable {
        case appleHealth
        case manualEntry
        case imported
        case unknown
    }

    struct IrregularCycleContext: Codable, Hashable, Sendable {
        var suspectedCause: IrregularCycleCause?
        var lastPeriodStart: Date?
        var trackedSymptoms: [SymptomEvent]
    }

    enum IrregularCycleCause: String, Codable, Sendable {
        case postpartumTransition
        case pcos
        case perimenopause
        case stress
        case hypothalamic
        case unknown
    }

    enum ContraceptionMethod: String, Codable, Sendable {
        case combinedPill
        case progesteroneOnlyPill
        case hormonalIUD
        case implant
        case patch
        case ring
        case injection
    }

    struct PregnancyContext: Codable, Hashable, Sendable {
        var weeksPregnant: Int
        var trimester: Int
        var notes: String?

        init(weeksPregnant: Int, notes: String? = nil) {
            self.weeksPregnant = weeksPregnant
            self.trimester = switch weeksPregnant {
            case ..<14: 1
            case 14..<28: 2
            default: 3
            }
            self.notes = notes
        }
    }

    struct PostpartumContext: Codable, Hashable, Sendable {
        var weeksPostpartum: Int
        var breastfeeding: Bool
        var notes: String?
    }

    struct PerimenopauseContext: Codable, Hashable, Sendable {
        var symptoms: Set<PerimenopauseSymptom>
        var onHormoneTherapy: Bool
        var notes: String?
    }

    enum PerimenopauseSymptom: String, Codable, CaseIterable, Sendable {
        case hotFlashes
        case nightSweats
        case insomnia
        case lowMood
        case anxiety
        case brainFog
        case jointPain
        case lowLibido
        case cycleShortening
        case cycleLengthening
        case heavyBleeding
        case migraines
    }

    struct MenopauseContext: Codable, Hashable, Sendable {
        var yearsSinceFinalPeriod: Int?
        var onHormoneTherapy: Bool
    }
}
