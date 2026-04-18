from __future__ import annotations

from enum import Enum
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
