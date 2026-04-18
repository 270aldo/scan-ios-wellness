from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
import logging

from pydantic_settings import BaseSettings, SettingsConfigDict

from app.contracts import (
    AdvicePriority,
    CoachReply,
    CoachReplyRequest,
    ScanVerdict,
    ScanVerdictConfidence,
    ScanVerdictRequest,
    StrategistAdviceCard,
    StrategistReply,
    StrategistReplyRequest,
)
from app.coach_runtime import (
    CoachSchemaValidationError,
    build_coach_context_prompt,
    build_coach_task_prompt,
    build_local_coach_reply,
    get_coach_assets,
)
from app.scan_verdict_runtime import (
    ScanVerdictSchemaValidationError,
    build_local_scan_verdict,
    build_scan_verdict_task_prompt,
    get_scan_verdict_assets,
)

logger = logging.getLogger(__name__)


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
    vertex_temperature: float = 0.2
    vertex_max_output_tokens: int = 2048
    vertex_seed: int = 7
    scan_assets_dir: str | None = None
    coach_assets_dir: str | None = None
    coach_vertex_temperature: float = 0.5
    coach_vertex_seed: int = 11
    coach_vertex_max_output_tokens: int = 1024


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

    def verdict(self, request: ScanVerdictRequest) -> ScanVerdict:
        assets = get_scan_verdict_assets(self.settings.scan_assets_dir)
        if self.settings.provider == "vertex":
            try:
                return self._vertex_verdict(request, assets)
            except Exception as exc:
                logger.warning("scan verdict provider failed; falling back to local runtime: %s", exc)
                return build_local_scan_verdict(
                    request,
                    assets=assets,
                    provider_failure=str(exc),
                )
        return build_local_scan_verdict(request, assets=assets)

    def coach_reply(self, request: CoachReplyRequest) -> CoachReply:
        assets = get_coach_assets(self.settings.coach_assets_dir)
        if self.settings.provider == "vertex":
            try:
                return self._vertex_coach_reply(request, assets)
            except Exception as exc:
                logger.warning("coach reply provider failed; falling back to local runtime: %s", exc)
                return build_local_coach_reply(
                    request,
                    assets=assets,
                    provider_failure=str(exc),
                )
        return build_local_coach_reply(request, assets=assets)

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

    def _vertex_verdict(self, request: ScanVerdictRequest, assets) -> ScanVerdict:
        if not self.settings.vertex_project:
            raise RuntimeError("WELLNESSLENS_AGENT_VERTEX_PROJECT is not configured")

        try:
            from google import genai
            from google.genai import types
        except ImportError as exc:
            raise RuntimeError("google-genai is not installed") from exc

        client = genai.Client(
            vertexai=True,
            project=self.settings.vertex_project,
            location=self.settings.vertex_location,
            http_options=types.HttpOptions(apiVersion="v1"),
        )
        response = client.models.generate_content(
            model=self.settings.vertex_model,
            contents=build_scan_verdict_task_prompt(request),
            config=types.GenerateContentConfig(
                systemInstruction=assets.system_prompt,
                responseMimeType="application/json",
                responseJsonSchema=assets.vertex_response_json_schema,
                temperature=self.settings.vertex_temperature,
                maxOutputTokens=self.settings.vertex_max_output_tokens,
                seed=self.settings.vertex_seed,
            ),
        )
        if isinstance(getattr(response, "parsed", None), dict):
            payload = assets.validate_payload(response.parsed)
            return ScanVerdict.model_validate(payload)

        response_text = (getattr(response, "text", "") or "").strip()
        if not response_text:
            raise RuntimeError("vertex returned an empty response")
        try:
            payload = assets.parse_payload_text(response_text)
        except ScanVerdictSchemaValidationError as exc:
            raise RuntimeError(f"vertex payload failed schema validation: {exc}") from exc
        return ScanVerdict.model_validate(payload)

    def _vertex_coach_reply(self, request: CoachReplyRequest, assets) -> CoachReply:
        if not self.settings.vertex_project:
            raise RuntimeError("WELLNESSLENS_AGENT_VERTEX_PROJECT is not configured")

        try:
            from google import genai
            from google.genai import types
        except ImportError as exc:
            raise RuntimeError("google-genai is not installed") from exc

        client = genai.Client(
            vertexai=True,
            project=self.settings.vertex_project,
            location=self.settings.vertex_location,
            http_options=types.HttpOptions(apiVersion="v1"),
        )
        response = client.models.generate_content(
            model=self.settings.vertex_model,
            contents=build_coach_context_prompt(request) + "\n\n" + build_coach_task_prompt(request),
            config=types.GenerateContentConfig(
                systemInstruction=assets.system_prompt,
                responseMimeType="application/json",
                responseJsonSchema=assets.vertex_response_json_schema,
                temperature=self.settings.coach_vertex_temperature,
                maxOutputTokens=self.settings.coach_vertex_max_output_tokens,
                seed=self.settings.coach_vertex_seed,
            ),
        )
        if isinstance(getattr(response, "parsed", None), dict):
            payload = assets.validate_payload(response.parsed)
            return CoachReply.model_validate(payload)

        response_text = (getattr(response, "text", "") or "").strip()
        if not response_text:
            raise RuntimeError("vertex returned an empty coach response")
        try:
            payload = assets.parse_payload_text(response_text)
        except CoachSchemaValidationError as exc:
            raise RuntimeError(f"vertex coach payload failed schema validation: {exc}") from exc
        return CoachReply.model_validate(payload)
