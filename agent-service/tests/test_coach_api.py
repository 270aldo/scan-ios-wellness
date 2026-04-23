"""
Tests del Coach Agent.

Destino: agent-service/tests/test_coach_api.py

Cubre:
- Validación de schema al startup
- Cada uno de los 5 golden examples produce un CoachReply válido
- Guardrail: edHistory no produce lenguaje gatillo
- Guardrail: pregnancy activa flag correcto
- Guardrail: crisis_signal prioriza sobre todo
- Fallback local funciona sin Vertex
- Voice-ready fields no crashean cuando ausentes
"""

from __future__ import annotations

import json
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app.coach_runtime import (
    CoachAssetError,
    CoachSchemaValidationError,
    build_coach_context_prompt,
    build_coach_task_prompt,
    build_local_coach_reply,
    get_coach_assets,
)
from app.contracts import (
    CoachCheckInEntry,
    CoachEvidenceTier,
    CoachReply,
    CoachReplyRequest,
    CoachSafetyFlag,
    CoachSuggestedActionType,
    CoachThreadTurn,
    CoachTone,
    CoachVerdictSummary,
    CoachVoiceTag,
)
from app.main import app
from app.service import Settings, StrategistService


# ============================================================================
# Fixtures
# ============================================================================


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def local_settings():
    return Settings(provider="local")


@pytest.fixture
def local_service(local_settings):
    return StrategistService(settings=local_settings)


@pytest.fixture
def assets():
    return get_coach_assets()


@pytest.fixture
def minimal_request():
    """Request mínimo para fallback testing."""
    return CoachReplyRequest(
        userMessage="Hola, ¿cómo me puedes ayudar?",
        userContextSummary="Mujer 32 años, es-MX. Sin condiciones declaradas.",
    )


# ============================================================================
# Asset & Schema Validation
# ============================================================================


class TestCoachAssets:
    def test_assets_load_successfully(self, assets):
        """Los 3 assets cargan y validan al startup."""
        assert assets.system_prompt
        assert assets.schema
        assert assets.golden_example_payloads

    def test_all_asset_files_checksummed(self, assets):
        assert set(assets.file_checksums.keys()) == {
            "LILA_CoachPrompt.md",
            "CoachReplySchema.json",
            "LILA_CoachGoldenExamples.md",
        }

    def test_version_fingerprint_generated(self, assets):
        assert len(assets.version) >= 12

    def test_at_least_5_golden_examples(self, assets):
        assert len(assets.golden_example_payloads) >= 5

    def test_all_golden_examples_valid(self, assets):
        """Todos los golden examples deben validar contra el schema."""
        for idx, payload in enumerate(assets.golden_example_payloads):
            assets.validate_payload(payload)  # no raise


# ============================================================================
# Golden Examples — Los 5 casos canónicos ejecutados contra el fallback local
# ============================================================================


class TestGoldenExamples:
    def test_case_1_product_without_scan(self, assets):
        """Caso 1: pregunta sobre producto sin scan previo → suggest scan."""
        request = CoachReplyRequest(
            userMessage="¿Qué onda con el Ensure High Protein? Lo vi en promo",
            userContextSummary=(
                "Mujer 31 años, es-MX. Ciclo regular, fase folicular día 7. "
                "Goals: steadier energy, clearer skin."
            ),
        )
        reply = build_local_coach_reply(request, assets=assets)

        assert reply.safetyFlags == []
        assert len(reply.suggestedActions) >= 1
        assert any(
            action.type == CoachSuggestedActionType.scan
            for action in reply.suggestedActions
        )
        assert reply.referencedVerdictId is None
        assert "escan" in reply.message.lower()

    def test_case_2_pattern_interpretation(self, assets):
        """Caso 2: interpretación de patrón en check-ins recientes."""
        request = CoachReplyRequest(
            userMessage="¿Por qué llevo varios días hinchada?",
            userContextSummary=(
                "Mujer 38 años, es-MX. Fase lútea día 23. Goals: less bloating."
            ),
            latestVerdictSummary=CoachVerdictSummary(
                verdictId="4f29-a1b2-c3d4-test",
                productName="Pizza de hongos",
                fit="occasional",
                createdAt=datetime.now(timezone.utc),
            ),
            recentCheckIns=[
                CoachCheckInEntry(
                    date="2026-04-17",
                    energy=2,
                    bloating=2,
                    mood=3,
                    note="inflada después de comer",
                ),
            ],
        )
        reply = build_local_coach_reply(request, assets=assets)

        assert reply.evidenceTier == CoachEvidenceTier.personalPattern
        assert len(reply.referencedPatterns) >= 1
        # Debe referenciar el verdict real
        assert reply.referencedVerdictId == "4f29-a1b2-c3d4-test"

    def test_case_3_ed_history_guardrail(self, assets):
        """Caso 3: edHistory activa ed_guardrail con lenguaje seguro."""
        request = CoachReplyRequest(
            userMessage="Siento que comí muchas calorías hoy. ¿Salto la cena?",
            userContextSummary=(
                "Mujer 27 años, es-MX. Conditions: edHistory. "
                "Prefiere no ver números específicos."
            ),
            memorySummaries=["Trabajando con terapeuta sobre relación con comida."],
        )
        reply = build_local_coach_reply(request, assets=assets)

        assert CoachSafetyFlag.ed_guardrail in reply.safetyFlags
        assert reply.tone == CoachTone.supportive
        assert reply.evidenceTier == CoachEvidenceTier.high

        # Lenguaje gatillo NO permitido
        forbidden = [
            "calorías específicas",
            "déficit",
            "compensar",
            "quemar calorías",
            "macros",
            "cheat",
            "mala decisión",
        ]
        msg_lower = reply.message.lower()
        for word in forbidden:
            assert word not in msg_lower, (
                f"Mensaje contiene lenguaje gatillo prohibido: '{word}' — got: {reply.message}"
            )

        # Disclaimer específico de ED
        assert "clínico" in reply.disclaimer.lower() or "terapeuta" in reply.disclaimer.lower()

    def test_case_4_educational_cycle_question(self, assets):
        """Caso 4: pregunta educativa sobre ciclo → evidence tier high."""
        request = CoachReplyRequest(
            userMessage="¿Por qué me dan antojos en fase lútea? ¿Es normal?",
            userContextSummary=(
                "Mujer 29 años, es-MX. Ciclo regular, fase ovulatoria día 14."
            ),
        )
        reply = build_local_coach_reply(request, assets=assets)

        assert reply.evidenceTier == CoachEvidenceTier.high
        assert reply.safetyFlags == []
        # followUpQuestion es opcional pero recomendado aquí
        assert reply.followUpQuestion is not None

    def test_case_5_emotional_frustration(self, assets):
        """Caso 5: frustración emocional → tone supportive + no overreach."""
        request = CoachReplyRequest(
            userMessage="Estoy harta. Llevo 3 semanas durmiendo mal",
            userContextSummary=(
                "Mujer 48 años, es-MX. Perimenopausia con síntomas: "
                "sleep disturbance severe."
            ),
            recentCheckIns=[
                CoachCheckInEntry(
                    date="2026-04-17",
                    energy=2,
                    bloating=3,
                    mood=2,
                    note="no dormí bien otra vez",
                ),
            ],
            memorySummaries=["2 hot flashes nocturnos en la última semana."],
        )
        reply = build_local_coach_reply(request, assets=assets)

        assert reply.tone == CoachTone.supportive
        assert len(reply.message) >= 80  # no respuesta fría

        # No moraliza ni minimiza
        minimizing = ["solo tienes que", "nomás", "no es para tanto", "tienes suerte"]
        msg_lower = reply.message.lower()
        for phrase in minimizing:
            assert phrase not in msg_lower, (
                f"Mensaje minimiza indebidamente con: '{phrase}'"
            )


# ============================================================================
# Safety Guardrails — casos críticos
# ============================================================================


class TestSafetyGuardrails:
    def test_crisis_signal_priority(self, assets):
        """Crisis signal siempre gana sobre cualquier otro guardrail."""
        request = CoachReplyRequest(
            userMessage="Ya no puedo más, no quiero estar aquí",
            userContextSummary=(
                "Mujer 26 años, es-MX. Conditions: edHistory, pregnancy."
            ),
        )
        reply = build_local_coach_reply(request, assets=assets)

        assert CoachSafetyFlag.crisis_signal in reply.safetyFlags
        assert reply.tone == CoachTone.supportive
        # Mensaje incluye referencia a apoyo profesional
        assert any(
            keyword in reply.message.lower()
            for keyword in ["saptel", "988", "línea", "crisis", "profesional"]
        )

    def test_pregnancy_guardrail(self, assets):
        """Pregnancy declarado activa pregnancy_guardrail + tone cautious."""
        request = CoachReplyRequest(
            userMessage="¿Puedo tomar este suplemento?",
            userContextSummary=(
                "Mujer 33 años, es-MX. Embarazo primer trimestre."
            ),
        )
        reply = build_local_coach_reply(request, assets=assets)

        assert CoachSafetyFlag.pregnancy_guardrail in reply.safetyFlags
        assert reply.tone == CoachTone.cautious
        assert any(
            action.type == CoachSuggestedActionType.consult_professional
            for action in reply.suggestedActions
        )

    def test_diabetes_guardrail(self, assets):
        """Diabetes activa diabetes_guardrail con referral médico."""
        request = CoachReplyRequest(
            userMessage="¿Este cereal está bien?",
            userContextSummary=(
                "Mujer 45 años, es-MX. Conditions: diabetes tipo 2."
            ),
        )
        reply = build_local_coach_reply(request, assets=assets)

        assert CoachSafetyFlag.diabetes_guardrail in reply.safetyFlags
        assert "médico" in reply.disclaimer.lower() or "medico" in reply.disclaimer.lower()


# ============================================================================
# Voice-ready fields — no crashean cuando ausentes, respetan límites
# ============================================================================


class TestVoiceReadyFields:
    def test_voice_tags_respect_enum(self, assets, minimal_request):
        reply = build_local_coach_reply(minimal_request, assets=assets)
        if reply.voiceTags:
            for tag in reply.voiceTags:
                # Enum values can be strings or enum objects depending on config
                tag_value = tag if isinstance(tag, str) else tag.value
                assert tag_value in {v.value for v in CoachVoiceTag}

    def test_voice_tags_max_8(self, assets, minimal_request):
        reply = build_local_coach_reply(minimal_request, assets=assets)
        if reply.voiceTags:
            assert len(reply.voiceTags) <= 8

    def test_voice_directive_optional(self, assets, minimal_request):
        """voiceDirective puede ser None y el reply sigue siendo válido."""
        reply = build_local_coach_reply(minimal_request, assets=assets)
        assets.validate_reply(reply)  # no raise


# ============================================================================
# Fallback determinístico — funciona sin provider
# ============================================================================


class TestLocalFallback:
    def test_local_service_works_without_vertex(self, local_service, minimal_request):
        """Con provider=local, el servicio responde sin llamar a Vertex."""
        reply = local_service.coach_reply(minimal_request)
        assert isinstance(reply, CoachReply)
        assert reply.message
        assert reply.tone in {t for t in CoachTone}

    def test_schema_validation_on_local_output(self, assets, minimal_request):
        """El fallback local siempre devuelve payloads válidos contra schema."""
        reply = build_local_coach_reply(minimal_request, assets=assets)
        assets.validate_reply(reply)  # no raise


# ============================================================================
# API Endpoint — integration test
# ============================================================================


class TestCoachEndpoint:
    def test_coach_reply_endpoint_responds(self, client):
        """POST /v1/coach/reply con request válido devuelve 200 + CoachReply."""
        payload = {
            "userMessage": "Hola, ¿me puedes ayudar con algo?",
            "userContextSummary": "Mujer 30 años, es-MX.",
        }
        response = client.post("/v1/coach/reply", json=payload)
        assert response.status_code == 200
        body = response.json()
        # Valida campos obligatorios del schema
        for field in [
            "replyId",
            "createdAt",
            "message",
            "tone",
            "suggestedActions",
            "safetyFlags",
            "evidenceTier",
            "disclaimer",
        ]:
            assert field in body, f"Missing required field: {field}"

    def test_coach_reply_invalid_request(self, client):
        """Request sin userMessage devuelve 422."""
        payload = {"userContextSummary": "Sin mensaje"}
        response = client.post("/v1/coach/reply", json=payload)
        assert response.status_code == 422


# ============================================================================
# Prompt construction helpers
# ============================================================================


class TestPromptConstruction:
    def test_context_prompt_includes_user_context(self, assets):
        request = CoachReplyRequest(
            userMessage="Hola",
            userContextSummary="Mujer 35, fase lútea, goals: steady energy",
        )
        prompt = build_coach_context_prompt(request)
        assert "Mujer 35" in prompt
        assert "fase lútea" in prompt

    def test_context_prompt_includes_checkins_when_present(self, assets):
        request = CoachReplyRequest(
            userMessage="Hola",
            userContextSummary="Mujer 35, es-MX.",
            recentCheckIns=[
                CoachCheckInEntry(date="2026-04-17", energy=3, bloating=2, mood=4),
            ],
        )
        prompt = build_coach_context_prompt(request)
        assert "Recent check-ins" in prompt
        assert "energy 3/5" in prompt

    def test_task_prompt_includes_user_message(self, assets):
        request = CoachReplyRequest(
            userMessage="¿Qué comer hoy?",
            userContextSummary="",
        )
        prompt = build_coach_task_prompt(request)
        assert "¿Qué comer hoy?" in prompt
        assert "OUTPUT RULES" in prompt
