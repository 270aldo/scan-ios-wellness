from __future__ import annotations

from typing import Iterable

from app.contracts import (
    ConfidenceLevel,
    ProductCandidate,
    ProductResolutionSemantic,
    ProductResolutionSource,
)


LOW_CONFIDENCE_THRESHOLD = 0.58
_SEMANTIC_ORDER = [
    ProductResolutionSemantic.canonical,
    ProductResolutionSemantic.provisional,
    ProductResolutionSemantic.directional,
    ProductResolutionSemantic.providerBacked,
    ProductResolutionSemantic.lowConfidence,
]
_PROVIDER_BACKED_SOURCES = {
    ProductResolutionSource.openFoodFacts,
    ProductResolutionSource.usdaFoodDataCentral,
    ProductResolutionSource.nihDSLD,
    ProductResolutionSource.cosing,
    ProductResolutionSource.localCatalog,
}


def ensure_product_resolution_semantics(
    product: ProductCandidate,
    *,
    confidence: ConfidenceLevel | None = None,
    identity_source: ProductResolutionSource | None = None,
    fact_sources: Iterable[ProductResolutionSource] = (),
) -> ProductCandidate:
    semantics = resolved_resolution_semantics(
        product,
        confidence=confidence,
        identity_source=identity_source,
        fact_sources=fact_sources,
    )
    return product.model_copy(update={"resolutionSemantics": semantics})


def resolved_resolution_semantics(
    product: ProductCandidate,
    *,
    confidence: ConfidenceLevel | None = None,
    identity_source: ProductResolutionSource | None = None,
    fact_sources: Iterable[ProductResolutionSource] = (),
) -> list[ProductResolutionSemantic]:
    if product.resolutionSemantics:
        return _ordered_semantics(product.resolutionSemantics)

    semantics: list[ProductResolutionSemantic] = []
    resolution = product.resolution

    canonical_product_id = (
        resolution.canonicalProductID.strip()
        if resolution and resolution.canonicalProductID
        else None
    )
    if canonical_product_id:
        semantics.append(ProductResolutionSemantic.canonical)

    is_directional = bool(resolution and resolution.isDirectional)
    if is_directional:
        semantics.append(ProductResolutionSemantic.directional)

    if not canonical_product_id and _is_provisional_identity(product.id, is_directional=is_directional):
        semantics.append(ProductResolutionSemantic.provisional)

    provider_sources = set(fact_sources)
    if identity_source is not None:
        provider_sources.add(identity_source)
    if resolution is not None:
        provider_sources.add(resolution.source)
    if provider_sources & _PROVIDER_BACKED_SOURCES:
        semantics.append(ProductResolutionSemantic.providerBacked)

    resolution_confidence = resolution.confidence if resolution is not None else None
    if resolution_confidence is not None:
        if resolution_confidence < LOW_CONFIDENCE_THRESHOLD:
            semantics.append(ProductResolutionSemantic.lowConfidence)
    elif confidence == ConfidenceLevel.low:
        semantics.append(ProductResolutionSemantic.lowConfidence)

    return _ordered_semantics(semantics)


def product_has_resolution_semantic(
    product: ProductCandidate,
    semantic: ProductResolutionSemantic,
    *,
    confidence: ConfidenceLevel | None = None,
    identity_source: ProductResolutionSource | None = None,
    fact_sources: Iterable[ProductResolutionSource] = (),
) -> bool:
    return semantic in resolved_resolution_semantics(
        product,
        confidence=confidence,
        identity_source=identity_source,
        fact_sources=fact_sources,
    )


def _ordered_semantics(
    semantics: Iterable[ProductResolutionSemantic],
) -> list[ProductResolutionSemantic]:
    seen = set(semantics)
    return [semantic for semantic in _SEMANTIC_ORDER if semantic in seen]


def _is_provisional_identity(product_id: str, *, is_directional: bool) -> bool:
    if is_directional:
        return True

    normalized_product_id = product_id.strip().lower()
    return (
        normalized_product_id.startswith("scan:")
        or normalized_product_id.startswith("directional:")
        or normalized_product_id.startswith("custom-")
    )
