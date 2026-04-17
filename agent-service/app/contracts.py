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
