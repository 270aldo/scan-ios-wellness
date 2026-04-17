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


class AnalyzeProductRequest(ContractModel):
    input: ScanInput
    userContext: UserContext
    installID: str


class AnalyzeProductResponse(ContractModel):
    analysis: ScanAnalysis


class AnalyzeStructuredScanRequest(ContractModel):
    input: ScanInput
    profile: UserProfile
    recentScans: list[ScanEvent]
    recentCheckIns: list[CheckInEvent]
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


def fixture_payload(data: ContractModel) -> dict[str, Any]:
    return data.model_dump(by_alias=True, mode="json")
