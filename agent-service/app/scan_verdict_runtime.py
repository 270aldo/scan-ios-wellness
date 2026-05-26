from __future__ import annotations

import copy
import hashlib
import json
import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

from jsonschema import Draft7Validator

from app.contracts import (
    ScanVerdict,
    ScanVerdictAgentInsight,
    ScanVerdictAlternative,
    ScanVerdictConfidence,
    ScanVerdictContextDirection,
    ScanVerdictContextFactor,
    ScanVerdictDeterministicFactor,
    ScanVerdictEvidenceSource,
    ScanVerdictEvidenceTier,
    ScanVerdictFit,
    ScanVerdictFollowUpPrompt,
    ScanVerdictFollowUpResponseType,
    ScanVerdictLens,
    ScanVerdictLensDelta,
    ScanVerdictLensScore,
    ScanVerdictPersonalRelevance,
    ScanVerdictReasoningBreakdown,
    ScanVerdictRequest,
    ScanVerdictScoreTrend,
    ScanVerdictUserHistoryFactor,
    ScanVerdictWatchout,
    ScanVerdictWatchoutSeverity,
)
from app.prompt_safety import sanitize_prompt_text

DEFAULT_ASSET_DIR = Path(__file__).resolve().parent.parent / "assets" / "scan_verdict"
SYSTEM_PROMPT_FILE = "LILA_SystemPrompt.md"
SCHEMA_FILE = "ScanVerdictSchema.json"
GOLDEN_EXAMPLES_FILE = "LILA_GoldenExamples.md"
SYSTEM_PROMPT_MARKER = "## CAPA 1: SYSTEM PROMPT FIJO"
SCAN_VERDICT_ASSET_FILES = (
    SYSTEM_PROMPT_FILE,
    SCHEMA_FILE,
    GOLDEN_EXAMPLES_FILE,
)
SCAN_VERDICT_LENS_ORDER = [
    ScanVerdictLens.glowAndSkin,
    ScanVerdictLens.hormoneBalance,
    ScanVerdictLens.gutComfort,
    ScanVerdictLens.energyAndMood,
    ScanVerdictLens.bodyCompositionAndStrength,
]
CONFIDENCE_RANK = {
    ScanVerdictConfidence.insufficient: 0,
    ScanVerdictConfidence.low: 1,
    ScanVerdictConfidence.medium: 2,
    ScanVerdictConfidence.high: 3,
}
BASE_DISCLAIMER = (
    "Nácar ofrece guía direccional de wellness, no diagnóstico ni tratamiento médico."
)


class ScanVerdictAssetError(RuntimeError):
    """Raised when the scan verdict runtime assets are missing or malformed."""


class ScanVerdictSchemaValidationError(RuntimeError):
    """Raised when a payload fails local schema validation."""


@dataclass(frozen=True)
class ScanVerdictRuntimeAssets:
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
        errors = sorted(self._validator.iter_errors(payload), key=lambda error: list(error.absolute_path))
        if errors:
            first = errors[0]
            path = ".".join(str(piece) for piece in first.absolute_path) or "<root>"
            raise ScanVerdictSchemaValidationError(f"{path}: {first.message}")
        return payload

    def validate_verdict(self, verdict: ScanVerdict) -> ScanVerdict:
        self.validate_payload(verdict.model_dump(mode="json"))
        return verdict

    def parse_payload_text(self, payload_text: str) -> dict[str, Any]:
        cleaned = payload_text.strip()
        if cleaned.startswith("```"):
            cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
            cleaned = re.sub(r"\s*```$", "", cleaned)
        try:
            payload = json.loads(cleaned)
        except json.JSONDecodeError as exc:
            raise ScanVerdictSchemaValidationError(f"invalid JSON payload: {exc}") from exc
        if not isinstance(payload, dict):
            raise ScanVerdictSchemaValidationError("scan verdict payload must be a JSON object")
        return self.validate_payload(payload)


@lru_cache(maxsize=4)
def get_scan_verdict_assets(asset_dir: str | None = None) -> ScanVerdictRuntimeAssets:
    root = Path(asset_dir).expanduser().resolve() if asset_dir else DEFAULT_ASSET_DIR
    raw_assets: dict[str, str] = {}
    file_checksums: dict[str, str] = {}

    for file_name in SCAN_VERDICT_ASSET_FILES:
        path = root / file_name
        if not path.exists():
            raise ScanVerdictAssetError(f"missing scan verdict asset: {path}")
        content = path.read_text(encoding="utf-8")
        raw_assets[file_name] = content
        file_checksums[file_name] = hashlib.sha256(content.encode("utf-8")).hexdigest()

    schema = json.loads(raw_assets[SCHEMA_FILE])
    validator = Draft7Validator(schema)
    golden_payloads = tuple(_extract_json_code_blocks(raw_assets[GOLDEN_EXAMPLES_FILE]))
    for payload in golden_payloads:
        errors = sorted(validator.iter_errors(payload), key=lambda error: list(error.absolute_path))
        if errors:
            first = errors[0]
            path = ".".join(str(piece) for piece in first.absolute_path) or "<root>"
            raise ScanVerdictAssetError(f"golden example failed schema validation at {path}: {first.message}")

    declared_version = _extract_declared_version(raw_assets[SYSTEM_PROMPT_FILE])
    fingerprint = hashlib.sha256(
        "".join(f"{name}:{file_checksums[name]}" for name in SCAN_VERDICT_ASSET_FILES).encode("utf-8")
    ).hexdigest()[:12]
    version = f"{declared_version}+{fingerprint}" if declared_version else fingerprint

    return ScanVerdictRuntimeAssets(
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


def build_scan_verdict_task_prompt(request: ScanVerdictRequest) -> str:
    structured_summary = sanitize_prompt_text(
        request.structuredSummary,
        max_length=1500,
        fallback="Sin structuredSummary adicional.",
    )
    user_context_summary = sanitize_prompt_text(
        request.userContextSummary,
        max_length=2000,
        fallback="Sin contexto adicional.",
    )
    product_name = sanitize_prompt_text(
        request.productName,
        max_length=240,
        fallback="(sin nombre de producto)",
    )
    resolved_product_lines: list[str] = []
    if request.resolvedProduct:
        rp = request.resolvedProduct
        resolved_product_lines = [
            "",
            "RESOLVED PRODUCT FACTS",
            f"- productId: {rp.productId or 'null'}",
            f"- canonicalProductID: {rp.canonicalProductID or 'null'}",
            f"- resolvedName: {rp.name}",
            f"- brand: {rp.brand or 'null'}",
            f"- barcode: {rp.barcode or 'null'}",
            f"- resolutionSource: {rp.source.value if rp.source else 'null'}",
            f"- resolutionConfidence: {rp.confidence if rp.confidence is not None else 'null'}",
            f"- isDirectional: {str(rp.isDirectional).lower()}",
            f"- ingredients: {', '.join(rp.ingredients[:8]) if rp.ingredients else 'none'}",
        ]
        if rp.nutritionSnapshot:
            ns = rp.nutritionSnapshot
            resolved_product_lines.append(
                "- nutritionSnapshot: "
                + ", ".join(
                    [
                        f"energy={ns.energyKcalPer100g}" if ns.energyKcalPer100g is not None else "energy=null",
                        f"protein={ns.proteinGPer100g}" if ns.proteinGPer100g is not None else "protein=null",
                        f"carbs={ns.carbsGPer100g}" if ns.carbsGPer100g is not None else "carbs=null",
                        f"fat={ns.fatGPer100g}" if ns.fatGPer100g is not None else "fat=null",
                        f"sugars={ns.sugarsGPer100g}" if ns.sugarsGPer100g is not None else "sugars=null",
                        f"fiber={ns.fiberGPer100g}" if ns.fiberGPer100g is not None else "fiber=null",
                        f"sodiumMg={ns.sodiumMgPer100g}" if ns.sodiumMgPer100g is not None else "sodiumMg=null",
                        f"caffeineMg={ns.caffeineMgPer100g}" if ns.caffeineMgPer100g is not None else "caffeineMg=null",
                        f"novaGroup={ns.novaGroup}" if ns.novaGroup is not None else "novaGroup=null",
                    ]
                )
            )

        # Explicit Mexico NOM-051 signals (regulatory information, not value judgment)
        if rp.mexicoNutritionSignals:
            m = rp.mexicoNutritionSignals
            labels = [label.value for label in m.warningLabels] if m.warningLabels else []
            mexico_line = f"- mexicoNOM051Signals: warningLabels={labels}, caffeineWarning={m.containsCaffeineWarning}, sweetenerWarning={m.containsSweetenerWarning}, source={m.source}"
            resolved_product_lines.append(mexico_line)
            resolved_product_lines.append("- NOTE: These are official Mexican front-of-pack labeling signals (NOM-051). Frame them as regulatory facts only. Never use them to make moral or health-superiority claims about the whole product.")
    return "\n".join(
        [
            "Evalúa este scan usando el UserContext inyectado y responde solo con JSON válido.",
            "",
            "USER CONTEXT INJECTION",
            user_context_summary,
            "",
            "TASK",
            f"- productName: {product_name}",
            f"- source: {request.source}",
            f"- scanId: {request.scanId or 'null'}",
            f"- structuredSummary: {structured_summary}",
            *resolved_product_lines,
            "",
            "OUTPUT RULES",
            "- Sigue exactamente el response schema provisto por el runtime.",
            "- Devuelve exactamente 5 lensScores y máximo 2 watchouts.",
            "- Usa betterSwap y trackPrompt solo cuando realmente apliquen; en caso contrario devuelve null.",
            "- Si la resolución es insuficiente, usa fit=unclear y confidence=insufficient sin inventar detalles.",
            "- No devuelvas markdown ni texto fuera del JSON.",
        ]
    )


def build_local_scan_verdict(
    request: ScanVerdictRequest,
    *,
    assets: ScanVerdictRuntimeAssets,
    provider_failure: str | None = None,
) -> ScanVerdict:
    product_name = (request.productName or "este producto").strip()
    resolved_product = request.resolvedProduct
    nutrition = resolved_product.nutritionSnapshot if resolved_product else None
    combined_text = " ".join(
        part
        for part in [
            product_name,
            resolved_product.name if resolved_product else "",
            resolved_product.brand if resolved_product else "",
            " ".join(resolved_product.ingredients) if resolved_product else "",
            request.source,
            request.userContextSummary,
            request.structuredSummary or "",
        ]
        if part
    ).lower()

    scores = {lens: 68 for lens in SCAN_VERDICT_LENS_ORDER}
    scores[ScanVerdictLens.energyAndMood] = 70
    context_applied: dict[ScanVerdictLens, list[ScanVerdictContextFactor]] = {
        lens: [] for lens in SCAN_VERDICT_LENS_ORDER
    }
    deterministic_factors: list[ScanVerdictDeterministicFactor] = []
    watchouts: list[ScanVerdictWatchout] = []
    user_history_factors: list[ScanVerdictUserHistoryFactor] = []
    disclaimer_lines: list[str] = []

    fit_override: ScanVerdictFit | None = None
    primary_reason: str | None = None
    better_swap: ScanVerdictAlternative | None = None
    track_prompt: ScanVerdictFollowUpPrompt | None = None
    evidence_tier = ScanVerdictEvidenceTier.emerging
    confidence = ScanVerdictConfidence.high if request.structuredSummary else ScanVerdictConfidence.medium

    resolution_confidence = resolved_product.confidence if resolved_product and resolved_product.confidence is not None else None
    if resolution_confidence is not None:
        if resolution_confidence >= 0.84:
            confidence = ScanVerdictConfidence.high
        elif resolution_confidence >= 0.58:
            confidence = _downgrade_confidence(confidence, ScanVerdictConfidence.medium)
        elif resolution_confidence >= 0.34:
            confidence = _downgrade_confidence(confidence, ScanVerdictConfidence.low)
        else:
            confidence = _downgrade_confidence(confidence, ScanVerdictConfidence.insufficient)

    pregnancy = _contains_any(combined_text, ["embaraz", "pregnan", "obstetra", "primer trimestre"])
    diabetes = _contains_any(combined_text, ["diabetes", "glucosa", "insulina"])
    ed_history = _contains_any(combined_text, ["edhistory", "trastorno aliment", "eating disorder"])
    luteal = _contains_any(combined_text, ["fase lútea", "fase lutea", "lútea", "lutea"])
    caffeine_sensitive = _contains_any(
        combined_text,
        ["caffeinesensitive", "caffeine sensitive", "sensibilidad a cafe", "sensibilidad a cafeína", "cafeína"],
    )
    bloating_prone = _contains_any(combined_text, ["bloating", "hinch", "inflam", "gut discomfort"])
    high_sugar = _contains_any(
        combined_text,
        ["high sugar", "higher sugar", "sugar load", "azúcar", "35g", "added sugar", "azucar"],
    )
    high_caffeine = _contains_any(
        combined_text,
        ["energy drink", "bebida energética", "bebida energetica", "160mg", "pre-workout", "pre workout"],
    )
    high_protein = _contains_any(combined_text, ["proteína", "proteina", "protein", "30g", "15g"])
    tuna = _contains_any(combined_text, ["atún", "atun", "tuna"])
    alcohol = _contains_any(combined_text, ["alcohol", "vino", "wine", "beer", "cerveza", "cocktail"])

    if nutrition:
        if nutrition.sugarsGPer100g is not None and nutrition.sugarsGPer100g >= 12:
            high_sugar = True
        if nutrition.caffeineMgPer100g is not None and nutrition.caffeineMgPer100g >= 45:
            high_caffeine = True
        if nutrition.proteinGPer100g is not None and nutrition.proteinGPer100g >= 10:
            high_protein = True

    def apply_delta(
        lens: ScanVerdictLens,
        delta: int,
        rule: str,
        *,
        context_label: str | None = None,
        context_direction: ScanVerdictContextDirection | None = None,
        context_explanation: str | None = None,
    ) -> None:
        scores[lens] = _clamp_score(scores[lens] + delta)
        deterministic_factors.append(
            ScanVerdictDeterministicFactor(
                rule=_clip(rule, 140),
                delta=max(-50, min(50, delta)),
                affectedLens=lens,
            )
        )
        if context_label and context_direction and context_explanation and len(context_applied[lens]) < 3:
            context_applied[lens].append(
                ScanVerdictContextFactor(
                    label=_clip(context_label, 40),
                    direction=context_direction,
                    explanation=_clip(context_explanation, 160),
                )
            )

    def add_watchout(
        title: str,
        detail: str,
        severity: ScanVerdictWatchoutSeverity,
        relevance: ScanVerdictPersonalRelevance,
    ) -> None:
        watchouts.append(
            ScanVerdictWatchout(
                title=_clip(title, 60),
                detail=_clip(detail, 200),
                severity=severity,
                personalRelevance=relevance,
            )
        )

    if resolved_product and resolved_product.isDirectional:
        confidence = _downgrade_confidence(confidence, ScanVerdictConfidence.low)
        add_watchout(
            "Producto no resuelto del todo",
            "Todavía no hay una identidad de producto suficientemente fuerte. Léelo como guía direccional, no como verdad final de catálogo.",
            ScanVerdictWatchoutSeverity.moderate,
            ScanVerdictPersonalRelevance.general,
        )
        if primary_reason is None:
            primary_reason = "Todavía no hay una resolución de producto lo bastante fuerte para una lectura totalmente específica."

    if request.source in {"meal_photo", "menu_photo"}:
        confidence = _downgrade_confidence(confidence, ScanVerdictConfidence.low)
        add_watchout(
            "Lectura por foto",
            "La lectura por foto sigue siendo direccional hasta conectar el resolver real de productos.",
            ScanVerdictWatchoutSeverity.moderate,
            ScanVerdictPersonalRelevance.general,
        )

    if not request.structuredSummary and request.source in {"meal_photo", "menu_photo"}:
        confidence = _downgrade_confidence(confidence, ScanVerdictConfidence.insufficient)
        fit_override = ScanVerdictFit.unclear
        primary_reason = (
            "No hay suficiente resolución del producto todavía. Corrige el nombre o aporta una foto/etiqueta más clara."
        )

    if pregnancy:
        evidence_tier = ScanVerdictEvidenceTier.high
        disclaimer_lines.append("Para decisiones específicas en embarazo, consulta con tu ginecóloga u obstetra.")
        if high_caffeine:
            apply_delta(
                ScanVerdictLens.energyAndMood,
                -18,
                "Cafeína alta en embarazo pide un guardrail más estricto.",
                context_label="Tu embarazo actual",
                context_direction=ScanVerdictContextDirection.reduce,
                context_explanation="En embarazo conviene cuidar más el total diario de cafeína.",
            )
            add_watchout(
                "Cafeína en embarazo",
                "Si esta bebida trae cafeína, revisa que tu total diario siga por debajo del límite que te indicó tu equipo de salud.",
                ScanVerdictWatchoutSeverity.important,
                ScanVerdictPersonalRelevance.clinical,
            )
        if alcohol:
            fit_override = ScanVerdictFit.skip
            confidence = ScanVerdictConfidence.high
            primary_reason = "En embarazo, si hay alcohol mejor evitarlo por completo aunque el resto del producto se vea aceptable."
            add_watchout(
                "Alcohol en embarazo",
                "Aquí el guardrail es clínico: mejor no usarlo mientras estés embarazada.",
                ScanVerdictWatchoutSeverity.important,
                ScanVerdictPersonalRelevance.clinical,
            )
        elif tuna:
            fit_override = ScanVerdictFit.occasional
            confidence = ScanVerdictConfidence.high
            primary_reason = (
                "Te aporta proteína útil, pero en embarazo conviene limitar atún por mercurio y no volverlo un staple."
            )
            apply_delta(
                ScanVerdictLens.bodyCompositionAndStrength,
                10,
                "Proteína útil en embarazo suma al lens de fuerza y recuperación.",
                context_label="Tu embarazo actual",
                context_direction=ScanVerdictContextDirection.boost,
                context_explanation="La proteína sigue siendo una base valiosa, pero aquí no compensa el guardrail de mercurio.",
            )
            apply_delta(
                ScanVerdictLens.hormoneBalance,
                -12,
                "Mercurio moderado de atún limita la frecuencia recomendada.",
                context_label="Tu embarazo actual",
                context_direction=ScanVerdictContextDirection.reduce,
                context_explanation="En esta etapa conviene preferir pescados con mercurio más bajo.",
            )
            add_watchout(
                "Mercurio en embarazo",
                "Mejor mantener el atún como algo ocasional y preferir pescados con mercurio más bajo.",
                ScanVerdictWatchoutSeverity.important,
                ScanVerdictPersonalRelevance.clinical,
            )
            better_swap = ScanVerdictAlternative(
                productName="Sardinas o salmón enlatado en agua",
                whyBetter="Mantienen proteína útil con un perfil más tranquilo para embarazo.",
                improvedLenses=[
                    ScanVerdictLens.hormoneBalance,
                    ScanVerdictLens.glowAndSkin,
                ],
                expectedLensDeltas=[
                    ScanVerdictLensDelta(
                        lens=ScanVerdictLens.hormoneBalance,
                        estimatedChange=14,
                    ),
                    ScanVerdictLensDelta(
                        lens=ScanVerdictLens.glowAndSkin,
                        estimatedChange=8,
                    ),
                ],
            )

    if high_sugar:
        apply_delta(
            ScanVerdictLens.hormoneBalance,
            -12,
            "Carga alta de azúcar resta estabilidad metabólica.",
            context_label="Tu contexto de hoy" if luteal else None,
            context_direction=ScanVerdictContextDirection.reduce if luteal else None,
            context_explanation="En fase lútea la oscilación de glucosa suele sentirse más." if luteal else None,
        )
        apply_delta(
            ScanVerdictLens.energyAndMood,
            -14,
            "Azúcar alta aumenta el riesgo de sube-y-baja de energía.",
            context_label="Tu energía reciente" if _contains_any(combined_text, ["energy crash", "crash", "fatigue", "fatiga"]) else None,
            context_direction=ScanVerdictContextDirection.reduce if _contains_any(combined_text, ["energy crash", "crash", "fatigue", "fatiga"]) else None,
            context_explanation="Vienes cuidando energía más estable; este perfil puede empujar en dirección contraria."
            if _contains_any(combined_text, ["energy crash", "crash", "fatigue", "fatiga"])
            else None,
        )
        apply_delta(
            ScanVerdictLens.glowAndSkin,
            -8,
            "Azúcar añadida alta suele jugar en contra de piel y glow.",
        )
        add_watchout(
            "Azúcar alta",
            "Se ve mejor como algo ocasional si hoy estás protegiendo energía más estable.",
            ScanVerdictWatchoutSeverity.moderate,
            ScanVerdictPersonalRelevance.personal if luteal else ScanVerdictPersonalRelevance.general,
        )

    if high_caffeine:
        apply_delta(
            ScanVerdictLens.energyAndMood,
            -18,
            "Cafeína alta puede dejarte más acelerada y luego pasar factura.",
            context_label="Tu sensibilidad a cafeína" if caffeine_sensitive else None,
            context_direction=ScanVerdictContextDirection.reduce if caffeine_sensitive else None,
            context_explanation="Declaraste sensibilidad; una dosis alta suele sentirse más intensa.",
        )
        apply_delta(
            ScanVerdictLens.hormoneBalance,
            -8,
            "Cafeína alta no es la mejor ancla si hoy buscas estabilidad.",
            context_label="Tu fase lútea" if luteal else None,
            context_direction=ScanVerdictContextDirection.reduce if luteal else None,
            context_explanation="En lútea la cafeína suele sentirse más intensa y menos pareja.",
        )
        if fit_override is None:
            fit_override = ScanVerdictFit.skip if high_sugar or caffeine_sensitive else ScanVerdictFit.occasional
        if primary_reason is None:
            primary_reason = (
                "La combinación actual carga demasiado energía y sistema nervioso para el contexto que describes hoy."
            )
        add_watchout(
            "Cafeína alta",
            "Si ya vienes sensible o en fase lútea, este tipo de producto suele pegar más fuerte.",
            ScanVerdictWatchoutSeverity.important if caffeine_sensitive else ScanVerdictWatchoutSeverity.moderate,
            ScanVerdictPersonalRelevance.personal if caffeine_sensitive or luteal else ScanVerdictPersonalRelevance.general,
        )
        if better_swap is None:
            better_swap = ScanVerdictAlternative(
                productName="Matcha latte bajo en azúcar",
                whyBetter="Da un empuje más parejo y con menos fricción para energía y hormonas.",
                improvedLenses=[
                    ScanVerdictLens.energyAndMood,
                    ScanVerdictLens.hormoneBalance,
                    ScanVerdictLens.gutComfort,
                ],
                expectedLensDeltas=[
                    ScanVerdictLensDelta(lens=ScanVerdictLens.energyAndMood, estimatedChange=26),
                    ScanVerdictLensDelta(lens=ScanVerdictLens.hormoneBalance, estimatedChange=18),
                    ScanVerdictLensDelta(lens=ScanVerdictLens.gutComfort, estimatedChange=12),
                ],
            )

    if bloating_prone:
        apply_delta(
            ScanVerdictLens.gutComfort,
            -10 if high_sugar or high_caffeine else -4,
            "Tu contexto digestivo reciente pide menos fricción, no más.",
            context_label="Tu digestión reciente",
            context_direction=ScanVerdictContextDirection.reduce,
            context_explanation="Vienes reportando inflamación o sensibilidad digestiva reciente.",
        )

    if high_protein and not high_sugar:
        apply_delta(
            ScanVerdictLens.bodyCompositionAndStrength,
            14,
            "Proteína útil suma estructura al lens de fuerza y recuperación.",
        )
        apply_delta(
            ScanVerdictLens.energyAndMood,
            6,
            "Proteína real suele favorecer una energía más pareja.",
        )
        if fit_override is None:
            fit_override = ScanVerdictFit.goodFit
        if primary_reason is None:
            primary_reason = "Lo que más suma aquí es que sí aporta estructura real y no solo un pico rápido."

    if diabetes:
        evidence_tier = ScanVerdictEvidenceTier.high
        disclaimer_lines.append("Consulta con tu equipo médico sobre cualquier ajuste nutricional.")
        add_watchout(
            "Glucosa primero",
            "Si tienes diabetes, evita usar este análisis como señal para cambios drásticos sin revisar tu manejo individual.",
            ScanVerdictWatchoutSeverity.important,
            ScanVerdictPersonalRelevance.clinical,
        )

    if ed_history:
        disclaimer_lines.append("Si este tipo de análisis te activa restricción, prioriza apoyo clínico y una lectura más amable.")

    if _contains_any(request.userContextSummary.lower(), ["recent", "report", "últim", "ultim", "esta semana", "this week"]):
        user_history_factors.append(
            ScanVerdictUserHistoryFactor(
                pattern=_clip(request.userContextSummary.strip(), 280),
                scansReferenced=1,
            )
        )

    average_score = round(sum(scores.values()) / len(scores))
    if fit_override is None:
        if confidence == ScanVerdictConfidence.insufficient:
            fit = ScanVerdictFit.unclear
        elif average_score >= 82:
            fit = ScanVerdictFit.greatFit
        elif average_score >= 70:
            fit = ScanVerdictFit.goodFit
        elif average_score >= 56:
            fit = ScanVerdictFit.occasional
        else:
            fit = ScanVerdictFit.skip
    else:
        fit = fit_override

    if primary_reason is None:
        primary_reason = {
            ScanVerdictFit.greatFit: "Se ve alineado con tu contexto actual y aporta más estructura que fricción.",
            ScanVerdictFit.goodFit: "En balance suma más estabilidad de la que resta para el día que describes.",
            ScanVerdictFit.occasional: "Puede entrar de forma ocasional, pero hoy no se ve como tu mejor ancla.",
            ScanVerdictFit.skip: "Hoy trae más fricción que soporte para el contexto que estás cuidando.",
            ScanVerdictFit.unclear: "No hay resolución suficiente para darte una lectura confiable todavía.",
        }[fit]

    headline = _headline_for_fit(product_name, fit)
    lens_scores = [
        ScanVerdictLensScore(
            lens=lens,
            score=scores[lens],
            trend=_trend_for_score(scores[lens]),
            summary=_lens_summary(lens, scores[lens], fit),
            contextApplied=context_applied[lens],
        )
        for lens in SCAN_VERDICT_LENS_ORDER
    ]

    if fit in {ScanVerdictFit.skip, ScanVerdictFit.occasional} and track_prompt is None:
        target_lens = ScanVerdictLens.gutComfort if bloating_prone else ScanVerdictLens.energyAndMood
        question_text = (
            "¿Cómo se sintió tu digestión después?"
            if target_lens == ScanVerdictLens.gutComfort
            else "¿Cómo te sentiste de energía y calma después?"
        )
        track_prompt = ScanVerdictFollowUpPrompt(
            triggerAfterHours=2 if target_lens == ScanVerdictLens.energyAndMood else 3,
            questionText=question_text,
            targetLens=target_lens,
            expectedResponseType=ScanVerdictFollowUpResponseType.intensityScale,
        )

    insight_lines = []
    if provider_failure:
        insight_lines.append(
            "Se aplicó fallback determinístico local porque el provider no devolvió un payload usable."
        )
    else:
        insight_lines.append("Se aplicó el runtime local validado contra el schema real de ScanVerdict.")
    if resolved_product and resolved_product.source:
        if resolved_product.isDirectional:
            insight_lines.append(
                f"La identidad del producto sigue direccional desde {resolved_product.source.value}; no se forzó un match exacto."
            )
        else:
            insight_lines.append(
                f"La identidad del producto llegó desde {resolved_product.source.value} con confidence {resolved_product.confidence or 0:.2f}."
            )
    if high_caffeine and high_sugar:
        insight_lines.append("La combinación de azúcar alta y cafeína pesó más que cualquier upside puntual.")
    elif high_protein and fit in {ScanVerdictFit.goodFit, ScanVerdictFit.greatFit}:
        insight_lines.append("El aporte estructural de proteína fue la señal positiva dominante.")
    elif pregnancy and tuna:
        insight_lines.append("El guardrail de embarazo limitó la recomendación aunque hubiera proteína útil.")

    agent_insights = [
        ScanVerdictAgentInsight(
            insight=_clip(line, 280),
            modelUsed=f"deterministic-local/{assets.version}",
            confidenceScore=_confidence_score(confidence),
        )
        for line in insight_lines[:2]
    ]

    verdict = ScanVerdict(
        fit=fit,
        confidence=confidence,
        headline=headline,
        primaryReason=_clip(primary_reason, 280),
        lensScores=lens_scores,
        watchouts=watchouts[:2],
        betterSwap=better_swap,
        trackPrompt=track_prompt,
        evidenceTier=evidence_tier,
        reasoningBreakdown=ScanVerdictReasoningBreakdown(
            deterministicFactors=deterministic_factors,
            agentInsights=agent_insights,
            userHistoryFactors=user_history_factors,
            totalAdjustments=len(deterministic_factors)
            + sum(len(factors) for factors in context_applied.values())
            + len(user_history_factors),
        ),
        disclaimer="\n".join(disclaimer_lines + [BASE_DISCLAIMER]) if disclaimer_lines else BASE_DISCLAIMER,
        sources=_sources_from_request(request),
    )
    return assets.validate_verdict(verdict)


def _extract_declared_version(markdown: str) -> str | None:
    match = re.search(r"\*\*Versión:\*\*\s*([^\n]+)", markdown)
    return match.group(1).strip() if match else None


def _sources_from_request(request: ScanVerdictRequest) -> list[ScanVerdictEvidenceSource]:
    sources: list[ScanVerdictEvidenceSource] = []
    if request.resolvedProduct and request.resolvedProduct.source:
        organization = {
            "openFoodFacts": "Open Food Facts",
            "usdaFoodDataCentral": "USDA FoodData Central",
            "localCatalog": "WellnessLens local catalog",
            "agentInferred": "WellnessLens directional resolver",
            "userProvided": "User-provided label text",
            "userEdited": "User-corrected product facts",
            "nihDSLD": "NIH DSLD",
            "cosing": "CosIng",
        }.get(request.resolvedProduct.source.value, request.resolvedProduct.source.value)
        tier = (
            ScanVerdictEvidenceTier.high
            if request.resolvedProduct.confidence is not None and request.resolvedProduct.confidence >= 0.84
            else ScanVerdictEvidenceTier.emerging
        )
        sources.append(
            ScanVerdictEvidenceSource(
                title=request.resolvedProduct.name,
                organization=organization,
                tier=tier,
            )
        )
    return sources


def _extract_runtime_system_prompt(markdown: str) -> str:
    section = markdown.split(SYSTEM_PROMPT_MARKER, 1)[1] if SYSTEM_PROMPT_MARKER in markdown else markdown
    match = re.search(r"```(?:[a-zA-Z0-9_-]+)?\s*(.*?)```", section, re.DOTALL)
    if not match:
        raise ScanVerdictAssetError("LILA_SystemPrompt.md does not contain a fenced system prompt block")
    return match.group(1).strip()


def _extract_json_code_blocks(markdown: str) -> list[dict[str, Any]]:
    payloads: list[dict[str, Any]] = []
    for match in re.finditer(r"```json\s*(.*?)```", markdown, re.DOTALL):
        block = match.group(1).strip()
        payload = json.loads(block)
        if isinstance(payload, dict):
            payloads.append(payload)
    if not payloads:
        raise ScanVerdictAssetError("LILA_GoldenExamples.md does not contain JSON examples")
    return payloads


def _normalize_vertex_json_schema(node: Any) -> Any:
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
                remainder = {key: value for key, value in working.items() if key != "type"}
                return {
                    "anyOf": [
                        _normalize_vertex_json_schema({"type": schema_entry, **remainder})
                        for schema_entry in schema_type
                    ]
                }
        normalized = {key: _normalize_vertex_json_schema(value) for key, value in working.items()}
        if normalized.get("type") == "object" and isinstance(normalized.get("properties"), dict):
            normalized["propertyOrdering"] = list(normalized["properties"].keys())
        return normalized
    if isinstance(node, list):
        return [_normalize_vertex_json_schema(item) for item in node]
    return node


def _contains_any(text: str, needles: list[str]) -> bool:
    return any(needle in text for needle in needles)


def _clamp_score(score: int) -> int:
    return max(0, min(100, score))


def _downgrade_confidence(
    current: ScanVerdictConfidence,
    target: ScanVerdictConfidence,
) -> ScanVerdictConfidence:
    return target if CONFIDENCE_RANK[target] < CONFIDENCE_RANK[current] else current


def _clip(text: str, max_length: int) -> str:
    stripped = " ".join(text.split())
    if len(stripped) <= max_length:
        return stripped
    return stripped[: max_length - 1].rstrip() + "…"


def _trend_for_score(score: int) -> ScanVerdictScoreTrend:
    if score >= 76:
        return ScanVerdictScoreTrend.rising
    if score <= 45:
        return ScanVerdictScoreTrend.falling
    return ScanVerdictScoreTrend.neutral


def _confidence_score(confidence: ScanVerdictConfidence) -> float:
    return {
        ScanVerdictConfidence.high: 0.82,
        ScanVerdictConfidence.medium: 0.64,
        ScanVerdictConfidence.low: 0.46,
        ScanVerdictConfidence.insufficient: 0.28,
    }[confidence]


def _headline_for_fit(product_name: str, fit: ScanVerdictFit) -> str:
    product_name = product_name.strip()
    if fit == ScanVerdictFit.greatFit:
        headline = f"{product_name} sí suma para tu contexto de hoy"
    elif fit == ScanVerdictFit.goodFit:
        headline = f"{product_name} se ve compatible con tu día de hoy"
    elif fit == ScanVerdictFit.occasional:
        headline = f"{product_name} va mejor como algo ocasional hoy"
    elif fit == ScanVerdictFit.skip:
        headline = f"Mejor no {product_name.lower()} hoy"
    else:
        headline = f"No hay claridad suficiente sobre {product_name}"
    return _clip(headline, 90)


def _lens_summary(lens: ScanVerdictLens, score: int, fit: ScanVerdictFit) -> str:
    if lens == ScanVerdictLens.glowAndSkin:
        if score >= 72:
            return "No se ve especialmente conflictivo para piel y glow hoy."
        if score <= 45:
            return "Aquí es donde más se nota el costo para piel y glow."
        return "El impacto en piel y glow se ve más neutro que decisivo."
    if lens == ScanVerdictLens.hormoneBalance:
        if fit == ScanVerdictFit.skip:
            return "Hoy no se alinea bien con estabilidad hormonal y metabólica."
        if score >= 72:
            return "Se sostiene razonablemente bien para balance hormonal."
        return "Este lens depende bastante de tu contexto actual."
    if lens == ScanVerdictLens.gutComfort:
        if score <= 45:
            return "Digestión y confort intestinal son el frente más frágil aquí."
        if score >= 72:
            return "Se ve relativamente amable para digestión hoy."
        return "Digestión queda en rango medio y con algo de variabilidad."
    if lens == ScanVerdictLens.energyAndMood:
        if score <= 45:
            return "La lectura apunta a energía menos pareja y más fricción."
        if score >= 76:
            return "La energía se ve más estable de lo habitual."
        return "Energía y ánimo quedan aceptables, pero no son el upside principal."
    if score >= 74:
        return "Sí aporta algo de estructura a fuerza y composición corporal."
    if score <= 45:
        return "Aporta poco a recuperación o fuerza en el contexto actual."
    return "Este lens queda más bien neutral hoy."
