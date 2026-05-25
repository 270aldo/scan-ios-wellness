from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import logging
from math import isfinite
import re
from time import monotonic
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.parse import quote_plus
from urllib.request import Request, urlopen

from app.config import Settings
from app.contracts import (
    ConfidenceLevel,
    Ingredient,
    IngredientTag,
    NutritionSnapshot,
    ProductCandidate,
    ProductResolution,
    ProductResolutionSource,
    ProductType,
    ScanInput,
    ScanSource,
)
from app.mexico_nutrition import infer_mexico_nutrition_signals, mexico_signal_titles
from app.product_resolution_semantics import ensure_product_resolution_semantics


logger = logging.getLogger(__name__)

OFF_PRODUCT_FIELDS = ",".join(
    [
        "code",
        "product_name",
        "brands",
        "ingredients_text",
        "ingredients_tags",
        "categories_tags",
        "labels_tags",
        "image_front_url",
        "nutrition_data",
        "nutrition_data_per",
        "nutriments",
    ]
)
OFF_SEARCH_FIELDS = ",".join(
    [
        "code",
        "product_name",
        "brands",
        "ingredients_text",
        "ingredients_tags",
        "categories_tags",
        "labels_tags",
        "nutrition_data",
        "nutriments",
    ]
)
STOPWORDS = {
    "and",
    "con",
    "de",
    "del",
    "for",
    "ingredients",
    "ingredient",
    "la",
    "las",
    "los",
    "por",
    "the",
    "with",
    "without",
    "y",
}


@dataclass
class ResolverResult:
    product: ProductCandidate
    confidence: ConfidenceLevel
    resolution_confidence: float
    is_directional: bool
    identity_source: ProductResolutionSource
    fact_sources: tuple[ProductResolutionSource, ...] = ()
    fallback_reason: str | None = None


@dataclass
class _CacheEntry:
    expires_at: float
    value: ResolverResult


class ProductResolver:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._cache: dict[str, _CacheEntry] = {}

    def resolve(self, input: ScanInput) -> ResolverResult:
        started_at = monotonic()
        cache_key = self._cache_key(input)
        cached = self._get_cached(cache_key)
        if cached is not None:
            self._log_result(input, cached, started_at, cached=True)
            return cached

        result = self._resolve_identity(input)
        result = self._maybe_enrich_with_usda(result, input)
        self._set_cached(cache_key, result)
        self._log_result(input, result, started_at, cached=False)
        return result

    def _resolve_identity(self, input: ScanInput) -> ResolverResult:
        off_step = _OpenFoodFactsIdentityStep(self._settings, self._get_json)
        dsld_step = _DSLDSupplementIdentityStep(self._settings, self._get_json)
        mexico_seed_step = _MexicoSeedCatalogStep()

        if input.productTypeHint == ProductType.supplement:
            return dsld_step.resolve(input)

        off_result = off_step.resolve(input)
        if input.productTypeHint not in {None, ProductType.food}:
            return off_result

        if (
            off_result.is_directional
            and input.barcode
            and input.sourceType in {ScanSource.liveBarcode, ScanSource.manualBarcode}
        ):
            dsld_result = dsld_step.resolve(input)
            if not dsld_result.is_directional:
                return dsld_result

        if off_result.is_directional:
            mexico_seed_result = mexico_seed_step.resolve(input)
            if mexico_seed_result is not None:
                return mexico_seed_result

        return off_result

    def _maybe_enrich_with_usda(self, result: ResolverResult, input: ScanInput) -> ResolverResult:
        if result.identity_source == ProductResolutionSource.nihDSLD:
            return result
        return _USDANutritionEnrichmentStep(self._settings, self._post_json).enrich(result, input)

    def _get_json(self, url: str) -> dict[str, Any]:
        request = Request(
            url,
            headers={
                "Accept": "application/json",
                "User-Agent": self._settings.open_food_facts_user_agent,
            },
        )
        with urlopen(request, timeout=self._settings.resolver_request_timeout_seconds) as response:
            return json.loads(response.read().decode("utf-8"))

    def _post_json(
        self,
        url: str,
        payload: dict[str, Any],
        *,
        extra_headers: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        headers: dict[str, str] = {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": self._settings.open_food_facts_user_agent,
        }
        if extra_headers:
            headers.update(extra_headers)
        request = Request(
            url,
            method="POST",
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
        )
        with urlopen(request, timeout=self._settings.resolver_request_timeout_seconds) as response:
            return json.loads(response.read().decode("utf-8"))

    def _cache_key(self, input: ScanInput) -> str:
        product_scope = input.productTypeHint.value if input.productTypeHint else "auto"
        source_scope = input.sourceType.value
        if input.barcode and input.sourceType in {ScanSource.liveBarcode, ScanSource.manualBarcode}:
            return f"{product_scope}:{source_scope}:barcode:{_normalize_barcode(input.barcode) or input.barcode.strip()}"
        raw_text = (input.rawText or "").strip().lower()
        digest = hashlib.sha1(raw_text.encode("utf-8")).hexdigest()[:20]
        return f"{product_scope}:{source_scope}:text:{digest}"

    def _get_cached(self, key: str) -> ResolverResult | None:
        entry = self._cache.get(key)
        if entry is None:
            return None
        if entry.expires_at <= monotonic():
            self._cache.pop(key, None)
            return None
        return entry.value

    def _set_cached(self, key: str, value: ResolverResult) -> None:
        if len(self._cache) >= self._settings.resolver_cache_max_entries:
            expired = [cache_key for cache_key, entry in self._cache.items() if entry.expires_at <= monotonic()]
            for cache_key in expired:
                self._cache.pop(cache_key, None)
            if len(self._cache) >= self._settings.resolver_cache_max_entries and self._cache:
                oldest_key = min(self._cache, key=lambda cache_key: self._cache[cache_key].expires_at)
                self._cache.pop(oldest_key, None)
        self._cache[key] = _CacheEntry(
            expires_at=monotonic() + self._settings.resolver_cache_ttl_seconds,
            value=value,
        )

    def _log_result(self, input: ScanInput, result: ResolverResult, started_at: float, *, cached: bool) -> None:
        latency_ms = int((monotonic() - started_at) * 1000)
        resolution = result.product.resolution
        fact_sources = ",".join(source.value for source in result.fact_sources) or "none"
        logger.info(
            "product_resolver identity_source=%s fact_sources=%s scan_source=%s cached=%s confidence=%.3f directional=%s latency_ms=%d fallback_reason=%s product_id=%s",
            result.identity_source.value,
            fact_sources,
            input.sourceType.value,
            cached,
            resolution.confidence if resolution else result.resolution_confidence,
            resolution.isDirectional if resolution else result.is_directional,
            latency_ms,
            result.fallback_reason or "none",
            result.product.id,
        )


class _ProductCandidateFactory:
    def off_product_to_candidate(
        self,
        product: dict[str, Any],
        *,
        resolution_confidence: float,
        is_directional: bool,
        headline: str,
    ) -> ProductCandidate:
        code = str(product.get("code") or "").strip()
        name = _clean_text(product.get("product_name"))
        if not name:
            name = f"Product {code[-4:]}" if code else "Resolved product"
        brand = _primary_brand(product.get("brands"))
        ingredients_text = _clean_text(product.get("ingredients_text"))
        ingredients_tags = _string_list(product.get("ingredients_tags"))
        categories_tags = _string_list(product.get("categories_tags"))
        labels_tags = _string_list(product.get("labels_tags"))
        snapshot = _off_nutrition_to_snapshot(product.get("nutriments"))
        tags = _infer_tags(
            name=name,
            ingredients_text=ingredients_text,
            ingredient_tags=ingredients_tags,
            labels_tags=labels_tags,
            snapshot=snapshot,
        )
        mexico_signals = infer_mexico_nutrition_signals(
            text_parts=[name, brand, ingredients_text, " ".join(labels_tags), " ".join(categories_tags)],
            snapshot=snapshot,
        )
        notes = [f"Source: Open Food Facts ({'directional' if is_directional else 'resolved'})."]
        notes.extend(f"Mexico label signal: {title}." for title in mexico_signal_titles(mexico_signals))
        candidate = ProductCandidate(
            id=f"off:{code or hashlib.sha1(name.encode('utf-8')).hexdigest()[:12]}",
            name=name,
            brand=brand,
            productType=ProductType.food,
            barcode=code or None,
            headline=headline,
            ingredients=[Ingredient(name=item) for item in _ingredient_lines(ingredients_text, ingredients_tags)],
            claims=_claims_from_labels(labels_tags),
            tags=tags,
            alternativeIDs=[],
            notes=notes,
            lookupTokens=_lookup_tokens(name, brand, ingredients_text, categories_tags),
            resolution=ProductResolution(
                canonicalProductID=f"off:{code}" if code else None,
                source=ProductResolutionSource.openFoodFacts,
                confidence=round(resolution_confidence, 3),
                nutritionSnapshot=snapshot,
                isDirectional=is_directional,
            ),
            mexicoNutritionSignals=mexico_signals,
        )
        return ensure_product_resolution_semantics(candidate)

    def dsld_product_to_candidate(
        self,
        label_payload: dict[str, Any],
        *,
        resolution_confidence: float,
        headline: str,
        search_hit: dict[str, Any] | None = None,
    ) -> ProductCandidate:
        label_id = str(label_payload.get("id") or (search_hit or {}).get("_id") or "").strip()
        source_payload = search_hit.get("_source") if isinstance(search_hit, dict) else None
        if not isinstance(source_payload, dict):
            source_payload = {}

        name = _clean_text(label_payload.get("fullName")) or _clean_text(source_payload.get("fullName")) or "Supplement label"
        brand = _clean_text(label_payload.get("brandName")) or _clean_text(source_payload.get("brandName")) or "NIH DSLD"
        barcode = _normalize_barcode(label_payload.get("upcSku")) or None
        ingredient_lines = _dsld_ingredient_lines(label_payload, search_hit=search_hit)
        statement_text = _dsld_statement_text(label_payload)
        claims = _dsld_claims(label_payload, search_hit=search_hit)
        product_type_description = _clean_text((label_payload.get("productType") or {}).get("langualCodeDescription"))
        lookup_context = " ".join(part for part in [statement_text, product_type_description] if part)

        candidate = ProductCandidate(
            id=f"dsld:{label_id or hashlib.sha1(name.encode('utf-8')).hexdigest()[:12]}",
            name=name,
            brand=brand,
            productType=ProductType.supplement,
            barcode=barcode,
            headline=headline,
            ingredients=[Ingredient(name=item) for item in ingredient_lines],
            claims=claims,
            tags=_infer_tags(
                name=name,
                ingredients_text=" ".join(ingredient_lines + claims + ([lookup_context] if lookup_context else [])),
                ingredient_tags=[],
                labels_tags=[],
                snapshot=None,
            ),
            alternativeIDs=[],
            notes=["Source: NIH DSLD (resolved)."],
            lookupTokens=_lookup_tokens(
                name,
                brand,
                " ".join(ingredient_lines + claims + ([lookup_context] if lookup_context else [])),
                [product_type_description] if product_type_description else [],
            ),
            resolution=ProductResolution(
                canonicalProductID=f"dsld:{label_id}" if label_id else None,
                source=ProductResolutionSource.nihDSLD,
                confidence=round(resolution_confidence, 3),
                nutritionSnapshot=None,
                isDirectional=False,
            ),
        )
        return ensure_product_resolution_semantics(candidate)

    def build_directional_result(
        self,
        input: ScanInput,
        *,
        fallback_reason: str,
        confidence_score: float,
        source: ProductResolutionSource,
    ) -> ResolverResult:
        raw_text = (input.rawText or "").strip()
        product_type = input.productTypeHint or ProductType.food
        product_name = _directional_name(input, raw_text)
        tag_text = raw_text or product_name
        tags = _infer_tags(
            name=product_name,
            ingredients_text=raw_text,
            ingredient_tags=[],
            labels_tags=[],
            snapshot=None,
        )
        mexico_signals = infer_mexico_nutrition_signals(text_parts=[product_name, raw_text], snapshot=None)
        notes = [
            "No exact packaged-food match was found yet.",
            "Use this read directionally and rescan when a clearer barcode or label is available.",
        ]
        notes.extend(f"Mexico label signal: {title}." for title in mexico_signal_titles(mexico_signals))
        resolution = ProductResolution(
            canonicalProductID=None,
            source=source,
            confidence=round(confidence_score, 3),
            nutritionSnapshot=None,
            isDirectional=True,
        )
        product = ProductCandidate(
            id=f"directional:{hashlib.sha1((input.barcode or raw_text or product_name).encode('utf-8')).hexdigest()[:12]}",
            name=product_name,
            brand="Directional read",
            productType=product_type,
            barcode=(input.barcode or "").strip() or None,
            headline="No exact packaged-food match yet. This read is directional.",
            ingredients=[Ingredient(name=item) for item in _ingredient_lines(raw_text, [])],
            claims=[],
            tags=tags,
            alternativeIDs=[],
            notes=notes,
            lookupTokens=_lookup_tokens(product_name, "Directional read", tag_text, []),
            resolution=resolution,
            mexicoNutritionSignals=mexico_signals,
        )
        confidence = ConfidenceLevel.low if confidence_score < 0.6 else ConfidenceLevel.medium
        product = ensure_product_resolution_semantics(
            product,
            confidence=confidence,
            identity_source=source,
            fact_sources=(source,),
        )
        return ResolverResult(
            product=product,
            confidence=confidence,
            resolution_confidence=confidence_score,
            is_directional=True,
            identity_source=source,
            fact_sources=(source,),
            fallback_reason=fallback_reason,
        )


class _MexicoSeedCatalogStep:
    def __init__(self) -> None:
        self._products = _mexico_seed_products()

    def resolve(self, input: ScanInput) -> ResolverResult | None:
        if input.productTypeHint not in {None, ProductType.food}:
            return None

        barcode = _normalize_barcode(input.barcode)
        if barcode:
            for product in self._products:
                if product.barcode == barcode:
                    return self._result(product, confidence=ConfidenceLevel.high, score=0.87)

        raw_text = (input.rawText or "").strip()
        if not raw_text:
            return None

        query_tokens = _meaningful_tokens(raw_text)
        if len(query_tokens) < 2:
            return None

        scored = [
            (_token_overlap(query_tokens, set(product.lookupTokens)), product)
            for product in self._products
        ]
        scored.sort(key=lambda item: item[0], reverse=True)
        top_score, top_product = scored[0]
        if top_score < 0.34:
            return None

        confidence = ConfidenceLevel.medium if top_score < 0.62 else ConfidenceLevel.high
        return self._result(top_product, confidence=confidence, score=max(0.62, min(0.88, top_score + 0.26)))

    def _result(self, product: ProductCandidate, *, confidence: ConfidenceLevel, score: float) -> ResolverResult:
        product = ensure_product_resolution_semantics(
            product,
            confidence=confidence,
            identity_source=ProductResolutionSource.localCatalog,
            fact_sources=(ProductResolutionSource.localCatalog,),
        )
        return ResolverResult(
            product=product,
            confidence=confidence,
            resolution_confidence=score,
            is_directional=False,
            identity_source=ProductResolutionSource.localCatalog,
            fact_sources=(ProductResolutionSource.localCatalog,),
        )


class _OpenFoodFactsIdentityStep:
    def __init__(
        self,
        settings: Settings,
        fetch_json: Callable[[str], dict[str, Any]],
    ) -> None:
        self._settings = settings
        self._fetch_json = fetch_json
        self._factory = _ProductCandidateFactory()

    def resolve(self, input: ScanInput) -> ResolverResult:
        if input.productTypeHint not in {None, ProductType.food}:
            return self._directional(
                input,
                fallback_reason="food_first_scope",
                confidence_score=0.32,
            )
        if input.barcode and input.sourceType in {ScanSource.liveBarcode, ScanSource.manualBarcode}:
            return self._resolve_barcode(input)
        if input.sourceType in {ScanSource.mealPhoto, ScanSource.menuPhoto}:
            return self._directional(
                input,
                fallback_reason="non_packaged_directional_mode",
                confidence_score=0.34 if input.sourceType == ScanSource.menuPhoto else 0.38,
            )
        if input.rawText:
            return self._resolve_label_text(input)
        return self._directional(
            input,
            fallback_reason="empty_input",
            confidence_score=0.18,
        )

    def _resolve_barcode(self, input: ScanInput) -> ResolverResult:
        barcode = (input.barcode or "").strip()
        if not barcode:
            return self._directional(
                input,
                fallback_reason="blank_barcode",
                confidence_score=0.18,
            )

        try:
            payload = self._fetch_json(
                f"{self._settings.open_food_facts_base_url}/api/v2/product/{quote_plus(barcode)}.json"
                f"?fields={OFF_PRODUCT_FIELDS}"
            )
        except (HTTPError, URLError, TimeoutError) as exc:
            return self._directional(
                input,
                fallback_reason=f"off_barcode_error:{exc.__class__.__name__}",
                confidence_score=0.24,
            )

        product_payload = payload.get("product") if isinstance(payload, dict) else None
        status = payload.get("status") if isinstance(payload, dict) else None
        if status != 1 or not isinstance(product_payload, dict):
            return self._directional(
                input,
                fallback_reason="off_barcode_miss",
                confidence_score=0.28,
            )

        resolution_confidence = 0.93 if product_payload.get("nutrition_data") == "on" else 0.86
        product = self._factory.off_product_to_candidate(
            product_payload,
            resolution_confidence=resolution_confidence,
            is_directional=False,
            headline="Exact barcode match from Open Food Facts.",
        )
        return ResolverResult(
            product=product,
            confidence=ConfidenceLevel.high,
            resolution_confidence=resolution_confidence,
            is_directional=False,
            identity_source=ProductResolutionSource.openFoodFacts,
            fact_sources=(ProductResolutionSource.openFoodFacts,),
        )

    def _resolve_label_text(self, input: ScanInput) -> ResolverResult:
        raw_text = (input.rawText or "").strip()
        meaningful_tokens = _meaningful_tokens(raw_text)
        if len(meaningful_tokens) < 2:
            return self._directional(
                input,
                fallback_reason="label_text_too_thin",
                confidence_score=0.34,
            )

        try:
            payload = self._fetch_json(
                f"{self._settings.open_food_facts_base_url}/api/v2/search"
                f"?search_terms={quote_plus(raw_text[:180])}"
                f"&fields={OFF_SEARCH_FIELDS}"
                f"&page_size=6"
            )
        except (HTTPError, URLError, TimeoutError) as exc:
            return self._directional(
                input,
                fallback_reason=f"off_search_error:{exc.__class__.__name__}",
                confidence_score=0.38,
            )

        products = payload.get("products") if isinstance(payload, dict) else None
        if not isinstance(products, list) or not products:
            return self._directional(
                input,
                fallback_reason="off_search_empty",
                confidence_score=0.42,
            )

        scored = [
            (self._score_search_hit(product, meaningful_tokens), product)
            for product in products
            if isinstance(product, dict)
        ]
        scored = [item for item in scored if item[0] > 0]
        if not scored:
            return self._directional(
                input,
                fallback_reason="off_search_unranked",
                confidence_score=0.42,
            )

        scored.sort(key=lambda item: item[0], reverse=True)
        top_score, top_product = scored[0]
        next_score = scored[1][0] if len(scored) > 1 else 0.0
        if top_score < 0.68 or top_score < next_score + 0.08:
            return self._directional(
                input,
                fallback_reason="off_search_low_confidence",
                confidence_score=min(0.56, max(top_score, 0.44)),
            )

        confidence_level = ConfidenceLevel.high if top_score >= 0.83 else ConfidenceLevel.medium
        product = self._factory.off_product_to_candidate(
            top_product,
            resolution_confidence=top_score,
            is_directional=False,
            headline="Resolved from label text against Open Food Facts.",
        )
        return ResolverResult(
            product=product,
            confidence=confidence_level,
            resolution_confidence=top_score,
            is_directional=False,
            identity_source=ProductResolutionSource.openFoodFacts,
            fact_sources=(ProductResolutionSource.openFoodFacts,),
        )

    def _directional(
        self,
        input: ScanInput,
        *,
        fallback_reason: str,
        confidence_score: float,
    ) -> ResolverResult:
        return self._factory.build_directional_result(
            input,
            fallback_reason=fallback_reason,
            confidence_score=confidence_score,
            source=ProductResolutionSource.agentInferred,
        )

    def _score_search_hit(self, product: dict[str, Any], query_tokens: set[str]) -> float:
        name_tokens = _meaningful_tokens(_clean_text(product.get("product_name")) or "")
        brand_tokens = _meaningful_tokens(_clean_text(product.get("brands")) or "")
        ingredient_tokens = _meaningful_tokens(_clean_text(product.get("ingredients_text")) or "")
        category_tokens = _meaningful_tokens(" ".join(_string_list(product.get("categories_tags"))))

        coverage = _token_overlap(query_tokens, name_tokens | brand_tokens | ingredient_tokens)
        name_overlap = _token_overlap(query_tokens, name_tokens)
        ingredient_overlap = _token_overlap(query_tokens, ingredient_tokens)
        nutrition_bonus = 0.08 if product.get("nutrition_data") == "on" else 0.0
        category_bonus = 0.04 if category_tokens else 0.0
        return min(0.95, coverage * 0.60 + name_overlap * 0.22 + ingredient_overlap * 0.12 + nutrition_bonus + category_bonus)


class _DSLDSupplementIdentityStep:
    def __init__(
        self,
        settings: Settings,
        fetch_json: Callable[[str], dict[str, Any]],
    ) -> None:
        self._settings = settings
        self._fetch_json = fetch_json
        self._factory = _ProductCandidateFactory()

    def resolve(self, input: ScanInput) -> ResolverResult:
        if input.sourceType in {ScanSource.mealPhoto, ScanSource.menuPhoto}:
            return self._directional(
                input,
                fallback_reason="dsld_non_packaged_directional_mode",
                confidence_score=0.34 if input.sourceType == ScanSource.menuPhoto else 0.38,
            )

        if input.barcode and input.sourceType in {ScanSource.liveBarcode, ScanSource.manualBarcode}:
            return self._resolve_barcode(input)

        raw_text = (input.rawText or "").strip()
        if raw_text:
            return self._resolve_label_text(input, raw_text)

        return self._directional(
            input,
            fallback_reason="dsld_empty_input",
            confidence_score=0.18,
        )

    def _resolve_barcode(self, input: ScanInput) -> ResolverResult:
        barcode = _normalize_barcode(input.barcode)
        if not barcode:
            return self._directional(
                input,
                fallback_reason="dsld_blank_barcode",
                confidence_score=0.18,
            )

        try:
            payload = self._fetch_json(
                f"{self._settings.nih_dsld_base_url.rstrip('/')}/search-filter"
                f"?q={quote_plus(barcode)}"
                f"&size=6&status=1&sort_by=_score&sort_order=desc"
            )
        except (HTTPError, URLError, TimeoutError) as exc:
            return self._directional(
                input,
                fallback_reason=f"dsld_barcode_error:{exc.__class__.__name__}",
                confidence_score=0.24,
            )

        hits = payload.get("hits") if isinstance(payload, dict) else None
        if not isinstance(hits, list) or not hits:
            return self._directional(
                input,
                fallback_reason="dsld_barcode_empty",
                confidence_score=0.28,
            )

        for hit in hits[:4]:
            if not isinstance(hit, dict):
                continue
            label = self._fetch_label(str(hit.get("_id") or "").strip())
            if label is None:
                continue
            if _normalize_barcode(label.get("upcSku")) != barcode:
                continue

            product = self._factory.dsld_product_to_candidate(
                label,
                resolution_confidence=0.94,
                headline="Supplement barcode matched in NIH DSLD.",
                search_hit=hit,
            )
            return ResolverResult(
                product=product,
                confidence=ConfidenceLevel.high,
                resolution_confidence=0.94,
                is_directional=False,
                identity_source=ProductResolutionSource.nihDSLD,
                fact_sources=(ProductResolutionSource.nihDSLD,),
            )

        return self._directional(
            input,
            fallback_reason="dsld_barcode_low_confidence",
            confidence_score=0.32,
        )

    def _resolve_label_text(self, input: ScanInput, raw_text: str) -> ResolverResult:
        meaningful_tokens = _meaningful_tokens(raw_text)
        if len(meaningful_tokens) < 2:
            return self._directional(
                input,
                fallback_reason="dsld_label_text_too_thin",
                confidence_score=0.34,
            )

        try:
            payload = self._fetch_json(
                f"{self._settings.nih_dsld_base_url.rstrip('/')}/search-filter"
                f"?q={quote_plus(raw_text[:180])}"
                f"&size=6&status=1&sort_by=_score&sort_order=desc"
            )
        except (HTTPError, URLError, TimeoutError) as exc:
            return self._directional(
                input,
                fallback_reason=f"dsld_search_error:{exc.__class__.__name__}",
                confidence_score=0.38,
            )

        hits = payload.get("hits") if isinstance(payload, dict) else None
        if not isinstance(hits, list) or not hits:
            return self._directional(
                input,
                fallback_reason="dsld_search_empty",
                confidence_score=0.42,
            )

        scored = [
            (self._score_search_hit(hit, meaningful_tokens, raw_text), hit)
            for hit in hits
            if isinstance(hit, dict)
        ]
        scored = [item for item in scored if item[0] > 0]
        if not scored:
            return self._directional(
                input,
                fallback_reason="dsld_search_unranked",
                confidence_score=0.42,
            )

        scored.sort(key=lambda item: item[0], reverse=True)
        top_score, top_hit = scored[0]
        next_score = scored[1][0] if len(scored) > 1 else 0.0
        if top_score < 0.70 or top_score < next_score + 0.08:
            return self._directional(
                input,
                fallback_reason="dsld_search_low_confidence",
                confidence_score=min(0.56, max(top_score, 0.44)),
            )

        label = self._fetch_label(str(top_hit.get("_id") or "").strip())
        if label is None:
            return self._directional(
                input,
                fallback_reason="dsld_label_fetch_failed",
                confidence_score=0.40,
            )

        confidence_level = ConfidenceLevel.high if top_score >= 0.84 else ConfidenceLevel.medium
        product = self._factory.dsld_product_to_candidate(
            label,
            resolution_confidence=top_score,
            headline="Resolved from NIH DSLD supplement labels.",
            search_hit=top_hit,
        )
        return ResolverResult(
            product=product,
            confidence=confidence_level,
            resolution_confidence=top_score,
            is_directional=False,
            identity_source=ProductResolutionSource.nihDSLD,
            fact_sources=(ProductResolutionSource.nihDSLD,),
        )

    def _fetch_label(self, label_id: str) -> dict[str, Any] | None:
        if not label_id:
            return None
        try:
            payload = self._fetch_json(
                f"{self._settings.nih_dsld_base_url.rstrip('/')}/label/{quote_plus(label_id)}"
            )
        except (HTTPError, URLError, TimeoutError):
            return None
        return payload if isinstance(payload, dict) else None

    def _directional(
        self,
        input: ScanInput,
        *,
        fallback_reason: str,
        confidence_score: float,
    ) -> ResolverResult:
        return self._factory.build_directional_result(
            input,
            fallback_reason=fallback_reason,
            confidence_score=confidence_score,
            source=ProductResolutionSource.agentInferred,
        )

    def _score_search_hit(
        self,
        hit: dict[str, Any],
        query_tokens: set[str],
        raw_query: str,
    ) -> float:
        source = hit.get("_source")
        if not isinstance(source, dict):
            return 0.0

        name = _clean_text(source.get("fullName")) or ""
        brand = _clean_text(source.get("brandName")) or ""
        ingredient_text = " ".join(_dsld_search_hit_ingredient_text(source))
        claim_text = " ".join(_dsld_search_hit_claim_text(source))
        type_text = _clean_text((source.get("productType") or {}).get("langualCodeDescription")) or ""

        name_tokens = _meaningful_tokens(name)
        brand_tokens = _meaningful_tokens(brand)
        ingredient_tokens = _meaningful_tokens(ingredient_text)
        claim_tokens = _meaningful_tokens(" ".join(part for part in [claim_text, type_text] if part))

        coverage = _token_overlap(query_tokens, name_tokens | brand_tokens | ingredient_tokens | claim_tokens)
        name_overlap = _token_overlap(query_tokens, name_tokens)
        ingredient_overlap = _token_overlap(query_tokens, ingredient_tokens)
        claim_overlap = _token_overlap(query_tokens, claim_tokens)

        normalized_query = _normalized_query_text(raw_query)
        normalized_name = _normalized_query_text(name)
        exact_bonus = 0.08 if normalized_query and normalized_name and (
            normalized_query in normalized_name or normalized_name in normalized_query
        ) else 0.0
        brand_bonus = 0.03 if brand_tokens else 0.0

        return min(
            0.96,
            coverage * 0.50
            + name_overlap * 0.24
            + ingredient_overlap * 0.16
            + claim_overlap * 0.07
            + exact_bonus
            + brand_bonus,
        )


class _USDANutritionEnrichmentStep:
    def __init__(
        self,
        settings: Settings,
        post_json: Callable[[str, dict[str, Any]], dict[str, Any]],
    ) -> None:
        self._settings = settings
        self._post_json = post_json

    def enrich(self, result: ResolverResult, input: ScanInput) -> ResolverResult:
        if result.is_directional or not self._settings.usda_api_key:
            return result
        resolution = result.product.resolution
        if resolution is None:
            return result
        if _nutrition_is_complete_enough(resolution.nutritionSnapshot):
            return result

        usda_food = self._search_food(result.product, input)
        if usda_food is None:
            return result

        snapshot = _usda_food_to_snapshot(usda_food)
        if snapshot is None or not _snapshot_adds_signal(snapshot, resolution.nutritionSnapshot):
            return result

        updated_product = result.product.model_copy(
            update={
                "notes": list(result.product.notes)
                + ["Nutrient snapshot enriched with USDA FoodData Central."],
                "resolution": resolution.model_copy(update={"nutritionSnapshot": snapshot}),
            }
        )
        fact_sources = _append_fact_source(result.fact_sources, ProductResolutionSource.usdaFoodDataCentral)
        updated_product = ensure_product_resolution_semantics(
            updated_product,
            confidence=result.confidence,
            identity_source=result.identity_source,
            fact_sources=fact_sources,
        )
        return ResolverResult(
            product=updated_product,
            confidence=result.confidence,
            resolution_confidence=result.resolution_confidence,
            is_directional=False,
            identity_source=result.identity_source,
            fact_sources=fact_sources,
            fallback_reason=result.fallback_reason,
        )

    def _search_food(self, product: ProductCandidate, input: ScanInput) -> dict[str, Any] | None:
        api_key = (self._settings.usda_api_key or "").strip()
        if not api_key:
            return None
        try:
            # USDA FoodData Central accepts `X-Api-Key` as an alternative to
            # the `api_key` query string. Keeping the key out of the URL
            # prevents accidental disclosure through access logs, upstream
            # retries, or exception messages that capture the full URL.
            payload = self._post_json(
                f"{self._settings.usda_base_url}/foods/search",
                {
                    "query": " ".join(part for part in [product.brand, product.name] if part).strip() or product.name,
                    "dataType": ["Branded"],
                    "pageSize": 5,
                },
                extra_headers={"X-Api-Key": api_key},
            )
        except (HTTPError, URLError, TimeoutError):
            return None

        foods = payload.get("foods") if isinstance(payload, dict) else None
        if not isinstance(foods, list):
            return None

        barcode = (input.barcode or product.barcode or "").strip()
        if barcode:
            for food in foods:
                if isinstance(food, dict) and str(food.get("gtinUpc") or "").strip() == barcode:
                    return food

        query_tokens = _meaningful_tokens(f"{product.brand} {product.name}")
        ranked: list[tuple[float, dict[str, Any]]] = []
        for food in foods:
            if not isinstance(food, dict):
                continue
            haystack = " ".join(
                part
                for part in [
                    str(food.get("description") or ""),
                    str(food.get("brandOwner") or ""),
                    str(food.get("brandName") or ""),
                    str(food.get("ingredients") or ""),
                ]
                if part
            )
            overlap = _token_overlap(query_tokens, _meaningful_tokens(haystack))
            if overlap <= 0:
                continue
            ranked.append((overlap, food))

        if not ranked:
            return None
        ranked.sort(key=lambda item: item[0], reverse=True)
        return ranked[0][1] if ranked[0][0] >= 0.72 else None


def _append_fact_source(
    sources: tuple[ProductResolutionSource, ...],
    source: ProductResolutionSource,
) -> tuple[ProductResolutionSource, ...]:
    if source in sources:
        return sources
    return (*sources, source)


def _mexico_seed_products() -> list[ProductCandidate]:
    def product(
        *,
        id: str,
        name: str,
        brand: str,
        barcode: str | None,
        headline: str,
        ingredients: list[str],
        claims: list[str],
        tags: list[IngredientTag],
        tokens: list[str],
        snapshot: NutritionSnapshot,
        alternatives: list[str] | None = None,
    ) -> ProductCandidate:
        signals = infer_mexico_nutrition_signals(
            text_parts=[name, brand, " ".join(ingredients), " ".join(claims)],
            snapshot=snapshot,
        )
        notes = ["Source: WellnessLens Mexico seed catalog."]
        notes.extend(f"Mexico label signal: {title}." for title in mexico_signal_titles(signals))
        return ProductCandidate(
            id=f"mx:{id}",
            name=name,
            brand=brand,
            productType=ProductType.food,
            barcode=barcode,
            headline=headline,
            ingredients=[Ingredient(name=item) for item in ingredients],
            claims=claims,
            tags=tags,
            alternativeIDs=alternatives or [],
            notes=notes,
            lookupTokens=sorted(set(_meaningful_tokens(" ".join([name, brand, *ingredients, *claims, *tokens])))),
            resolution=ProductResolution(
                canonicalProductID=f"mx:{id}",
                source=ProductResolutionSource.localCatalog,
                confidence=0.82,
                nutritionSnapshot=snapshot,
                isDirectional=False,
            ),
            mexicoNutritionSignals=signals,
        )

    return [
        product(
            id="yogurt-griego-natural",
            name="Yogurt griego natural sin azucar",
            brand="Catalogo Mexico",
            barcode=None,
            headline="Base practica de super con proteina alta y baja azucar.",
            ingredients=["Leche descremada", "Cultivos lacticos"],
            claims=["Alto en proteina", "Sin azucar anadida"],
            tags=[IngredientTag.proteinDense, IngredientTag.probiotic],
            tokens=["yogurt griego", "yoghurt griego", "natural", "sin azucar", "proteina"],
            snapshot=NutritionSnapshot(
                energy_kcal_per_100g=92,
                protein_g_per_100g=10.5,
                carbs_g_per_100g=4.0,
                fat_g_per_100g=2.2,
                sugars_g_per_100g=3.8,
                fiber_g_per_100g=0.0,
                sodium_mg_per_100g=58,
                caffeine_mg_per_100g=None,
                nova_group=3,
            ),
            alternatives=["mx:barra-avena-fibra"],
        ),
        product(
            id="bebida-energetica-azucar",
            name="Bebida energetica con azucar",
            brand="Catalogo Mexico",
            barcode=None,
            headline="Impulso rapido con sellos que conviene tratar como ocasional.",
            ingredients=["Agua carbonatada", "Azucar", "Cafeina", "Saborizantes"],
            claims=["Exceso azucares", "Contiene cafeina", "Evitar en ninos"],
            tags=[IngredientTag.sugarSpike, IngredientTag.stimulant, IngredientTag.ultraProcessed],
            tokens=["bebida energetica", "energy drink", "azucar", "cafeina", "exceso azucares"],
            snapshot=NutritionSnapshot(
                energy_kcal_per_100g=52,
                protein_g_per_100g=0,
                carbs_g_per_100g=13,
                fat_g_per_100g=0,
                sugars_g_per_100g=13,
                fiber_g_per_100g=0,
                sodium_mg_per_100g=32,
                caffeine_mg_per_100g=58,
                nova_group=4,
            ),
            alternatives=["mx:yogurt-griego-natural", "mx:barra-avena-fibra"],
        ),
        product(
            id="barra-avena-fibra",
            name="Barra de avena con fibra",
            brand="Catalogo Mexico",
            barcode=None,
            headline="Snack de paso con mejor soporte de fibra que una barra dulce comun.",
            ingredients=["Avena", "Almendra", "Linaza", "Canela"],
            claims=["Fuente de fibra"],
            tags=[IngredientTag.fiberSupport],
            tokens=["barra de avena", "avena", "fibra", "linaza", "snack"],
            snapshot=NutritionSnapshot(
                energy_kcal_per_100g=365,
                protein_g_per_100g=7,
                carbs_g_per_100g=45,
                fat_g_per_100g=12,
                sugars_g_per_100g=6,
                fiber_g_per_100g=7,
                sodium_mg_per_100g=120,
                caffeine_mg_per_100g=None,
                nova_group=3,
            ),
            alternatives=["mx:yogurt-griego-natural"],
        ),
        product(
            id="agua-fresca-azucar",
            name="Agua fresca endulzada",
            brand="Catalogo Mexico",
            barcode=None,
            headline="Opcion comun de comida corrida, pero la carga de azucar puede pegar rapido.",
            ingredients=["Agua", "Fruta", "Azucar"],
            claims=["Exceso azucares"],
            tags=[IngredientTag.sugarSpike],
            tokens=["agua fresca", "jamaica", "horchata", "limonada", "azucar"],
            snapshot=NutritionSnapshot(
                energy_kcal_per_100g=48,
                protein_g_per_100g=0,
                carbs_g_per_100g=12,
                fat_g_per_100g=0,
                sugars_g_per_100g=11,
                fiber_g_per_100g=0,
                sodium_mg_per_100g=8,
                caffeine_mg_per_100g=None,
                nova_group=2,
            ),
            alternatives=["mx:yogurt-griego-natural"],
        ),
    ]


def _normalize_barcode(value: Any) -> str:
    return re.sub(r"\D+", "", str(value or ""))


def _clean_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value if item]


def _primary_brand(value: Any) -> str:
    brands = _clean_text(value)
    if not brands:
        return "Open Food Facts"
    return brands.split(",")[0].strip() or "Open Food Facts"


def _ingredient_lines(text: str | None, ingredient_tags: list[str]) -> list[str]:
    if text:
        parts = [
            re.sub(r"\s+", " ", part).strip(" -")
            for part in re.split(r"[,;\n\[\]\(\)]", text)
        ]
        cleaned = [part for part in parts if len(part) >= 2]
        if cleaned:
            return cleaned[:8]
    derived = [tag.split(":")[-1].replace("-", " ").strip() for tag in ingredient_tags]
    return [item.title() for item in derived[:8]]


def _lookup_tokens(name: str, brand: str, ingredients_text: str | None, categories_tags: list[str]) -> list[str]:
    combined = " ".join(
        [name, brand, ingredients_text or "", " ".join(item.split(":")[-1] for item in categories_tags)]
    )
    return sorted(_meaningful_tokens(combined))[:24]


def _dsld_ingredient_lines(label_payload: dict[str, Any], *, search_hit: dict[str, Any] | None = None) -> list[str]:
    ingredients: list[str] = []

    for row in label_payload.get("ingredientRows") or []:
        if not isinstance(row, dict):
            continue
        name = _clean_text(row.get("name"))
        notes = _clean_text(row.get("notes"))
        if name:
            ingredients.append(name)
        if notes:
            ingredients.append(notes)

    other_ingredients = label_payload.get("otheringredients")
    if isinstance(other_ingredients, dict):
        for row in other_ingredients.get("ingredients") or []:
            if not isinstance(row, dict):
                continue
            name = _clean_text(row.get("name"))
            if name:
                ingredients.append(name)

    if not ingredients and isinstance(search_hit, dict):
        source = search_hit.get("_source")
        if isinstance(source, dict):
            ingredients.extend(_dsld_search_hit_ingredient_text(source))

    deduped = list(dict.fromkeys(item for item in ingredients if item))
    return deduped[:12]


def _dsld_statement_text(label_payload: dict[str, Any]) -> str:
    notes: list[str] = []
    for statement in label_payload.get("statements") or []:
        if not isinstance(statement, dict):
            continue
        note = _clean_text(statement.get("notes"))
        if note:
            notes.append(note)
    return " ".join(dict.fromkeys(notes))


def _dsld_claims(label_payload: dict[str, Any], *, search_hit: dict[str, Any] | None = None) -> list[str]:
    claims: list[str] = []

    for claim in label_payload.get("claims") or []:
        if not isinstance(claim, dict):
            continue
        description = _clean_text(claim.get("langualCodeDescription"))
        if description:
            claims.append(description)

    for statement in label_payload.get("statements") or []:
        if not isinstance(statement, dict):
            continue
        statement_type = (_clean_text(statement.get("type")) or "").lower()
        notes = _clean_text(statement.get("notes"))
        if not notes:
            continue
        if any(keyword in statement_type for keyword in ["suggested", "usage", "direction", "claim"]):
            claims.append(notes)
        elif "general statements" in statement_type and len(claims) < 4:
            claims.append(notes)

    if not claims and isinstance(search_hit, dict):
        source = search_hit.get("_source")
        if isinstance(source, dict):
            claims.extend(_dsld_search_hit_claim_text(source))

    return list(dict.fromkeys(claims))[:6]


def _dsld_search_hit_ingredient_text(source: dict[str, Any]) -> list[str]:
    items: list[str] = []
    for ingredient in source.get("allIngredients") or []:
        if not isinstance(ingredient, dict):
            continue
        name = _clean_text(ingredient.get("name"))
        notes = _clean_text(ingredient.get("notes"))
        if name:
            items.append(name)
        if notes:
            items.append(notes)
    return items


def _dsld_search_hit_claim_text(source: dict[str, Any]) -> list[str]:
    items: list[str] = []
    for claim in source.get("claims") or []:
        if not isinstance(claim, dict):
            continue
        description = _clean_text(claim.get("langualCodeDescription"))
        if description:
            items.append(description)
    return items


def _normalized_query_text(value: str) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", value.lower()))


def _directional_name(input: ScanInput, raw_text: str) -> str:
    if input.sourceType in {ScanSource.labelPhoto, ScanSource.manualLabel}:
        return "Directional label read"
    if input.sourceType == ScanSource.mealPhoto:
        return "Meal snapshot"
    if input.sourceType == ScanSource.menuPhoto:
        return "Menu read"
    if input.barcode:
        return f"Unresolved barcode {input.barcode[-4:]}"
    return raw_text[:48] if raw_text else "Directional product read"


def _meaningful_tokens(text: str) -> set[str]:
    tokens = {
        token
        for token in re.findall(r"[a-z0-9áéíóúñ]{3,}", text.lower())
        if token not in STOPWORDS and not token.isdigit()
    }
    return tokens


def _token_overlap(left: set[str], right: set[str]) -> float:
    if not left or not right:
        return 0.0
    return len(left & right) / len(left)


def _off_nutrition_to_snapshot(nutriments: Any) -> NutritionSnapshot | None:
    if not isinstance(nutriments, dict):
        return None

    snapshot = NutritionSnapshot(
        energyKcalPer100g=_numeric_value(nutriments, "energy-kcal_100g", "energy-kcal_100ml", "energy-kcal"),
        proteinGPer100g=_numeric_value(nutriments, "proteins_100g"),
        carbsGPer100g=_numeric_value(nutriments, "carbohydrates_100g"),
        fatGPer100g=_numeric_value(nutriments, "fat_100g"),
        sugarsGPer100g=_numeric_value(nutriments, "sugars_100g"),
        fiberGPer100g=_numeric_value(nutriments, "fiber_100g"),
        sodiumMgPer100g=_grams_to_mg(_numeric_value(nutriments, "sodium_100g")),
        caffeineMgPer100g=_numeric_value(nutriments, "caffeine_100g"),
        novaGroup=_int_value(nutriments, "nova-group_100g", "nova-group"),
    )
    return snapshot if any(value is not None for value in snapshot.model_dump().values()) else None


def _usda_food_to_snapshot(food: dict[str, Any]) -> NutritionSnapshot | None:
    nutrients = food.get("foodNutrients")
    if not isinstance(nutrients, list):
        return None

    mapped: dict[str, float] = {}
    for nutrient in nutrients:
        if not isinstance(nutrient, dict):
            continue
        name = str(nutrient.get("nutrientName") or "").strip().lower()
        value = nutrient.get("value")
        if not isinstance(value, (int, float)) or not isfinite(value):
            continue
        mapped[name] = float(value)

    snapshot = NutritionSnapshot(
        energyKcalPer100g=mapped.get("energy"),
        proteinGPer100g=mapped.get("protein"),
        carbsGPer100g=mapped.get("carbohydrate, by difference"),
        fatGPer100g=mapped.get("total lipid (fat)"),
        sugarsGPer100g=mapped.get("total sugars"),
        fiberGPer100g=mapped.get("fiber, total dietary"),
        sodiumMgPer100g=mapped.get("sodium, na"),
        caffeineMgPer100g=mapped.get("caffeine"),
        novaGroup=None,
    )
    return snapshot if any(value is not None for value in snapshot.model_dump().values()) else None


def _numeric_value(payload: dict[str, Any], *keys: str) -> float | None:
    for key in keys:
        value = payload.get(key)
        if isinstance(value, (int, float)) and isfinite(value):
            return float(value)
    return None


def _int_value(payload: dict[str, Any], *keys: str) -> int | None:
    for key in keys:
        value = payload.get(key)
        if isinstance(value, (int, float)) and isfinite(value):
            return int(value)
    return None


def _grams_to_mg(value: float | None) -> float | None:
    return value * 1000 if value is not None else None


def _infer_tags(
    *,
    name: str,
    ingredients_text: str | None,
    ingredient_tags: list[str],
    labels_tags: list[str],
    snapshot: NutritionSnapshot | None,
) -> list[IngredientTag]:
    combined = " ".join([name, ingredients_text or "", " ".join(ingredient_tags), " ".join(labels_tags)]).lower()
    tags: set[IngredientTag] = set()

    if snapshot and snapshot.proteinGPer100g is not None and snapshot.proteinGPer100g >= 10:
        tags.add(IngredientTag.proteinDense)
    if snapshot and snapshot.fiberGPer100g is not None and snapshot.fiberGPer100g >= 5:
        tags.add(IngredientTag.fiberSupport)
    if snapshot and snapshot.sugarsGPer100g is not None and snapshot.sugarsGPer100g >= 12:
        tags.add(IngredientTag.sugarSpike)
    if snapshot and snapshot.novaGroup is not None and snapshot.novaGroup >= 4:
        tags.add(IngredientTag.ultraProcessed)
    if _contains_any(combined, ["caffeine", "cafeína", "cafeina", "coffee extract", "guarana", "energy drink"]):
        tags.add(IngredientTag.stimulant)
    if _contains_any(combined, ["probiotic", "cultures", "kefir", "yogurt", "yoghurt"]):
        tags.add(IngredientTag.probiotic)
    if _contains_any(combined, ["omega", "chia", "flax", "salmon", "sardine"]):
        tags.add(IngredientTag.omegaSupport)
    return sorted(tags, key=lambda item: item.value)


def _claims_from_labels(labels_tags: list[str]) -> list[str]:
    claims: list[str] = []
    for tag in labels_tags[:4]:
        label = tag.split(":")[-1].replace("-", " ").strip()
        if label:
            claims.append(label.title())
    return claims


def _nutrition_is_complete_enough(snapshot: NutritionSnapshot | None) -> bool:
    if snapshot is None:
        return False
    populated = [
        snapshot.energyKcalPer100g,
        snapshot.proteinGPer100g,
        snapshot.carbsGPer100g,
        snapshot.fatGPer100g,
        snapshot.sugarsGPer100g,
        snapshot.fiberGPer100g,
    ]
    return sum(value is not None for value in populated) >= 5


def _snapshot_adds_signal(candidate: NutritionSnapshot, existing: NutritionSnapshot | None) -> bool:
    if existing is None:
        return True
    candidate_count = sum(value is not None for value in candidate.model_dump().values())
    existing_count = sum(value is not None for value in existing.model_dump().values())
    return candidate_count > existing_count


def _contains_any(text: str, terms: list[str]) -> bool:
    return any(term in text for term in terms)
