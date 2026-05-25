from __future__ import annotations

from enum import Enum
from typing import Any
from uuid import uuid4

from pydantic import BaseModel, ConfigDict, Field

from app.date_utils import apple_timestamp_now


def contract_id(prefix: str | None = None) -> str:
    raw = str(uuid4())
    return f"{prefix}-{raw}" if prefix else raw


class ContractModel(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        extra="forbid",
    )


AppleTimestamp = float


class ProductType(str, Enum):
    food = "food"
    supplement = "supplement"
    skincare = "skincare"
    haircare = "haircare"
    personalCare = "personalCare"


class ScanSource(str, Enum):
    liveBarcode = "liveBarcode"
    manualBarcode = "manualBarcode"
    labelPhoto = "labelPhoto"
    mealPhoto = "mealPhoto"
    menuPhoto = "menuPhoto"
    manualLabel = "manualLabel"


class ScanCyclePhase(str, Enum):
    menstrual = "menstrual"
    follicular = "follicular"
    ovulatory = "ovulatory"
    luteal = "luteal"


class WellnessLensKind(str, Enum):
    glowSkin = "glowSkin"
    hormoneBalance = "hormoneBalance"
    gutComfort = "gutComfort"
    energyMood = "energyMood"
    bodyCompositionStrength = "bodyCompositionStrength"


class ConfidenceLevel(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"


class UserGoal(str, Enum):
    clearSkin = "clearSkin"
    steadyEnergy = "steadyEnergy"
    gutCalm = "gutCalm"
    hormoneSupport = "hormoneSupport"
    leanStrength = "leanStrength"
    deBloat = "deBloat"


class SensitivityFlag(str, Enum):
    fragranceSensitive = "fragranceSensitive"
    caffeineSensitive = "caffeineSensitive"
    sugarSensitive = "sugarSensitive"
    acneProne = "acneProne"
    drySkin = "drySkin"
    reactiveDigestion = "reactiveDigestion"


class DietStyle(str, Enum):
    omnivore = "omnivore"
    pescatarian = "pescatarian"
    vegetarian = "vegetarian"
    dairyLight = "dairyLight"
    highProtein = "highProtein"
    flexitarian = "flexitarian"


class SkinConcern(str, Enum):
    blemishes = "blemishes"
    sensitivity = "sensitivity"
    dullness = "dullness"
    dryness = "dryness"
    texture = "texture"


class LifeStage(str, Enum):
    everyDay = "everyDay"
    highStress = "highStress"
    postpartumAware = "postpartumAware"
    perimenopauseAware = "perimenopauseAware"


class IngredientTag(str, Enum):
    proteinDense = "proteinDense"
    probiotic = "probiotic"
    fiberSupport = "fiberSupport"
    sugarSpike = "sugarSpike"
    sugarAlcohol = "sugarAlcohol"
    stimulant = "stimulant"
    ultraProcessed = "ultraProcessed"
    collagen = "collagen"
    omegaSupport = "omegaSupport"
    niacinamide = "niacinamide"
    peptide = "peptide"
    hyaluronicAcid = "hyaluronicAcid"
    retinoid = "retinoid"
    fragrance = "fragrance"
    alcoholDrying = "alcoholDrying"
    harshSurfactants = "harshSurfactants"
    mineralSPF = "mineralSPF"
    antioxidantBlend = "antioxidantBlend"
    emulsifierHeavy = "emulsifierHeavy"


class UserContext(ContractModel):
    goals: list[UserGoal]
    sensitivities: list[SensitivityFlag]
    dietStyle: DietStyle
    skinConcerns: list[SkinConcern]
    lifeStage: LifeStage
    optInCycleAware: bool


class Ingredient(ContractModel):
    name: str


class ProductResolutionSource(str, Enum):
    openFoodFacts = "openFoodFacts"
    usdaFoodDataCentral = "usdaFoodDataCentral"
    nihDSLD = "nihDSLD"
    cosing = "cosing"
    localCatalog = "localCatalog"
    agentInferred = "agentInferred"
    userProvided = "userProvided"
    userEdited = "userEdited"


class ProductResolutionSemantic(str, Enum):
    canonical = "canonical"
    provisional = "provisional"
    directional = "directional"
    providerBacked = "provider_backed"
    lowConfidence = "low_confidence"


class NutritionSnapshot(ContractModel):
    energyKcalPer100g: float | None = Field(default=None, alias="energy_kcal_per_100g")
    proteinGPer100g: float | None = Field(default=None, alias="protein_g_per_100g")
    carbsGPer100g: float | None = Field(default=None, alias="carbs_g_per_100g")
    fatGPer100g: float | None = Field(default=None, alias="fat_g_per_100g")
    sugarsGPer100g: float | None = Field(default=None, alias="sugars_g_per_100g")
    fiberGPer100g: float | None = Field(default=None, alias="fiber_g_per_100g")
    sodiumMgPer100g: float | None = Field(default=None, alias="sodium_mg_per_100g")
    caffeineMgPer100g: float | None = Field(default=None, alias="caffeine_mg_per_100g")
    novaGroup: int | None = Field(default=None, alias="nova_group")


class MexicoWarningLabel(str, Enum):
    excessCalories = "excess_calories"
    excessSugars = "excess_sugars"
    excessSodium = "excess_sodium"
    excessSaturatedFat = "excess_saturated_fat"
    excessTransFat = "excess_trans_fat"


class MexicoNutritionSignals(ContractModel):
    warningLabels: list[MexicoWarningLabel] = Field(default_factory=list, alias="warning_labels")
    containsCaffeineWarning: bool = Field(default=False, alias="contains_caffeine_warning")
    containsSweetenerWarning: bool = Field(default=False, alias="contains_sweetener_warning")
    detectedPhrases: list[str] = Field(default_factory=list, alias="detected_phrases")
    source: str = "deterministic"

    @property
    def has_signal(self) -> bool:
        return bool(self.warningLabels or self.containsCaffeineWarning or self.containsSweetenerWarning or self.detectedPhrases)


class ProductResolution(ContractModel):
    canonicalProductID: str | None = Field(default=None, alias="canonical_product_id")
    source: ProductResolutionSource
    confidence: float = Field(ge=0, le=1)
    nutritionSnapshot: NutritionSnapshot | None = Field(default=None, alias="nutrition_snapshot")
    isDirectional: bool = Field(default=False, alias="is_directional")


class ProductCandidate(ContractModel):
    id: str
    name: str
    brand: str
    productType: ProductType
    barcode: str | None = None
    headline: str
    ingredients: list[Ingredient]
    claims: list[str]
    tags: list[IngredientTag]
    alternativeIDs: list[str]
    notes: list[str]
    lookupTokens: list[str]
    resolution: ProductResolution | None = None
    resolutionSemantics: list[ProductResolutionSemantic] | None = Field(default=None, alias="resolution_semantics")
    mexicoNutritionSignals: MexicoNutritionSignals | None = Field(default=None, alias="mexico_nutrition_signals")


class LensScore(ContractModel):
    lens: WellnessLensKind
    score: int
    summary: str


class ReasonImpact(str, Enum):
    positive = "positive"
    caution = "caution"
    neutral = "neutral"


class ReasonItem(ContractModel):
    id: str = Field(default_factory=contract_id)
    title: str
    detail: str
    impact: ReasonImpact


class AlternativeSuggestion(ContractModel):
    id: str
    productName: str
    productID: str
    whyBetter: str
    improvedLenses: list[WellnessLensKind]


class ScanAnalysis(ContractModel):
    id: str = Field(default_factory=contract_id)
    createdAt: AppleTimestamp = Field(default_factory=apple_timestamp_now)
    resolvedProduct: ProductCandidate
    source: ScanSource
    productType: ProductType
    lensScores: list[LensScore]
    overallSummary: str
    topReasons: list[ReasonItem]
    warnings: list[str]
    alternatives: list[AlternativeSuggestion]
    confidence: ConfidenceLevel
    disclaimer: str


class CheckInEntry(ContractModel):
    id: str = Field(default_factory=contract_id)
    createdAt: AppleTimestamp = Field(default_factory=apple_timestamp_now)
    energy: int
    skin: int
    bloatingRelief: int
    cravingControl: int
    mood: int
    note: str


class WeeklyInsight(ContractModel):
    id: str = Field(default_factory=contract_id)
    title: str
    summary: str
    callToAction: str


class AgeRange(str, Enum):
    twenties = "20-29"
    thirties = "30-39"
    forties = "40-49"
    fiftiesPlus = "50+"


class RestaurantFrequency(str, Enum):
    mostlyHome = "mostlyHome"
    balanced = "balanced"
    oftenOut = "oftenOut"


class DailyNutritionPriority(str, Enum):
    energy = "energy"
    digestion = "digestion"
    skin = "skin"
    hormones = "hormones"
    bodyComposition = "bodyComposition"


class ConsentFlags(ContractModel):
    aiProcessing: bool
    analytics: bool
    notifications: bool
    healthDataProcessing: bool


class UserLifecycleState(str, Enum):
    unonboarded = "unonboarded"
    calibrating = "calibrating"
    active = "active"
    drifting = "drifting"
    reengagement = "reengagement"


class GuidanceStyle(str, Enum):
    calmAndDirect = "calmAndDirect"
    warmAndEncouraging = "warmAndEncouraging"
    strategicAndPrecise = "strategicAndPrecise"


class UserFriction(str, Enum):
    energyCrash = "energyCrash"
    bloating = "bloating"
    cravings = "cravings"
    supplementConfusion = "supplementConfusion"
    inconsistentMeals = "inconsistentMeals"
    reactiveSkin = "reactiveSkin"
    stressSnacking = "stressSnacking"


class EatingRhythm(str, Enum):
    structured = "structured"
    flexible = "flexible"
    onTheGo = "onTheGo"
    eveningHeavy = "eveningHeavy"


class SupplementRoutineStyle(str, Enum):
    none = "none"
    simple = "simple"
    stacked = "stacked"
    inconsistent = "inconsistent"


class GoalStatus(str, Enum):
    active = "active"
    holding = "holding"
    won = "won"


class RecommendationKind(str, Enum):
    scanStaple = "scanStaple"
    checkInNow = "checkInNow"
    swapProduct = "swapProduct"
    askStrategist = "askStrategist"
    repeatProduct = "repeatProduct"
    tidyRoutine = "tidyRoutine"


class ScanDecisionKind(str, Enum):
    saveToRoutine = "saveToRoutine"
    avoidForNow = "avoidForNow"
    swapInstead = "swapInstead"
    askStrategist = "askStrategist"
    trackAgain = "trackAgain"


class MemoryItemKind(str, Enum):
    staple = "staple"
    avoid = "avoid"
    strategistTakeaway = "strategistTakeaway"
    checkInPattern = "checkInPattern"
    scanDecision = "scanDecision"
    experimentWin = "experimentWin"
    experimentCaution = "experimentCaution"
    routineNote = "routineNote"


class SignalTone(str, Enum):
    supportive = "supportive"
    caution = "caution"
    neutral = "neutral"


class UserProfile(ContractModel):
    userContext: UserContext
    frictions: list[UserFriction]
    guidanceStyle: GuidanceStyle
    eatingRhythm: EatingRhythm
    supplementStyle: SupplementRoutineStyle
    memoryEnabled: bool
    ageRange: AgeRange
    restaurantFrequency: RestaurantFrequency
    nutritionPriorities: list[DailyNutritionPriority]
    consentFlags: ConsentFlags
    createdAt: AppleTimestamp


class GoalMilestone(ContractModel):
    id: str = Field(default_factory=contract_id)
    title: str
    detail: str
    progressHint: str


class ActiveGoal(ContractModel):
    id: str = Field(default_factory=contract_id)
    goal: UserGoal
    title: str
    summary: str
    status: GoalStatus
    focusMetric: str
    currentSignalSummary: str
    milestone: GoalMilestone


class FirstWeekPlanStep(ContractModel):
    id: str = Field(default_factory=contract_id)
    title: str
    detail: str
    isComplete: bool = False


class FirstWeekPlan(ContractModel):
    title: str
    summary: str
    steps: list[FirstWeekPlanStep]


class Recommendation(ContractModel):
    id: str
    kind: RecommendationKind
    title: str
    summary: str
    cta: str
    relatedProductID: str | None = None
    relatedGoal: UserGoal | None = None


class RoutineItem(ContractModel):
    id: str = Field(default_factory=contract_id)
    productID: str
    productName: str
    cadenceSummary: str
    note: str
    createdAt: AppleTimestamp = Field(default_factory=apple_timestamp_now)


class ScanDecision(ContractModel):
    id: str = Field(default_factory=contract_id)
    createdAt: AppleTimestamp = Field(default_factory=apple_timestamp_now)
    productID: str
    productName: str
    kind: ScanDecisionKind
    note: str
    relatedGoal: UserGoal | None = None
    resolvedAt: AppleTimestamp | None = None


class CheckInSignal(ContractModel):
    id: str = Field(default_factory=contract_id)
    title: str
    summary: str
    tone: SignalTone


class MemoryItem(ContractModel):
    id: str = Field(default_factory=contract_id)
    kind: MemoryItemKind
    title: str
    summary: str
    relatedProductID: str | None = None
    relatedProductName: str | None = None
    createdAt: AppleTimestamp = Field(default_factory=apple_timestamp_now)
    lastReferencedAt: AppleTimestamp = Field(default_factory=apple_timestamp_now)


class TodayFocus(ContractModel):
    title: str
    summary: str


class OpenLoop(ContractModel):
    id: str = Field(default_factory=contract_id)
    title: str
    summary: str


class StrategistNote(ContractModel):
    title: str
    summary: str


class RecentWin(ContractModel):
    id: str = Field(default_factory=contract_id)
    title: str
    summary: str


class DailyHomePayload(ContractModel):
    state: UserLifecycleState
    todayFocus: TodayFocus
    bodySignal: CheckInSignal
    nextAction: Recommendation
    recommendedSwap: AlternativeSuggestion | None = None
    openLoops: list[OpenLoop]
    strategistNote: StrategistNote
    recentWins: list[RecentWin]


class AnalysisInputType(str, Enum):
    barcode = "barcode"
    labelPhoto = "label_photo"
    mealPhoto = "meal_photo"
    menuPhoto = "menu_photo"
    manual = "manual"


class AnalysisEntityType(str, Enum):
    product = "product"
    meal = "meal"
    menuItem = "menu_item"
    supplement = "supplement"


class AnalysisVerdict(str, Enum):
    good = "good"
    adjust = "adjust"
    avoid = "avoid"
    needsMoreInfo = "needs_more_info"


class SwapPriority(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"


class StructuredLensScores(ContractModel):
    skin: int
    hormones: int
    gut: int
    energy: int
    bodyComp: int = Field(alias="body_comp")


class SwapSuggestion(ContractModel):
    id: str = Field(default_factory=contract_id)
    title: str
    reason: str
    priority: SwapPriority


class SafetyRiskLevel(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class MedicalSafety(ContractModel):
    isMedicalAdvice: bool = Field(alias="is_medical_advice")
    disclaimerNeeded: bool = Field(alias="disclaimer_needed")
    riskLevel: SafetyRiskLevel = Field(alias="risk_level")


class PatternContext(ContractModel):
    usedHistory: bool = Field(alias="used_history")
    relevantPattern: str | None = Field(default=None, alias="relevant_pattern")


class AnalysisEnvelope(ContractModel):
    analysisID: str = Field(alias="analysis_id")
    timestamp: AppleTimestamp
    inputType: AnalysisInputType = Field(alias="input_type")
    entityType: AnalysisEntityType = Field(alias="entity_type")
    resolvedProduct: ProductCandidate | None = Field(default=None, alias="resolved_product")
    verdict: AnalysisVerdict
    overallScore: int = Field(alias="overall_score")
    lensScores: StructuredLensScores = Field(alias="lens_scores")
    whyToday: list[str] = Field(alias="why_today")
    greenFlags: list[str] = Field(alias="green_flags")
    redFlags: list[str] = Field(alias="red_flags")
    recommendedActions: list[str] = Field(alias="recommended_actions")
    swapSuggestions: list[SwapSuggestion] = Field(alias="swap_suggestions")
    followUpPrompt: str = Field(alias="follow_up_prompt")
    confidence: float
    medicalSafety: MedicalSafety = Field(alias="medical_safety")
    patternContext: PatternContext = Field(alias="pattern_context")


class NormalizedScanPayload(ContractModel):
    source: AnalysisInputType
    entityName: str
    brand: str | None = None
    productType: ProductType | None = None
    ingredients: list[str]
    claims: list[str]
    extractedText: str | None = None
    inferredTags: list[str]
    scanContext: ScanContext | None = Field(default=None, alias="scan_context")


class ScanEvent(ContractModel):
    id: str = Field(alias="scan_id")
    timestamp: AppleTimestamp
    localProfileID: str = Field(alias="local_profile_id")
    inputType: AnalysisInputType = Field(alias="input_type")
    normalizedPayload: NormalizedScanPayload = Field(alias="normalized_payload")
    analysis: AnalysisEnvelope
    legacyAnalysis: ScanAnalysis = Field(alias="legacy_analysis")
    sourceAgents: list[str] = Field(alias="source_agents")
    latencyMs: int = Field(alias="latency_ms")


class CheckInEvent(ContractModel):
    id: str = Field(alias="checkin_id")
    timestamp: AppleTimestamp
    localProfileID: str = Field(alias="local_profile_id")
    linkedScanIDs: list[str] = Field(alias="linked_scan_ids")
    energy: int
    bloating: int
    mood: int
    cravings: int
    skin: int
    satiety: int
    notes: str
    readHelpful: bool | None = Field(default=None, alias="read_helpful")
    legacyEntry: CheckInEntry = Field(alias="legacy_entry")


class FavoriteItem(ContractModel):
    id: str = Field(alias="favorite_id")
    scanEventID: str = Field(alias="scan_event_id")
    relatedProductID: str | None = Field(default=None, alias="related_product_id")
    createdAt: AppleTimestamp = Field(alias="created_at")
    title: str
    summary: str


class HomeSurfaceModule(str, Enum):
    firstWeekPlan = "firstWeekPlan"
    dailyBrief = "dailyBrief"
    activeGoals = "activeGoals"
    recommendedSwap = "recommendedSwap"
    openLoops = "openLoops"
    recentWins = "recentWins"
    strategistNote = "strategistNote"
    routineMemory = "routineMemory"
    pantry = "pantry"
    sampleReads = "sampleReads"


class DailyHomeHeroEmphasis(str, Enum):
    onboarding = "onboarding"
    protectMomentum = "protectMomentum"
    rebuildMomentum = "rebuildMomentum"
    reengage = "reengage"


class HomeModuleSuppressionReason(str, Enum):
    redundantNarrative = "redundantNarrative"
    redundantMemory = "redundantMemory"
    demoOnly = "demoOnly"


class SuppressedHomeModule(ContractModel):
    module: HomeSurfaceModule
    reason: HomeModuleSuppressionReason


class DailyHomeHeroV2(ContractModel):
    emphasis: DailyHomeHeroEmphasis
    whyNow: str


class DailyHomePayloadV2(ContractModel):
    schemaVersion: int = 2
    hero: DailyHomeHeroV2
    primaryModule: HomeSurfaceModule | None = None
    secondaryModules: list[HomeSurfaceModule]
    deferredModules: list[HomeSurfaceModule]
    suppressedModules: list[SuppressedHomeModule]
    ctaPriority: RecommendationKind


class WellnessFeatureFlags(ContractModel):
    newOnboarding: bool = True
    newHome: bool = True
    homeSurfaceV2: bool = True
    strategist: bool = True
    dailyBrief: bool = True
    structuredAnalysis: bool = True
    mealSnapshot: bool = True
    safetyGuard: bool = True
    patternAgent: bool = True
    weeklyInsightV2: bool = True
    menuScanner: bool = True
    pantryMVP: bool = True
    contextualPaywall: bool = True
    entitlementsV2: bool = True


class ClientKillSwitches(ContractModel):
    scanDisabled: bool = False
    strategistDisabled: bool = False
    homeDisabled: bool = False


class ClientConfigResponse(ContractModel):
    environment: str
    minimumSupportedVersion: str
    minimumSupportedBuild: int
    copyVersion: str
    persistenceMode: str
    firebaseAuthEnforced: bool
    appCheckEnforced: bool
    agentProviderMode: str
    flags: WellnessFeatureFlags
    killSwitches: ClientKillSwitches
    updatedAt: AppleTimestamp


class ScanInput(ContractModel):
    sourceType: ScanSource
    barcode: str | None = None
    capturedImageRef: str | None = None
    rawText: str | None = None
    productTypeHint: ProductType | None = None
    locale: str


class ScanContext(ContractModel):
    cyclePhase: ScanCyclePhase | None = Field(default=None, alias="cycle_phase")
    isInAnabolicWindow: bool | None = Field(default=None, alias="is_in_anabolic_window")
    sleepHours: float | None = Field(default=None, alias="sleep_hours")
    hrvMilliseconds: float | None = Field(default=None, alias="hrv_milliseconds")
    restingHeartRate: float | None = Field(default=None, alias="resting_heart_rate")
    wristTemperatureDeltaCelsius: float | None = Field(default=None, alias="wrist_temperature_delta_celsius")


class AnalyzeProductRequest(ContractModel):
    input: ScanInput
    userContext: UserContext
    scanContext: ScanContext | None = Field(default=None, alias="scan_context")
    installID: str


class AnalyzeProductResponse(ContractModel):
    analysis: ScanAnalysis


class AnalyzeStructuredScanRequest(ContractModel):
    input: ScanInput
    profile: UserProfile
    recentScans: list[ScanEvent]
    recentCheckIns: list[CheckInEvent]
    scanContext: ScanContext | None = Field(default=None, alias="scan_context")
    installID: str


class AnalyzeStructuredScanResponse(ContractModel):
    analysis: AnalysisEnvelope


class SaveCheckInRequest(ContractModel):
    checkIn: CheckInEntry
    userContext: UserContext
    installID: str


class SaveCheckInEventRequest(ContractModel):
    event: CheckInEvent
    installID: str


class WeeklyInsightsRequest(ContractModel):
    userContext: UserContext
    installID: str


class WeeklyInsightsResponse(ContractModel):
    insights: list[WeeklyInsight]


class CompleteOnboardingRequest(ContractModel):
    profile: UserProfile
    activeGoals: list[ActiveGoal]
    firstWeekPlan: FirstWeekPlan | None = None
    installID: str


class ProfileSyncRequest(CompleteOnboardingRequest):
    pass


class SaveScanDecisionRequest(ContractModel):
    decision: ScanDecision
    installID: str


class UpsertMemoryRequest(ContractModel):
    memoryItems: list[MemoryItem]
    installID: str


class DailyHomeRequest(ContractModel):
    profile: UserProfile
    activeGoals: list[ActiveGoal]
    installID: str


class DailyHomeResponse(ContractModel):
    payload: DailyHomePayload
    payloadV2: DailyHomePayloadV2 | None = None


class SaveFavoriteItemRequest(ContractModel):
    favorite: FavoriteItem
    installID: str


class HistorySyncRequest(ContractModel):
    installID: str
    scans: list[ScanEvent]
    checkIns: list[CheckInEvent]
    favorites: list[FavoriteItem]
    memoryItems: list[MemoryItem]
    scanDecisions: list[ScanDecision]


class HistorySyncResponse(ContractModel):
    installID: str
    scans: list[ScanEvent]
    checkIns: list[CheckInEvent]
    favorites: list[FavoriteItem]
    memoryItems: list[MemoryItem]
    scanDecisions: list[ScanDecision]
    serverTimestamp: AppleTimestamp


class EmptyResponse(ContractModel):
    ok: bool = True


# --- Subscription receipt reporting --------------------------------------
#
# These contracts carry StoreKit 2 transaction metadata from the iOS client to
# the backend so we have a server-side audit trail of who was granted what and
# when. They deliberately do NOT make the backend the source of truth for
# entitlements yet — iOS still trusts its local StoreKit 2 JWS verification.
# The grant model is ready for a follow-up slice that adds App Store Server
# API verification and uses the grant to authoritatively gate backend-only
# premium features.


class SubscriptionTier(str, Enum):
    free = "free"
    plus = "plus"
    pro = "pro"


class SubscriptionGrantState(str, Enum):
    active = "active"
    expired = "expired"
    revoked = "revoked"
    unknown = "unknown"


class SubscriptionGrant(ContractModel):
    installID: str
    tier: SubscriptionTier
    productID: str
    originalTransactionID: str
    transactionID: str
    purchasedAt: AppleTimestamp
    expiresAt: AppleTimestamp | None = None
    revokedAt: AppleTimestamp | None = None
    state: SubscriptionGrantState
    rawTransactionJWS: str | None = Field(
        default=None,
        description=(
            "Original StoreKit 2 JWS string the client forwarded. Stored for "
            "future signature verification against Apple's x5c certificate "
            "chain. Never returned to the client."
        ),
    )
    updatedAt: AppleTimestamp


class SubscriptionReportRequest(ContractModel):
    installID: str
    productID: str
    originalTransactionID: str
    transactionID: str
    purchasedAt: AppleTimestamp
    expiresAt: AppleTimestamp | None = None
    revokedAt: AppleTimestamp | None = None
    tier: SubscriptionTier
    rawTransactionJWS: str | None = None


class SubscriptionStatusResponse(ContractModel):
    installID: str
    grant: SubscriptionGrant | None = None


class SubscriptionLifecycleNotificationRequest(ContractModel):
    """App Store Server Notifications v2 webhook payload.

    Apple signs the notification with a JWS whose payload is the
    `responseBodyV2DecodedPayload`. We accept the raw signed payload and,
    until full signature verification lands, log it for ops visibility and
    no-op the entitlement path.
    """

    signedPayload: str


def fixture_payload(data: ContractModel) -> dict[str, Any]:
    return data.model_dump(by_alias=True, mode="json")
