from __future__ import annotations

import json
import re
import unicodedata

from app.contracts import (
    MexicoWarningLabel,
    NutritionExtractionRequest,
    NutritionExtractionResult,
)
from app.prompt_safety import sanitize_prompt_text


EXTRACTION_SYSTEM_PROMPT = """
Eres el extractor estructurado de WellnessLens Mexico.
Tu tarea es leer texto de etiqueta, OCR, menu o comida y devolver solo JSON valido.
No calcules score nutricional, no diagnostiques y no inventes datos que no esten en el texto.
Si detectas sellos NOM-051 o advertencias visibles, reportalos en warning_labels.
Si el texto es parcial, baja confidence y explica el limite en notes.
"""


def build_nutrition_extraction_task_prompt(request: NutritionExtractionRequest) -> str:
    text = sanitize_prompt_text(request.text, max_length=6000, fallback="")
    return (
        "EXTRACTION TASK\n"
        f"Locale: {sanitize_prompt_text(request.locale, max_length=16, fallback='es-MX')}\n"
        f"Source: {request.source.value}\n"
        "Return JSON matching the NutritionExtractionResult schema.\n\n"
        "USER-CONTROLLED TEXT START\n"
        f"{text}\n"
        "USER-CONTROLLED TEXT END\n"
    )


def build_local_nutrition_extraction(
    request: NutritionExtractionRequest,
    *,
    provider_failure: str | None = None,
) -> NutritionExtractionResult:
    text = sanitize_prompt_text(request.text, max_length=6000, fallback="")
    normalized = _normalize(text)
    labels = _detect_warning_labels(normalized)
    ingredients = _extract_ingredients(text)
    product_name = _guess_product_name(text)
    brand = _guess_brand(text)
    contains_caffeine = any(phrase in normalized for phrase in _CAFFEINE_PHRASES)
    contains_sweetener = any(phrase in normalized for phrase in _SWEETENER_PHRASES)
    notes = _notes_for_result(
        text=text,
        labels=labels,
        contains_caffeine=contains_caffeine,
        contains_sweetener=contains_sweetener,
        provider_failure=provider_failure,
    )

    confidence = 0.28
    if product_name:
        confidence += 0.12
    if ingredients:
        confidence += 0.18
    if labels:
        confidence += 0.18
    if contains_caffeine or contains_sweetener:
        confidence += 0.08
    if len(normalized) < 40:
        confidence = min(confidence, 0.38)

    return NutritionExtractionResult(
        productName=product_name,
        brand=brand,
        warning_labels=labels,
        contains_caffeine_warning=contains_caffeine,
        contains_sweetener_warning=contains_sweetener,
        ingredients=ingredients,
        serving_text=_extract_serving_text(text),
        confidence=round(min(confidence, 0.84), 2),
        notes=notes[:8],
        source="deterministic-local/provider-fallback" if provider_failure else "deterministic-local",
    )


def parse_nutrition_extraction_payload_text(payload_text: str) -> NutritionExtractionResult:
    payload = json.loads(payload_text)
    if isinstance(payload, dict) and "extraction" in payload:
        payload = payload["extraction"]
    return NutritionExtractionResult.model_validate(payload)


_LABEL_PATTERNS: tuple[tuple[MexicoWarningLabel, tuple[str, ...]], ...] = (
    (MexicoWarningLabel.excessCalories, ("exceso calorias", "excess calories")),
    (MexicoWarningLabel.excessSugars, ("exceso azucares", "excess sugars")),
    (MexicoWarningLabel.excessSodium, ("exceso sodio", "excess sodium")),
    (MexicoWarningLabel.excessSaturatedFat, ("exceso grasas saturadas", "excess saturated fat")),
    (MexicoWarningLabel.excessTransFat, ("exceso grasas trans", "excess trans fat")),
)

_CAFFEINE_PHRASES = (
    "contiene cafeina",
    "evitar en ninos",
    "cafeina",
    "caffeine warning",
)

_SWEETENER_PHRASES = (
    "contiene edulcorantes",
    "edulcorante",
    "edulcorantes",
    "sucralosa",
    "acesulfame",
    "aspartame",
    "stevia",
    "sweetener warning",
)


def _detect_warning_labels(normalized: str) -> list[MexicoWarningLabel]:
    labels: list[MexicoWarningLabel] = []
    for label, patterns in _LABEL_PATTERNS:
        if any(pattern in normalized for pattern in patterns):
            labels.append(label)
    return labels


def _extract_ingredients(text: str) -> list[str]:
    match = re.search(r"ingredientes?\s*[:\-]\s*(.+)", text, flags=re.IGNORECASE | re.DOTALL)
    if not match:
        return []
    block = re.split(r"\n|informacion nutrimental|tabla nutrimental|contenido neto", match.group(1), maxsplit=1, flags=re.IGNORECASE)[0]
    values = [re.sub(r"\s+", " ", item.strip(" .;")) for item in block.split(",")]
    return [value for value in values if len(value) >= 2][:40]


def _guess_product_name(text: str) -> str | None:
    for line in _useful_lines(text):
        if not re.search(r"ingredientes?|informacion|tabla|exceso|contiene|porcion", line, flags=re.IGNORECASE):
            return line[:80]
    return None


def _guess_brand(text: str) -> str | None:
    match = re.search(r"(?:marca|brand)\s*[:\-]\s*([^\n]+)", text, flags=re.IGNORECASE)
    if not match:
        return None
    return re.sub(r"\s+", " ", match.group(1).strip())[:80] or None


def _extract_serving_text(text: str) -> str | None:
    match = re.search(r"(porcion|serving)\s*[:\-]?\s*([^\n]{1,120})", text, flags=re.IGNORECASE)
    if not match:
        return None
    return re.sub(r"\s+", " ", match.group(0).strip())[:160]


def _notes_for_result(
    *,
    text: str,
    labels: list[MexicoWarningLabel],
    contains_caffeine: bool,
    contains_sweetener: bool,
    provider_failure: str | None,
) -> list[str]:
    notes: list[str] = []
    if labels:
        notes.append("Sellos NOM-051 detectados en texto.")
    if contains_caffeine:
        notes.append("Advertencia de cafeina detectada.")
    if contains_sweetener:
        notes.append("Advertencia de edulcorantes detectada.")
    if len(_normalize(text)) < 80:
        notes.append("Texto parcial; usar como lectura de baja confianza.")
    if provider_failure:
        notes.append("Provider AI no disponible; se uso extractor local.")
    return notes


def _useful_lines(text: str) -> list[str]:
    lines = [re.sub(r"\s+", " ", line.strip()) for line in text.splitlines()]
    return [line for line in lines if len(line) >= 3]


def _normalize(value: str) -> str:
    without_accents = "".join(
        char for char in unicodedata.normalize("NFKD", value.lower()) if not unicodedata.combining(char)
    )
    return re.sub(r"\s+", " ", without_accents).strip()
