from __future__ import annotations

import re
import unicodedata
from collections.abc import Iterable

from app.contracts import MexicoNutritionSignals, MexicoWarningLabel, NutritionSnapshot


_LABEL_PATTERNS: tuple[tuple[MexicoWarningLabel, tuple[str, ...]], ...] = (
    (MexicoWarningLabel.excessCalories, ("exceso calorias", "exceso calorías", "excess calories")),
    (MexicoWarningLabel.excessSugars, ("exceso azucares", "exceso azúcares", "excess sugars")),
    (MexicoWarningLabel.excessSodium, ("exceso sodio", "excess sodium")),
    (MexicoWarningLabel.excessSaturatedFat, ("exceso grasas saturadas", "excess saturated fat")),
    (MexicoWarningLabel.excessTransFat, ("exceso grasas trans", "excess trans fat")),
)

_CAFFEINE_PHRASES = (
    "contiene cafeina",
    "contiene cafeína",
    "evitar en ninos",
    "evitar en niños",
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


def infer_mexico_nutrition_signals(
    *,
    text_parts: Iterable[str | None] = (),
    snapshot: NutritionSnapshot | None = None,
) -> MexicoNutritionSignals | None:
    raw_text = " ".join(part.strip() for part in text_parts if part and part.strip())
    normalized = _normalize(raw_text)
    labels: list[MexicoWarningLabel] = []
    phrases: list[str] = []

    for label, patterns in _LABEL_PATTERNS:
        if any(_normalize(pattern) in normalized for pattern in patterns):
            labels.append(label)
            phrases.append(_label_title(label))

    for label in _threshold_labels(snapshot):
        if label not in labels:
            labels.append(label)
            phrases.append(_threshold_phrase(label))

    contains_caffeine_warning = any(_normalize(phrase) in normalized for phrase in _CAFFEINE_PHRASES)
    contains_sweetener_warning = any(_normalize(phrase) in normalized for phrase in _SWEETENER_PHRASES)
    if contains_caffeine_warning:
        phrases.append("Contiene cafeina")
    if contains_sweetener_warning:
        phrases.append("Contiene edulcorantes")

    signal = MexicoNutritionSignals(
        warning_labels=_ordered_labels(labels),
        contains_caffeine_warning=contains_caffeine_warning,
        contains_sweetener_warning=contains_sweetener_warning,
        detected_phrases=_dedupe(phrases)[:8],
        source="deterministic",
    )
    return signal if signal.has_signal else None


def mexico_signal_titles(signal: MexicoNutritionSignals | None) -> list[str]:
    if signal is None:
        return []
    titles = [_label_title(label) for label in signal.warningLabels]
    if signal.containsCaffeineWarning:
        titles.append("Contiene cafeina")
    if signal.containsSweetenerWarning:
        titles.append("Contiene edulcorantes")
    return _dedupe(titles)


def _threshold_labels(snapshot: NutritionSnapshot | None) -> list[MexicoWarningLabel]:
    if snapshot is None:
        return []

    labels: list[MexicoWarningLabel] = []
    energy = snapshot.energyKcalPer100g
    sugars = snapshot.sugarsGPer100g
    sodium = snapshot.sodiumMgPer100g

    if energy is not None and energy >= 275:
        labels.append(MexicoWarningLabel.excessCalories)
    if sugars is not None:
        if sugars >= 10:
            labels.append(MexicoWarningLabel.excessSugars)
        elif energy and energy > 0 and (sugars * 4 / energy) >= 0.10 and sugars >= 5:
            labels.append(MexicoWarningLabel.excessSugars)
    if sodium is not None:
        if sodium >= 300:
            labels.append(MexicoWarningLabel.excessSodium)
        elif energy and energy > 0 and sodium / energy >= 1:
            labels.append(MexicoWarningLabel.excessSodium)

    return _ordered_labels(labels)


def _ordered_labels(labels: Iterable[MexicoWarningLabel]) -> list[MexicoWarningLabel]:
    order = list(MexicoWarningLabel)
    seen = set(labels)
    return [label for label in order if label in seen]


def _label_title(label: MexicoWarningLabel) -> str:
    return {
        MexicoWarningLabel.excessCalories: "Exceso calorias",
        MexicoWarningLabel.excessSugars: "Exceso azucares",
        MexicoWarningLabel.excessSodium: "Exceso sodio",
        MexicoWarningLabel.excessSaturatedFat: "Exceso grasas saturadas",
        MexicoWarningLabel.excessTransFat: "Exceso grasas trans",
    }[label]


def _threshold_phrase(label: MexicoWarningLabel) -> str:
    return f"{_label_title(label)} por umbral nutrimental"


def _dedupe(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        cleaned = re.sub(r"\s+", " ", value.strip())
        if not cleaned:
            continue
        key = _normalize(cleaned)
        if key in seen:
            continue
        seen.add(key)
        result.append(cleaned)
    return result


def _normalize(value: str) -> str:
    without_accents = "".join(
        char for char in unicodedata.normalize("NFKD", value.lower()) if not unicodedata.combining(char)
    )
    return re.sub(r"\s+", " ", without_accents).strip()
