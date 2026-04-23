"""
Coach Agent runtime.

Espejo de scan_verdict_runtime.py. Carga assets, valida golden examples al
startup, normaliza schema para Vertex, construye task prompt, y provee un
fallback determinístico local en español MX.

Destino: agent-service/app/coach_runtime.py
"""

from __future__ import annotations

import copy
import hashlib
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any
from uuid import uuid4

from jsonschema import Draft7Validator

from app.contracts import (
    CoachReply,
    CoachReplyRequest,
    CoachSafetyFlag,
    CoachSuggestedAction,
    CoachSuggestedActionType,
    CoachTone,
    CoachEvidenceTier,
    CoachVoiceTag,
)

DEFAULT_ASSET_DIR = Path(__file__).resolve().parent.parent / "assets" / "coach_agent"
SYSTEM_PROMPT_FILE = "LILA_CoachPrompt.md"
SCHEMA_FILE = "CoachReplySchema.json"
GOLDEN_EXAMPLES_FILE = "LILA_CoachGoldenExamples.md"
SYSTEM_PROMPT_MARKER = "## CAPA 1: SYSTEM PROMPT FIJO"
COACH_ASSET_FILES = (
    SYSTEM_PROMPT_FILE,
    SCHEMA_FILE,
    GOLDEN_EXAMPLES_FILE,
)
BASE_DISCLAIMER = (
    "Nácar ofrece guía direccional de wellness, no diagnóstico ni tratamiento médico."
)


class CoachAssetError(RuntimeError):
    """Assets del Coach ausentes o malformados."""


class CoachSchemaValidationError(RuntimeError):
    """Payload del Coach falla validación contra schema."""


@dataclass(frozen=True)
class CoachRuntimeAssets:
    asset_dir: Path
    system_prompt_markdown: str
    system_prompt: str
    schema: dict[str, Any]
    vertex_response_json_schema: dict[str, Any]
    golden_examples_markdown: str
    golden_example_payloads: tuple[dict[str, Any], ...]
    declared_version: str | None
    version: str
    file_checksums: dict[str, str]
    _validator: Draft7Validator

    def validate_payload(self, payload: dict[str, Any]) -> dict[str, Any]:
        errors = sorted(
            self._validator.iter_errors(payload),
            key=lambda error: list(error.absolute_path),
        )
        if errors:
            first = errors[0]
            path = ".".join(str(piece) for piece in first.absolute_path) or "<root>"
            raise CoachSchemaValidationError(f"{path}: {first.message}")
        return payload

    def validate_reply(self, reply: CoachReply) -> CoachReply:
        self.validate_payload(reply.model_dump(mode="json"))
        return reply

    def parse_payload_text(self, payload_text: str) -> dict[str, Any]:
        cleaned = payload_text.strip()
        if cleaned.startswith("```"):
            cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
            cleaned = re.sub(r"\s*```$", "", cleaned)
        try:
            payload = json.loads(cleaned)
        except json.JSONDecodeError as exc:
            raise CoachSchemaValidationError(f"invalid JSON payload: {exc}") from exc
        if not isinstance(payload, dict):
            raise CoachSchemaValidationError(
                "coach reply payload must be a JSON object"
            )
        return self.validate_payload(payload)


@lru_cache(maxsize=4)
def get_coach_assets(asset_dir: str | None = None) -> CoachRuntimeAssets:
    root = Path(asset_dir).expanduser().resolve() if asset_dir else DEFAULT_ASSET_DIR
    raw_assets: dict[str, str] = {}
    file_checksums: dict[str, str] = {}

    for file_name in COACH_ASSET_FILES:
        path = root / file_name
        if not path.exists():
            raise CoachAssetError(f"missing coach asset: {path}")
        content = path.read_text(encoding="utf-8")
        raw_assets[file_name] = content
        file_checksums[file_name] = hashlib.sha256(
            content.encode("utf-8")
        ).hexdigest()

    schema = json.loads(raw_assets[SCHEMA_FILE])
    validator = Draft7Validator(schema)
    golden_payloads = tuple(_extract_json_code_blocks(raw_assets[GOLDEN_EXAMPLES_FILE]))

    if len(golden_payloads) < 5:
        raise CoachAssetError(
            f"expected at least 5 coach golden examples, found {len(golden_payloads)}"
        )

    for idx, payload in enumerate(golden_payloads):
        errors = sorted(
            validator.iter_errors(payload),
            key=lambda error: list(error.absolute_path),
        )
        if errors:
            first = errors[0]
            path = ".".join(str(piece) for piece in first.absolute_path) or "<root>"
            raise CoachAssetError(
                f"golden example #{idx + 1} failed schema validation at {path}: {first.message}"
            )

    declared_version = _extract_declared_version(raw_assets[SYSTEM_PROMPT_FILE])
    fingerprint = hashlib.sha256(
        "".join(
            f"{name}:{file_checksums[name]}" for name in COACH_ASSET_FILES
        ).encode("utf-8")
    ).hexdigest()[:12]
    version = f"{declared_version}+{fingerprint}" if declared_version else fingerprint

    return CoachRuntimeAssets(
        asset_dir=root,
        system_prompt_markdown=raw_assets[SYSTEM_PROMPT_FILE],
        system_prompt=_extract_runtime_system_prompt(raw_assets[SYSTEM_PROMPT_FILE]),
        schema=schema,
        vertex_response_json_schema=_normalize_vertex_json_schema(schema),
        golden_examples_markdown=raw_assets[GOLDEN_EXAMPLES_FILE],
        golden_example_payloads=golden_payloads,
        declared_version=declared_version,
        version=version,
        file_checksums=file_checksums,
        _validator=validator,
    )


def build_coach_context_prompt(request: CoachReplyRequest) -> str:
    """
    CAPA 2: Context injection dinámico a partir del CoachReplyRequest.

    Se concatena al system prompt cuando se llama al modelo.
    """
    sections: list[str] = ["# CONTEXTO DE LA USUARIA"]

    sections.append(
        "## UserContext summary\n"
        + (request.userContextSummary.strip() or "Sin contexto adicional.")
    )

    if request.latestVerdictSummary:
        lv = request.latestVerdictSummary
        sections.append(
            "## Latest Verdict\n"
            f"- Product: {lv.productName}\n"
            f"- Fit: {lv.fit}\n"
            f"- When: {lv.createdAt}\n"
            f"- Verdict ID: {lv.verdictId}"
        )

    if request.recentVerdictSummaries:
        lines = [
            f"- {v.productName} → {v.fit} ({v.createdAt})"
            for v in request.recentVerdictSummaries[:5]
        ]
        sections.append("## Recent verdicts\n" + "\n".join(lines))

    if request.recentCheckIns:
        lines = []
        for c in request.recentCheckIns[:3]:
            base = (
                f"- {c.date}: energy {c.energy}/5, bloating {c.bloating}/5, "
                f"mood {c.mood}/5"
            )
            if c.note:
                base += f", note: {c.note}"
            lines.append(base)
        sections.append("## Recent check-ins\n" + "\n".join(lines))

    if request.memorySummaries:
        sections.append(
            "## Memory summaries\n"
            + "\n".join(f"- {m}" for m in request.memorySummaries[:5])
        )

    if request.patternInsights:
        sections.append(
            "## Pattern insights\n"
            + "\n".join(f"- {p}" for p in request.patternInsights[:3])
        )

    if request.threadHistory:
        lines = [
            f"- [{turn.role}] {turn.content}"
            for turn in request.threadHistory[-10:]
        ]
        sections.append("## Recent conversation\n" + "\n".join(lines))

    return "\n\n".join(sections)


def build_coach_task_prompt(request: CoachReplyRequest) -> str:
    """CAPA 3: task prompt con el mensaje actual y output rules."""
    return "\n".join(
        [
            "Responde a la usuaria. Usa el contexto inyectado y aplica los guardrails del sistema.",
            "",
            f"USER MESSAGE: {request.userMessage}",
            "",
            "OUTPUT RULES",
            "- Devuelve solo JSON válido conforme al schema.",
            "- No uses markdown ni texto fuera del JSON.",
            "- Si activas safetyFlags, inclúyelos en el array.",
            "- Si referencias un verdict, usa su ID real.",
            "- Máximo 4 frases en message, máximo 3 suggestedActions.",
            "- replyId debe ser UUID v4 único.",
            "- createdAt en formato ISO8601 UTC.",
        ]
    )


def build_local_coach_reply(
    request: CoachReplyRequest,
    *,
    assets: CoachRuntimeAssets,
    provider_failure: str | None = None,
) -> CoachReply:
    """
    Fallback determinístico del Coach.

    Activa:
    - Guardrails reales (edHistory, pregnancy, diabetes, minor, crisis)
    - Detección básica de intent (pregunta-sobre-producto, interpretación-patrón,
      emocional-frustración, educativa, celebración)
    - Copy en español MX
    - Voice tags alineados al tono

    No reemplaza al provider real, pero sostiene conversaciones básicas sin red.
    """
    now = datetime.now(timezone.utc)
    combined_text = " ".join(
        part
        for part in [
            request.userMessage,
            request.userContextSummary,
            " ".join(request.memorySummaries or []),
            " ".join(
                f"{c.note or ''}" for c in request.recentCheckIns or []
            ),
        ]
        if part
    ).lower()

    # Guardrail detection
    ed_history = _contains_any(
        combined_text,
        ["edhistory", "trastorno aliment", "eating disorder"],
    )
    pregnancy = _contains_any(
        combined_text,
        ["embaraz", "pregnan", "obstetra", "primer trimestre"],
    )
    diabetes = _contains_any(combined_text, ["diabetes", "glucosa", "insulina"])
    minor = _contains_any(combined_text, ["menor de edad", "tengo 15", "tengo 16", "tengo 17"])
    crisis = _contains_any(
        combined_text,
        [
            "no puedo más",
            "no puedo mas",
            "no quiero estar aquí",
            "no quiero estar aqui",
            "lastimarme",
            "hacerme daño",
            "hacerme dano",
            "suicid",
            "desespera",
        ],
    )

    # User message intent detection
    asks_about_product = _contains_any(
        request.userMessage.lower(),
        [
            "está bien",
            "esta bien",
            "me conviene",
            "puedo tomar",
            "¿sirve",
            "recomiendas",
            "qué onda con",
            "que onda con",
        ],
    )
    asks_about_pattern = _contains_any(
        request.userMessage.lower(),
        [
            "por qué me siento",
            "por que me siento",
            "por qué llevo",
            "por que llevo",
            "varios días",
            "varios dias",
            "últimos días",
            "ultimos dias",
        ],
    )
    expresses_frustration = _contains_any(
        request.userMessage.lower(),
        [
            "estoy harta",
            "ya no puedo",
            "estoy cansada",
            "estoy agotada",
            "no me siento bien",
        ],
    )
    asks_educational = _contains_any(
        request.userMessage.lower(),
        [
            "¿qué es",
            "qué es",
            "que es",
            "por qué",
            "por que",
            "cómo funciona",
            "como funciona",
            "es normal",
        ],
    )

    # Defaults
    safety_flags: list[CoachSafetyFlag] = []
    disclaimer_lines: list[str] = []
    tone = CoachTone.warmDirect
    evidence_tier = CoachEvidenceTier.emerging
    voice_tags: list[CoachVoiceTag] = [CoachVoiceTag.warm]
    voice_directive: str | None = None
    suggested_actions: list[CoachSuggestedAction] = []
    follow_up: str | None = None
    referenced_verdict_id: str | None = None
    referenced_verdict_summary: str | None = None
    referenced_patterns: list[str] = []

    # Crisis signal takes absolute priority
    if crisis:
        safety_flags.append(CoachSafetyFlag.crisis_signal)
        tone = CoachTone.supportive
        evidence_tier = CoachEvidenceTier.high
        voice_tags = [CoachVoiceTag.gentle, CoachVoiceTag.warm, CoachVoiceTag.calm]
        voice_directive = "pause-after-sentence-1"
        message = (
            "Lo que me cuentas me importa. No tienes que sostener esto sola, y hay líneas "
            "profesionales que atienden exactamente lo que estás viviendo. En México puedes "
            "marcar al 800-290-0024 (SAPTEL), y si estás en Estados Unidos, el 988 de la "
            "Línea de Crisis. ¿Hay alguien cercano a quien puedas llamar ahora mismo?"
        )
        suggested_actions = [
            CoachSuggestedAction(
                type=CoachSuggestedActionType.consult_professional,
                label="Marca una línea de apoyo ahora",
                deepLinkHint=None,
            )
        ]
        follow_up = "¿Quieres que te acompañe hasta que llegues con alguien?"
        disclaimer_lines.append(
            "Si estás en crisis, por favor busca apoyo profesional inmediato."
        )

    # edHistory guardrail
    elif ed_history:
        safety_flags.append(CoachSafetyFlag.ed_guardrail)
        tone = CoachTone.supportive
        evidence_tier = CoachEvidenceTier.high
        voice_tags = [CoachVoiceTag.gentle, CoachVoiceTag.warm]
        voice_directive = "pause-after-sentence-1"
        message = (
            "Aquí vamos con calma. Lo que está sobre la mesa no lo vamos a tratar con números "
            "ni con lógica de restricción; eso suele volver el ciclo más difícil, no más fácil. "
            "Lo que sí suma es cerrar el día con algo que se sienta nutritivo y tranquilo. "
            "Si te está pesando, platicarlo con tu terapeuta vale mucho."
        )
        suggested_actions = [
            CoachSuggestedAction(
                type=CoachSuggestedActionType.consult_professional,
                label="Platícalo con tu terapeuta si aplica",
                deepLinkHint=None,
            )
        ]
        follow_up = "¿Qué te sentiría cuidar bien hoy?"
        disclaimer_lines.append(
            "Si este tipo de análisis te activa restricción, prioriza apoyo clínico y una "
            "lectura más amable."
        )

    # Pregnancy guardrail
    elif pregnancy:
        safety_flags.append(CoachSafetyFlag.pregnancy_guardrail)
        tone = CoachTone.cautious
        evidence_tier = CoachEvidenceTier.high
        voice_tags = [CoachVoiceTag.warm, CoachVoiceTag.cautious]
        message = (
            "En embarazo lo que siempre cierra mejor es llevarlo con tu ginecóloga u "
            "obstetra, especialmente para decisiones específicas sobre suplementos, cafeína "
            "y cualquier cambio en tu alimentación. Puedo darte contexto general, pero la "
            "decisión final la tomas con tu equipo de salud."
        )
        suggested_actions = [
            CoachSuggestedAction(
                type=CoachSuggestedActionType.consult_professional,
                label="Consulta con tu ginecóloga u obstetra",
                deepLinkHint=None,
            )
        ]
        disclaimer_lines.append(
            "En embarazo, cualquier decisión específica conviene revisarla con tu equipo médico."
        )

    # Diabetes guardrail
    elif diabetes:
        safety_flags.append(CoachSafetyFlag.diabetes_guardrail)
        tone = CoachTone.warmDirect
        evidence_tier = CoachEvidenceTier.high
        voice_tags = [CoachVoiceTag.warm, CoachVoiceTag.confident]
        message = (
            "Con diabetes, cualquier ajuste nutricional importante conviene revisarlo con "
            "tu equipo médico. Lo que puedo hacer es darte lecturas específicas de productos "
            "cuando los escanees, pero sin sugerir cambios drásticos de carbos o de tu manejo."
        )
        suggested_actions = [
            CoachSuggestedAction(
                type=CoachSuggestedActionType.consult_professional,
                label="Revisa esto con tu equipo médico",
                deepLinkHint=None,
            ),
            CoachSuggestedAction(
                type=CoachSuggestedActionType.scan,
                label="Escanea lo que quieras evaluar",
                deepLinkHint="scan/barcode",
            ),
        ]
        disclaimer_lines.append("Consulta con tu equipo médico antes de cualquier cambio nutricional.")

    # Minor detected
    elif minor:
        safety_flags.append(CoachSafetyFlag.minor_detected)
        tone = CoachTone.cautious
        evidence_tier = CoachEvidenceTier.high
        voice_tags = [CoachVoiceTag.gentle, CoachVoiceTag.warm]
        message = (
            "Nácar está pensada para mujeres mayores de 18 años. Para esta etapa, lo ideal "
            "es que un adulto de confianza te acompañe a consultar con alguien de salud. "
            "No voy a dar análisis específicos aquí."
        )
        suggested_actions = [
            CoachSuggestedAction(
                type=CoachSuggestedActionType.consult_professional,
                label="Platica con un adulto de confianza",
                deepLinkHint=None,
            )
        ]

    # Emotional frustration
    elif expresses_frustration:
        tone = CoachTone.supportive
        evidence_tier = CoachEvidenceTier.personalPattern
        voice_tags = [CoachVoiceTag.gentle, CoachVoiceTag.warm, CoachVoiceTag.calm]
        voice_directive = "pause-after-sentence-1"
        message = (
            "Lo escucho. Esto que describes no es falta de voluntad ni de disciplina — a veces "
            "hay semanas donde el cuerpo pide otra cosa y vale la pena parar a observarlo. "
            "Si quieres, podemos revisar lo que traes registrado para ver si hay algún patrón."
        )
        if request.recentCheckIns:
            referenced_patterns.append(
                f"Check-ins recientes de {len(request.recentCheckIns)} días registrados"
            )
        suggested_actions = [
            CoachSuggestedAction(
                type=CoachSuggestedActionType.check_in,
                label="Registra cómo te sientes hoy",
                deepLinkHint="checkin/new",
            )
        ]
        follow_up = "¿Qué parte pesa más hoy?"

    # Question about specific product
    elif asks_about_product:
        tone = CoachTone.warmDirect
        evidence_tier = CoachEvidenceTier.emerging
        voice_tags = [CoachVoiceTag.warm, CoachVoiceTag.confident]
        message = (
            "Para darte una lectura real de cómo te afecta, necesito escanearlo. Mándame el "
            "código de barras o una foto de la etiqueta y te doy contexto en un minuto — ahí "
            "puedo ver si el perfil te va a funcionar para tu contexto actual."
        )
        suggested_actions = [
            CoachSuggestedAction(
                type=CoachSuggestedActionType.scan,
                label="Escanea el producto",
                deepLinkHint="scan/barcode",
            )
        ]

    # Pattern interpretation
    elif asks_about_pattern and request.recentCheckIns:
        tone = CoachTone.warmDirect
        evidence_tier = CoachEvidenceTier.personalPattern
        voice_tags = [CoachVoiceTag.warm, CoachVoiceTag.curious]
        recent = request.recentCheckIns[0]
        referenced_patterns.append(
            f"Energy {recent.energy}/5 y bloating {recent.bloating}/5 en tu último check-in"
        )
        message = (
            f"En tus check-ins recientes veo el dato que me dices. Antes de sacar conclusión "
            f"fuerte, me ayudaría saber más — a veces es fase del ciclo, a veces comida, a "
            f"veces sueño. Vale la pena registrarlo un par de días más para ver qué patrón sale."
        )
        if request.latestVerdictSummary:
            referenced_verdict_id = request.latestVerdictSummary.verdictId
            referenced_verdict_summary = (
                f"Tu último scan fue {request.latestVerdictSummary.productName} "
                f"con fit {request.latestVerdictSummary.fit}."
            )
            suggested_actions = [
                CoachSuggestedAction(
                    type=CoachSuggestedActionType.view_verdict,
                    label="Revisa el último veredicto",
                    deepLinkHint=f"analysis/{request.latestVerdictSummary.verdictId}",
                )
            ]
        suggested_actions.append(
            CoachSuggestedAction(
                type=CoachSuggestedActionType.check_in,
                label="Registra cómo sigues estos días",
                deepLinkHint="checkin/new",
            )
        )
        follow_up = "¿Notaste algo específico que haya cambiado esta semana?"

    # Educational question
    elif asks_educational:
        tone = CoachTone.warmDirect
        evidence_tier = CoachEvidenceTier.high
        voice_tags = [CoachVoiceTag.warm, CoachVoiceTag.confident]
        message = (
            "Buena pregunta. Lo que está detrás tiene que ver con cómo cambia tu biología "
            "según la fase del ciclo y tu contexto individual. Puedo darte más detalle si me "
            "dices qué parte te interesa — si es el síntoma en sí, si es qué hacer, o si es "
            "por qué te pasa."
        )
        follow_up = "¿Qué parte te gustaría entender mejor?"

    # Default open conversation
    else:
        tone = CoachTone.warmDirect
        evidence_tier = CoachEvidenceTier.emerging
        voice_tags = [CoachVoiceTag.warm, CoachVoiceTag.curious]
        message = (
            "Cuéntame más. Puedo ayudarte mejor si me dices qué te está pasando hoy — "
            "energía, digestión, ciclo, lo que sea. Y si tienes un producto específico en mente, "
            "mándame el código y lo miramos juntas."
        )
        suggested_actions = [
            CoachSuggestedAction(
                type=CoachSuggestedActionType.scan,
                label="Escanea un producto",
                deepLinkHint="scan/barcode",
            ),
            CoachSuggestedAction(
                type=CoachSuggestedActionType.check_in,
                label="Registra cómo te sientes hoy",
                deepLinkHint="checkin/new",
            ),
        ]
        follow_up = "¿Qué tienes hoy sobre la mesa?"

    # Provider failure note (internal, doesn't affect message)
    if provider_failure:
        # Tracked internally but doesn't alter UX
        pass

    disclaimer = (
        "\n".join(disclaimer_lines + [BASE_DISCLAIMER]) if disclaimer_lines else BASE_DISCLAIMER
    )

    reply = CoachReply(
        replyId=str(uuid4()),
        createdAt=now,
        message=_clip(message, 560),
        tone=tone,
        referencedVerdictId=referenced_verdict_id,
        referencedVerdictSummary=(
            _clip(referenced_verdict_summary, 140) if referenced_verdict_summary else None
        ),
        referencedPatterns=[_clip(p, 200) for p in referenced_patterns[:3]],
        suggestedActions=suggested_actions[:3],
        followUpQuestion=_clip(follow_up, 160) if follow_up else None,
        safetyFlags=safety_flags,
        evidenceTier=evidence_tier,
        disclaimer=disclaimer,
        voiceTags=voice_tags[:8],
        voiceDirective=_clip(voice_directive, 120) if voice_directive else None,
        spokenVersion=None,
    )

    return assets.validate_reply(reply)


# -------- helpers --------


def _extract_declared_version(markdown: str) -> str | None:
    match = re.search(r"\*\*Versión:\*\*\s*([^\n]+)", markdown)
    return match.group(1).strip() if match else None


def _extract_runtime_system_prompt(markdown: str) -> str:
    section = (
        markdown.split(SYSTEM_PROMPT_MARKER, 1)[1]
        if SYSTEM_PROMPT_MARKER in markdown
        else markdown
    )
    match = re.search(r"```(?:[a-zA-Z0-9_-]+)?\s*(.*?)```", section, re.DOTALL)
    if not match:
        raise CoachAssetError(
            "LILA_CoachPrompt.md does not contain a fenced system prompt block"
        )
    return match.group(1).strip()


def _extract_json_code_blocks(markdown: str) -> list[dict[str, Any]]:
    payloads: list[dict[str, Any]] = []
    for match in re.finditer(r"```json\s*(.*?)```", markdown, re.DOTALL):
        block = match.group(1).strip()
        try:
            payload = json.loads(block)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            payloads.append(payload)
    if not payloads:
        raise CoachAssetError("LILA_CoachGoldenExamples.md does not contain JSON examples")
    return payloads


def _normalize_vertex_json_schema(node: Any) -> Any:
    """Mirror de scan_verdict_runtime._normalize_vertex_json_schema."""
    if isinstance(node, dict):
        working = copy.deepcopy(node)
        working.pop("$schema", None)
        schema_type = working.get("type")
        if isinstance(schema_type, list):
            non_null = [entry for entry in schema_type if entry != "null"]
            if len(non_null) == 1 and len(non_null) != len(schema_type):
                working["type"] = non_null[0]
                working["nullable"] = True
            else:
                remainder = {
                    key: value for key, value in working.items() if key != "type"
                }
                return {
                    "anyOf": [
                        _normalize_vertex_json_schema(
                            {"type": schema_entry, **remainder}
                        )
                        for schema_entry in schema_type
                    ]
                }
        normalized = {
            key: _normalize_vertex_json_schema(value) for key, value in working.items()
        }
        if normalized.get("type") == "object" and isinstance(
            normalized.get("properties"), dict
        ):
            normalized["propertyOrdering"] = list(normalized["properties"].keys())
        return normalized
    if isinstance(node, list):
        return [_normalize_vertex_json_schema(item) for item in node]
    return node


def _contains_any(text: str, needles: list[str]) -> bool:
    return any(needle in text for needle in needles)


def _clip(text: str | None, max_length: int) -> str:
    if text is None:
        return ""
    stripped = " ".join(text.split())
    if len(stripped) <= max_length:
        return stripped
    return stripped[: max_length - 1].rstrip() + "…"
