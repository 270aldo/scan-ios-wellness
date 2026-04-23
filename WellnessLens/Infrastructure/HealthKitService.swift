import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

struct BiometricsSnapshot: Codable, Hashable, Sendable {
    var capturedAt: Date
    var cycleState: LILADomain.CycleState?
    var trainingLoad: LILADomain.WeeklyTrainingLoad?
    var sleepHours: Double?
    var hrvMilliseconds: Double?
    var restingHeartRate: Double?
    var wristTemperatureDeltaCelsius: Double?

    static let empty = BiometricsSnapshot(
        capturedAt: .now,
        cycleState: nil,
        trainingLoad: nil,
        sleepHours: nil,
        hrvMilliseconds: nil,
        restingHeartRate: nil,
        wristTemperatureDeltaCelsius: nil
    )
}

enum HealthAuthorizationState: String, Codable, Sendable {
    case unavailable
    case notDetermined
    case sharingDenied
    case sharingAuthorized
}

struct HealthKitAuthorizationReport: Codable, Hashable, Sendable {
    var healthDataAvailable: Bool
    var cycle: HealthAuthorizationState
    var workouts: HealthAuthorizationState
    var recovery: HealthAuthorizationState
    var sleep: HealthAuthorizationState
    var nutritionWriteBack: HealthAuthorizationState
}

protocol HealthKitServicing: Sendable {
    func requestAuthorization(for preferences: LILADomain.DataSyncPreferences) async -> HealthKitAuthorizationReport
    func currentSnapshot(for profile: UserProfile) async -> BiometricsSnapshot?
    func writeNutritionIfAllowed(verdict: LILADomain.ScanVerdict, preferences: LILADomain.DataSyncPreferences) async
}

struct NoopHealthKitService: HealthKitServicing {
    func requestAuthorization(for preferences: LILADomain.DataSyncPreferences) async -> HealthKitAuthorizationReport {
        .init(
            healthDataAvailable: false,
            cycle: .unavailable,
            workouts: .unavailable,
            recovery: .unavailable,
            sleep: .unavailable,
            nutritionWriteBack: .unavailable
        )
    }

    func currentSnapshot(for profile: UserProfile) async -> BiometricsSnapshot? {
        nil
    }

    func writeNutritionIfAllowed(verdict: LILADomain.ScanVerdict, preferences: LILADomain.DataSyncPreferences) async {}
}

#if canImport(HealthKit)
actor HealthKitService: HealthKitServicing {
    private let healthStore: HKHealthStore
    private let calendar: Calendar

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        calendar: Calendar = .current
    ) {
        self.healthStore = healthStore
        self.calendar = calendar
    }

    func requestAuthorization(for preferences: LILADomain.DataSyncPreferences) async -> HealthKitAuthorizationReport {
        guard HKHealthStore.isHealthDataAvailable() else {
            return unavailableReport
        }

        let readTypes = makeReadTypes(preferences: preferences)
        let shareTypes = makeShareTypes(preferences: preferences)

        guard !readTypes.isEmpty || !shareTypes.isEmpty else {
            return authorizationReport(preferences: preferences)
        }

        do {
            try await requestAuthorization(toShare: shareTypes, read: readTypes)
        } catch {
            return authorizationReport(preferences: preferences)
        }

        return authorizationReport(preferences: preferences)
    }

    func currentSnapshot(for profile: UserProfile) async -> BiometricsSnapshot? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let preferences = profile.lilaContext().dataSync
        guard preferences.healthKitEnabled else { return nil }

        async let cycleState = fetchCycleStateIfAuthorized(preferences: preferences)
        async let trainingLoad = fetchTrainingLoadIfAuthorized(preferences: preferences)
        async let sleepHours = fetchSleepHoursIfAuthorized(preferences: preferences)
        async let hrv = fetchHRVIfAuthorized(preferences: preferences)
        async let restingHeartRate = fetchRestingHeartRateIfAuthorized(preferences: preferences)
        async let wristTemperature = fetchWristTemperatureIfAuthorized(preferences: preferences)

        return BiometricsSnapshot(
            capturedAt: .now,
            cycleState: await cycleState,
            trainingLoad: await trainingLoad,
            sleepHours: await sleepHours,
            hrvMilliseconds: await hrv,
            restingHeartRate: await restingHeartRate,
            wristTemperatureDeltaCelsius: await wristTemperature
        )
    }

    func writeNutritionIfAllowed(verdict: LILADomain.ScanVerdict, preferences: LILADomain.DataSyncPreferences) async {
        guard preferences.healthKitEnabled, preferences.nutritionWriteBackOptIn else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let nutrition = verdict.resolvedProduct.nutrition else { return }

        let now = Date()
        var samples: [HKQuantitySample] = []

        if let sample = quantitySample(
            identifier: .dietaryEnergyConsumed,
            value: nutrition.macros.energyKcal,
            unit: .kilocalorie(),
            date: now
        ) {
            samples.append(sample)
        }
        if let sample = quantitySample(
            identifier: .dietaryProtein,
            value: nutrition.macros.proteinG,
            unit: .gram(),
            date: now
        ) {
            samples.append(sample)
        }
        if let sample = quantitySample(
            identifier: .dietaryCarbohydrates,
            value: nutrition.macros.carbsG,
            unit: .gram(),
            date: now
        ) {
            samples.append(sample)
        }
        if let sample = quantitySample(
            identifier: .dietaryFatTotal,
            value: nutrition.macros.fatG,
            unit: .gram(),
            date: now
        ) {
            samples.append(sample)
        }
        if let fiberG = nutrition.fiberG,
           let sample = quantitySample(identifier: .dietaryFiber, value: fiberG, unit: .gram(), date: now) {
            samples.append(sample)
        }
        if let caffeine = nutrition.caffeineMg,
           let sample = quantitySample(identifier: .dietaryCaffeine, value: caffeine, unit: .gramUnit(with: .milli), date: now) {
            samples.append(sample)
        }

        guard !samples.isEmpty else { return }
        try? await save(samples)
    }

    private var unavailableReport: HealthKitAuthorizationReport {
        .init(
            healthDataAvailable: false,
            cycle: .unavailable,
            workouts: .unavailable,
            recovery: .unavailable,
            sleep: .unavailable,
            nutritionWriteBack: .unavailable
        )
    }

    private func authorizationReport(preferences: LILADomain.DataSyncPreferences) -> HealthKitAuthorizationReport {
        let cycleState = authorizationState(for: cycleCategoryType)
        let workoutState = authorizationState(for: HKObjectType.workoutType())
        let recoveryType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        let nutritionType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)

        return HealthKitAuthorizationReport(
            healthDataAvailable: HKHealthStore.isHealthDataAvailable(),
            cycle: preferences.cycleTrackingOptIn ? cycleState : .notDetermined,
            workouts: preferences.workoutsOptIn ? workoutState : .notDetermined,
            recovery: preferences.hrvAndRecoveryOptIn ? authorizationState(for: recoveryType) : .notDetermined,
            sleep: preferences.sleepOptIn ? authorizationState(for: sleepType) : .notDetermined,
            nutritionWriteBack: preferences.nutritionWriteBackOptIn ? authorizationState(for: nutritionType) : .notDetermined
        )
    }

    private var cycleCategoryType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .menstrualFlow)
    }

    private func makeReadTypes(preferences: LILADomain.DataSyncPreferences) -> Set<HKObjectType> {
        var result: Set<HKObjectType> = []

        if preferences.cycleTrackingOptIn {
            if let menstrualFlow = cycleCategoryType {
                result.insert(menstrualFlow)
            }
            if let basalTemperature = HKObjectType.quantityType(forIdentifier: .basalBodyTemperature) {
                result.insert(basalTemperature)
            }
            if #available(iOS 16.0, *),
               let wristTemperature = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                result.insert(wristTemperature)
            }
        }

        if preferences.workoutsOptIn {
            result.insert(HKObjectType.workoutType())
        }

        if preferences.hrvAndRecoveryOptIn {
            if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
                result.insert(hrv)
            }
            if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
                result.insert(restingHR)
            }
        }

        if preferences.sleepOptIn,
           let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            result.insert(sleep)
        }

        return result
    }

    private func makeShareTypes(preferences: LILADomain.DataSyncPreferences) -> Set<HKSampleType> {
        guard preferences.nutritionWriteBackOptIn else { return [] }

        let candidates: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryFiber,
            .dietaryCaffeine
        ]

        return Set(candidates.compactMap(HKObjectType.quantityType(forIdentifier:)))
    }

    private func requestAuthorization(
        toShare shareTypes: Set<HKSampleType>,
        read readTypes: Set<HKObjectType>
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitQueryError.authorizationDenied)
                }
            }
        }
    }

    private func save(_ samples: [HKSample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitQueryError.saveFailed)
                }
            }
        }
    }

    private func fetchCycleStateIfAuthorized(
        preferences: LILADomain.DataSyncPreferences
    ) async -> LILADomain.CycleState? {
        guard preferences.cycleTrackingOptIn,
              let menstrualFlow = cycleCategoryType,
              authorizationState(for: menstrualFlow) == .sharingAuthorized else {
            return nil
        }

        let start = calendar.date(byAdding: .day, value: -90, to: .now) ?? .now
        let samples = await categorySamples(for: menstrualFlow, since: start)
        guard let latestFlow = samples.sorted(by: { $0.startDate > $1.startDate }).first else {
            return nil
        }

        return LILADomain.CycleState(
            lastPeriodStart: latestFlow.startDate,
            averageCycleLength: 28,
            averagePeriodLength: 5,
            trackedSymptoms: [],
            source: .appleHealth
        )
    }

    private func fetchTrainingLoadIfAuthorized(
        preferences: LILADomain.DataSyncPreferences
    ) async -> LILADomain.WeeklyTrainingLoad? {
        guard preferences.workoutsOptIn,
              authorizationState(for: HKObjectType.workoutType()) == .sharingAuthorized else {
            return nil
        }

        let start = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let workouts = await workoutSamples(since: start)
        guard !workouts.isEmpty else { return nil }

        let activeEnergy = workouts.reduce(0.0) { partial, workout in
            partial + (workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
        }
        let durationMinutes = Int(workouts.reduce(0.0) { $0 + $1.duration } / 60.0)

        return LILADomain.WeeklyTrainingLoad(
            workoutsCount: workouts.count,
            activeEnergyBurnedKcal: activeEnergy > 0 ? activeEnergy : nil,
            durationMinutes: durationMinutes,
            lastWorkoutEndedAt: workouts.max(by: { $0.endDate < $1.endDate })?.endDate
        )
    }

    private func fetchSleepHoursIfAuthorized(
        preferences: LILADomain.DataSyncPreferences
    ) async -> Double? {
        guard preferences.sleepOptIn,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              authorizationState(for: sleepType) == .sharingAuthorized else {
            return nil
        }

        let start = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now
        let samples = await categorySamples(for: sleepType, since: start)
        let asleepValues = Set([
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue
        ])

        let totalSeconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

        return totalSeconds > 0 ? totalSeconds / 3600.0 : nil
    }

    private func fetchHRVIfAuthorized(
        preferences: LILADomain.DataSyncPreferences
    ) async -> Double? {
        guard preferences.hrvAndRecoveryOptIn,
              let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              authorizationState(for: type) == .sharingAuthorized else {
            return nil
        }

        return await latestQuantityValue(for: type, unit: .secondUnit(with: .milli))
    }

    private func fetchRestingHeartRateIfAuthorized(
        preferences: LILADomain.DataSyncPreferences
    ) async -> Double? {
        guard preferences.hrvAndRecoveryOptIn,
              let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              authorizationState(for: type) == .sharingAuthorized else {
            return nil
        }

        return await latestQuantityValue(
            for: type,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
    }

    private func fetchWristTemperatureIfAuthorized(
        preferences: LILADomain.DataSyncPreferences
    ) async -> Double? {
        guard preferences.cycleTrackingOptIn else { return nil }
        guard #available(iOS 16.0, *) else { return nil }
        guard let type = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature),
              authorizationState(for: type) == .sharingAuthorized else {
            return nil
        }

        return await latestQuantityValue(for: type, unit: .degreeCelsius())
    }

    private func latestQuantityValue(for type: HKQuantityType, unit: HKUnit) async -> Double? {
        let samples = await quantitySamples(for: type, limit: 1)
        return samples.first?.quantity.doubleValue(for: unit)
    }

    private func quantitySample(
        identifier: HKQuantityTypeIdentifier,
        value: Double,
        unit: HKUnit,
        date: Date
    ) -> HKQuantitySample? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: value), start: date, end: date)
    }

    private func authorizationState(for objectType: HKObjectType?) -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return HealthAuthorizationState.unavailable }
        guard let objectType else { return HealthAuthorizationState.unavailable }

        switch healthStore.authorizationStatus(for: objectType) {
        case .notDetermined:
            return HealthAuthorizationState.notDetermined
        case .sharingDenied:
            return HealthAuthorizationState.sharingDenied
        case .sharingAuthorized:
            return HealthAuthorizationState.sharingAuthorized
        @unknown default:
            return HealthAuthorizationState.notDetermined
        }
    }

    private func quantitySamples(for type: HKQuantityType, limit: Int) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                continuation.resume(returning: results as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func categorySamples(for type: HKCategoryType, since start: Date) async -> [HKCategorySample] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                continuation.resume(returning: results as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func workoutSamples(since start: Date) async -> [HKWorkout] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                continuation.resume(returning: results as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }
    }
}

private enum HealthKitQueryError: Error {
    case authorizationDenied
    case saveFailed
}
#endif
