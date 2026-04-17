from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict

from app.contracts import (
    AdvicePriority,
    StrategistAdviceCard,
    StrategistReply,
    StrategistReplyRequest,
)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="WELLNESSLENS_AGENT_",
        extra="ignore",
    )

    env: str = "dev"
    provider: str = "local"
    vertex_model: str = "gemini-2.5-pro"
    vertex_project: str | None = None
    vertex_location: str = "us-central1"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()


@dataclass
class StrategistService:
    settings: Settings

    def reply(self, request: StrategistReplyRequest) -> StrategistReply:
        if self.settings.provider == "vertex":
            return self._vertex_placeholder_reply(request)
        return self._local_reply(request)

    def _local_reply(self, request: StrategistReplyRequest) -> StrategistReply:
        cards = [
            StrategistAdviceCard(
                priority=AdvicePriority.primary,
                title="Protect the next anchor",
                summary="Choose the next scan or meal that keeps momentum instead of chasing variety.",
                action="Scan the next real choice before you default to it.",
            )
        ]
        if request.context.openLoops:
            cards.append(
                StrategistAdviceCard(
                    priority=AdvicePriority.supporting,
                    title="Close one open loop",
                    summary=request.context.openLoops[0],
                    action="Add a check-in so the backend gets a real signal, not just intent.",
                )
            )
        if request.context.memorySummaries:
            cards.append(
                StrategistAdviceCard(
                    priority=AdvicePriority.watchout,
                    title="Respect remembered friction",
                    summary=request.context.memorySummaries[0],
                    action="Keep the next recommendation aligned with the memory you already earned.",
                )
            )

        return StrategistReply(
            source="local-deterministic",
            tone=request.tone,
            summary=f"{request.profileSummary} {request.userMessage}".strip(),
            whyNow="The strategist is prioritizing the shortest path to a stronger next signal.",
            cards=cards,
            safetyNotes=[
                "Consumer wellness guidance only.",
                "Do not use strategist output as medical diagnosis or treatment advice.",
            ],
        )

    def _vertex_placeholder_reply(self, request: StrategistReplyRequest) -> StrategistReply:
        reply = self._local_reply(request)
        reply.source = f"vertex-placeholder:{self.settings.vertex_model}"
        reply.whyNow = (
            "Vertex provider mode is enabled, but this scaffold currently keeps the deterministic reply path "
            "until the structured ADK adapter is wired."
        )
        return reply
