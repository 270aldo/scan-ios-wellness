from __future__ import annotations

from enum import Enum
from datetime import datetime
from uuid import uuid4

from pydantic import BaseModel, ConfigDict, Field


def contract_id(prefix: str | None = None) -> str:
    raw = str(uuid4())
    return f"{prefix}-{raw}" if prefix else raw


class ContractModel(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        extra="forbid",
    )


class AdvicePriority(str, Enum):
    primary = "primary"
    supporting = "supporting"
    watchout = "watchout"


class StrategistTone(str, Enum):
    calm_and_direct = "calm_and_direct"
    warm_and_encouraging = "warm_and_encouraging"
    strategic_and_precise = "strategic_and_precise"


class StrategistContextSnapshot(ContractModel):
    activeGoals: list[str]
    recentSignals: list[str]
    recentProducts: list[str]
    openLoops: list[str]
    memorySummaries: list[str]
    weeklyNarrative: str | None = None


class StrategistAdviceCard(ContractModel):
    id: str = Field(default_factory=lambda: contract_id("card"))
    priority: AdvicePriority
    title: str
    summary: str
    action: str


class StrategistReply(ContractModel):
    id: str = Field(default_factory=lambda: contract_id("reply"))
    source: str
    tone: StrategistTone
    summary: str
    whyNow: str
    cards: list[StrategistAdviceCard]
    safetyNotes: list[str]


class StrategistReplyRequest(ContractModel):
    profileSummary: str
    tone: StrategistTone
    userMessage: str
    context: StrategistContextSnapshot


class StrategistReplyResponse(ContractModel):
    reply: StrategistReply


class ScanVerdictFit(str, Enum):
    greatFit = "greatFit"
    goodFit = "goodFit"
    occasional = "occasional"
    skip = "skip"
    unclear = "unclear"


class ScanVerdictConfidence(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"
    insufficient = "insufficient"


class ScanVerdictLens(str, Enum):
    glowAndSkin = "glowAndSkin"
    hormoneBalance = "hormoneBalance"
    gutComfort = "gutComfort"
    energyAndMood = "energyAndMood"
    bodyCompositionAndStrength = "bodyCompositionAndStrength"


class ScanVerdictScoreTrend(str, Enum):
    rising = "rising"
    neutral = "neutral"
    falling = "falling"


class ScanVerdictContextDirection(str, Enum):
    boost = "boost"
    reduce = "reduce"
    neutral = "neutral"


class ScanVerdictWatchoutSeverity(str, Enum):
    gentle = "gentle"
    moderate = "moderate"
    important = "important"


class ScanVerdictPersonalRelevance(str, Enum):
    general = "general"
    personal = "personal"
    clinical = "clinical"


class ScanVerdictFollowUpResponseType(str, Enum):
    intensityScale = "intensityScale"
    symptomsChecklist = "symptomsChecklist"
    openText = "openText"


class ScanVerdictEvidenceTier(str, Enum):
    high = "high"
    emerging = "emerging"
    personalPattern = "personalPattern"


class ScanVerdictContextFactor(ContractModel):
    label: str
    direction: ScanVerdictContextDirection
    explanation: str


class ScanVerdictLensScore(ContractModel):
    lens: ScanVerdictLens
    score: int = Field(ge=0, le=100)
    trend: ScanVerdictScoreTrend
    summary: str
    contextApplied: list[ScanVerdictContextFactor] = Field(default_factory=list)


class ScanVerdictWatchout(ContractModel):
    title: str
    detail: str
    severity: ScanVerdictWatchoutSeverity
    personalRelevance: ScanVerdictPersonalRelevance


class ScanVerdictLensDelta(ContractModel):
    lens: ScanVerdictLens
    estimatedChange: int = Field(ge=-100, le=100)


class ScanVerdictAlternative(ContractModel):
    productName: str
    productID: str | None = None
    brand: str | None = None
    whyBetter: str
    improvedLenses: list[ScanVerdictLens] = Field(default_factory=list)
    expectedLensDeltas: list[ScanVerdictLensDelta] = Field(default_factory=list)


class ScanVerdictFollowUpPrompt(ContractModel):
    triggerAfterHours: int = Field(ge=1, le=24)
    questionText: str
    targetLens: ScanVerdictLens
    expectedResponseType: ScanVerdictFollowUpResponseType


class ScanVerdictDeterministicFactor(ContractModel):
    rule: str
    delta: int = Field(ge=-50, le=50)
    affectedLens: ScanVerdictLens


class ScanVerdictAgentInsight(ContractModel):
    insight: str
    modelUsed: str
    confidenceScore: float = Field(ge=0, le=1)


class ScanVerdictUserHistoryFactor(ContractModel):
    pattern: str
    scansReferenced: int = Field(ge=0)


class ScanVerdictReasoningBreakdown(ContractModel):
    deterministicFactors: list[ScanVerdictDeterministicFactor] = Field(default_factory=list)
    agentInsights: list[ScanVerdictAgentInsight] = Field(default_factory=list)
    userHistoryFactors: list[ScanVerdictUserHistoryFactor] = Field(default_factory=list)
    totalAdjustments: int


class ScanVerdictEvidenceSource(ContractModel):
    title: str
    organization: str
    url: str | None = None
    publishedYear: int | None = None
    tier: ScanVerdictEvidenceTier


class ScanVerdict(ContractModel):
    fit: ScanVerdictFit
    confidence: ScanVerdictConfidence
    headline: str
    primaryReason: str
    lensScores: list[ScanVerdictLensScore]
    watchouts: list[ScanVerdictWatchout]
    betterSwap: ScanVerdictAlternative | None = None
    trackPrompt: ScanVerdictFollowUpPrompt | None = None
    evidenceTier: ScanVerdictEvidenceTier
    reasoningBreakdown: ScanVerdictReasoningBreakdown
    disclaimer: str
    sources: list[ScanVerdictEvidenceSource] = Field(default_factory=list)


class ScanVerdictRequest(ContractModel):
    scanId: str | None = None
    productName: str
    source: str
    userContextSummary: str
    structuredSummary: str | None = None


class ScanVerdictResponse(ContractModel):
    verdict: ScanVerdict


class CoachTone(str, Enum):
    warmDirect = "warmDirect"
    supportive = "supportive"
    cautious = "cautious"
    celebratory = "celebratory"


class CoachEvidenceTier(str, Enum):
    high = "high"
    emerging = "emerging"
    personalPattern = "personalPattern"


class CoachSuggestedActionType(str, Enum):
    scan = "scan"
    check_in = "check_in"
    view_verdict = "view_verdict"
    consult_professional = "consult_professional"
    none = "none"


class CoachSafetyFlag(str, Enum):
    crisis_signal = "crisis_signal"
    ed_guardrail = "ed_guardrail"
    pregnancy_guardrail = "pregnancy_guardrail"
    diabetes_guardrail = "diabetes_guardrail"
    minor_detected = "minor_detected"


class CoachVoiceTag(str, Enum):
    warm = "warm"
    calm = "calm"
    curious = "curious"
    encouraging = "encouraging"
    cautious = "cautious"
    gentle = "gentle"
    confident = "confident"
    playful = "playful"


class CoachSuggestedAction(ContractModel):
    type: CoachSuggestedActionType
    label: str = Field(min_length=1, max_length=40)
    deepLinkHint: str | None = Field(default=None, max_length=80)


class CoachVerdictSummary(ContractModel):
    verdictId: str
    productName: str
    fit: str
    createdAt: datetime


class CoachCheckInEntry(ContractModel):
    date: str
    energy: int = Field(ge=1, le=5)
    bloating: int = Field(ge=1, le=5)
    mood: int = Field(ge=1, le=5)
    note: str | None = Field(default=None, max_length=280)


class CoachThreadTurn(ContractModel):
    role: str
    content: str = Field(max_length=640)
    timestamp: datetime | None = None


class CoachReplyRequest(ContractModel):
    userMessage: str = Field(min_length=1, max_length=2000)
    userContextSummary: str = Field(max_length=2000)
    latestVerdictSummary: CoachVerdictSummary | None = None
    recentVerdictSummaries: list[CoachVerdictSummary] = Field(default_factory=list, max_length=5)
    recentCheckIns: list[CoachCheckInEntry] = Field(default_factory=list, max_length=3)
    memorySummaries: list[str] = Field(default_factory=list, max_length=5)
    patternInsights: list[str] = Field(default_factory=list, max_length=3)
    threadHistory: list[CoachThreadTurn] = Field(default_factory=list, max_length=10)


class CoachReply(ContractModel):
    replyId: str
    createdAt: datetime
    message: str = Field(min_length=1, max_length=560)
    tone: CoachTone
    referencedVerdictId: str | None = None
    referencedVerdictSummary: str | None = Field(default=None, max_length=140)
    referencedPatterns: list[str] = Field(default_factory=list, max_length=3)
    suggestedActions: list[CoachSuggestedAction] = Field(default_factory=list, max_length=3)
    followUpQuestion: str | None = Field(default=None, max_length=160)
    safetyFlags: list[CoachSafetyFlag] = Field(default_factory=list)
    evidenceTier: CoachEvidenceTier
    disclaimer: str = Field(min_length=1)
    voiceTags: list[CoachVoiceTag] | None = Field(default=None, max_length=8)
    voiceDirective: str | None = Field(default=None, max_length=120)
    spokenVersion: str | None = Field(default=None, max_length=640)
