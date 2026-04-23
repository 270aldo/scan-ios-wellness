import Foundation

enum OnboardingStep: Int, Codable, CaseIterable, Hashable, Identifiable {
    case goals
    case frictions
    case routine
    case priorities
    case consent
    case summary

    var id: Int { rawValue }

    var number: Int { rawValue + 1 }

    var isSkippable: Bool {
        switch self {
        case .goals, .consent, .summary:
            false
        case .frictions, .routine, .priorities:
            true
        }
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}

enum OnboardingExitDestination: String, Codable, CaseIterable, Hashable, Identifiable {
    case scan
    case checkIn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scan:
            "Start with your first scan"
        case .checkIn:
            "Log your first check-in"
        }
    }

    var subtitle: String {
        switch self {
        case .scan:
            "Go straight to a real product, meal, or menu decision."
        case .checkIn:
            "Capture a body signal first so Home has context immediately."
        }
    }

    var tab: AppTab {
        switch self {
        case .scan:
            .scan
        case .checkIn:
            .checkIn
        }
    }
}

struct StrategistProfileFormData: Codable, Hashable {
    var goals: [UserGoal]
    var frictions: [UserFriction]
    var sensitivities: [SensitivityFlag]
    var skinConcerns: [SkinConcern]
    var nutritionPriorities: [DailyNutritionPriority]
    var dietStyle: DietStyle
    var lifeStage: LifeStage
    var guidanceStyle: GuidanceStyle
    var eatingRhythm: EatingRhythm
    var supplementStyle: SupplementRoutineStyle
    var ageRange: AgeRange
    var restaurantFrequency: RestaurantFrequency
    var memoryEnabled: Bool
    var optInCycleAware: Bool
    var aiProcessingConsent: Bool
    var analyticsConsent: Bool
    var notificationsConsent: Bool

    static let starter = StrategistProfileFormData(profile: .starter)

    init(
        goals: [UserGoal],
        frictions: [UserFriction],
        sensitivities: [SensitivityFlag],
        skinConcerns: [SkinConcern],
        nutritionPriorities: [DailyNutritionPriority],
        dietStyle: DietStyle,
        lifeStage: LifeStage,
        guidanceStyle: GuidanceStyle,
        eatingRhythm: EatingRhythm,
        supplementStyle: SupplementRoutineStyle,
        ageRange: AgeRange,
        restaurantFrequency: RestaurantFrequency,
        memoryEnabled: Bool,
        optInCycleAware: Bool,
        aiProcessingConsent: Bool,
        analyticsConsent: Bool,
        notificationsConsent: Bool
    ) {
        self.goals = goals
        self.frictions = frictions
        self.sensitivities = sensitivities
        self.skinConcerns = skinConcerns
        self.nutritionPriorities = nutritionPriorities
        self.dietStyle = dietStyle
        self.lifeStage = lifeStage
        self.guidanceStyle = guidanceStyle
        self.eatingRhythm = eatingRhythm
        self.supplementStyle = supplementStyle
        self.ageRange = ageRange
        self.restaurantFrequency = restaurantFrequency
        self.memoryEnabled = memoryEnabled
        self.optInCycleAware = optInCycleAware
        self.aiProcessingConsent = aiProcessingConsent
        self.analyticsConsent = analyticsConsent
        self.notificationsConsent = notificationsConsent
    }

    init(profile: UserProfile) {
        self.init(
            goals: profile.userContext.goals,
            frictions: profile.frictions,
            sensitivities: profile.userContext.sensitivities,
            skinConcerns: profile.userContext.skinConcerns,
            nutritionPriorities: profile.nutritionPriorities,
            dietStyle: profile.userContext.dietStyle,
            lifeStage: profile.userContext.lifeStage,
            guidanceStyle: profile.guidanceStyle,
            eatingRhythm: profile.eatingRhythm,
            supplementStyle: profile.supplementStyle,
            ageRange: profile.ageRange,
            restaurantFrequency: profile.restaurantFrequency,
            memoryEnabled: profile.memoryEnabled,
            optInCycleAware: profile.userContext.optInCycleAware,
            aiProcessingConsent: profile.consentFlags.aiProcessing,
            analyticsConsent: profile.consentFlags.analytics,
            notificationsConsent: profile.consentFlags.notifications
        )
    }

    func makeProfile(createdAt: Date) -> UserProfile {
        UserProfile(
            userContext: UserContext(
                goals: orderedSelection(goals, using: UserGoal.allCases),
                sensitivities: orderedSelection(sensitivities, using: SensitivityFlag.allCases),
                dietStyle: dietStyle,
                skinConcerns: orderedSelection(skinConcerns, using: SkinConcern.allCases),
                lifeStage: lifeStage,
                optInCycleAware: optInCycleAware
            ),
            frictions: orderedSelection(frictions, using: UserFriction.allCases),
            guidanceStyle: guidanceStyle,
            eatingRhythm: eatingRhythm,
            supplementStyle: supplementStyle,
            memoryEnabled: memoryEnabled,
            ageRange: ageRange,
            restaurantFrequency: restaurantFrequency,
            nutritionPriorities: orderedSelection(
                nutritionPriorities.isEmpty ? [.energy] : nutritionPriorities,
                using: DailyNutritionPriority.allCases
            ),
            consentFlags: ConsentFlags(
                aiProcessing: aiProcessingConsent,
                analytics: analyticsConsent,
                notifications: notificationsConsent,
                healthDataProcessing: true
            ),
            createdAt: createdAt
        )
    }
}

struct OnboardingDraft: Codable, Hashable {
    var currentStep: OnboardingStep
    var formData: StrategistProfileFormData
    var createdAt: Date
    var lastUpdatedAt: Date

    init(
        currentStep: OnboardingStep = .goals,
        formData: StrategistProfileFormData = .starter,
        createdAt: Date = .now,
        lastUpdatedAt: Date = .now
    ) {
        self.currentStep = currentStep
        self.formData = formData
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }

    init(profile: UserProfile, currentStep: OnboardingStep = .goals, lastUpdatedAt: Date = .now) {
        self.init(
            currentStep: currentStep,
            formData: StrategistProfileFormData(profile: profile),
            createdAt: profile.createdAt,
            lastUpdatedAt: lastUpdatedAt
        )
    }

    mutating func touch(now: Date = .now) {
        lastUpdatedAt = now
    }
}

private func orderedSelection<T>(_ values: [T], using orderedValues: T.AllCases) -> [T]
where T: CaseIterable & Hashable, T.AllCases: Collection, T.AllCases.Element == T {
    let selected = Set(values)
    return orderedValues.filter { selected.contains($0) }
}
