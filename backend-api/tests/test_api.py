from __future__ import annotations

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import Settings, get_settings
from app.contracts import (
    ConfidenceLevel,
    Ingredient,
    MexicoWarningLabel,
    ProductCandidate,
    ProductResolution,
    ProductResolutionSemantic,
    ProductResolutionSource,
    ProductType,
    ScanContext,
    ScanCyclePhase,
    ScanInput,
    ScanSource,
    NutritionSnapshot,
    UserContext,
    WellnessLensKind,
)
from app.main import app, build_backend_services
from app.product_resolver import ProductResolver, ResolverResult
from app.security import SecurityVerificationError
from app.services import (
    build_analysis_envelope,
    build_scan_analysis,
    fixture_models,
    starter_history_sync_request,
    starter_home_request,
)


client = TestClient(app)


def starter_user_context() -> UserContext:
    return starter_home_request("install-prd5-test").profile.userContext


def lens_score(analysis, lens: WellnessLensKind) -> int:
    return next(item.score for item in analysis.lensScores if item.lens == lens)


def overall_score(analysis) -> int:
    return int(sum(item.score for item in analysis.lensScores) / max(len(analysis.lensScores), 1))


def make_resolver_result(
    product: ProductCandidate,
    confidence: ConfidenceLevel = ConfidenceLevel.high,
) -> ResolverResult:
    resolution_source = product.resolution.source if product.resolution is not None else ProductResolutionSource.agentInferred
    resolution_confidence = product.resolution.confidence if product.resolution is not None else 0.42
    return ResolverResult(
        product=product,
        confidence=confidence,
        resolution_confidence=resolution_confidence,
        is_directional=product.resolution.isDirectional if product.resolution is not None else confidence == ConfidenceLevel.low,
        identity_source=resolution_source,
        fact_sources=(resolution_source,),
    )


def make_provider_backed_product(
    resolution_source: ProductResolutionSource,
) -> ProductCandidate:
    if resolution_source == ProductResolutionSource.nihDSLD:
        return ProductCandidate(
            id="dsld:steady-capsules",
            name="Steady Capsules",
            brand="Inner Balance",
            productType=ProductType.supplement,
            barcode="888800001",
            headline="Provider-backed supplement facts.",
            ingredients=[Ingredient(name="Lactobacillus blend"), Ingredient(name="Vegetable capsule")],
            claims=["Gut support"],
            tags=[],
            alternativeIDs=[],
            notes=[],
            lookupTokens=["probiotic", "capsules"],
            resolution=ProductResolution(
                canonicalProductID="dsld:steady-capsules",
                source=resolution_source,
                confidence=0.88,
                nutritionSnapshot=NutritionSnapshot(
                    energyKcalPer100g=300,
                    proteinGPer100g=24,
                    carbsGPer100g=40,
                    fatGPer100g=8,
                    sugarsGPer100g=24,
                    fiberGPer100g=0,
                    sodiumMgPer100g=15,
                    caffeineMgPer100g=80,
                    novaGroup=4,
                ),
                isDirectional=False,
            ),
            resolutionSemantics=[
                ProductResolutionSemantic.canonical,
                ProductResolutionSemantic.providerBacked,
            ],
        )

    return ProductCandidate(
        id=f"{resolution_source.value}:850000001",
        name="Balanced Protein Yogurt",
        brand="Good Farm" if resolution_source != ProductResolutionSource.localCatalog else "Glow Pantry",
        productType=ProductType.food,
        barcode="850000001",
        headline="Provider-backed protein and fiber anchor.",
        ingredients=[Ingredient(name="Cultured milk"), Ingredient(name="Chia fiber")],
        claims=["15g protein", "5g fiber"],
        tags=[],
        alternativeIDs=[],
        notes=[],
        lookupTokens=["protein yogurt", "chia", "cultures"],
        resolution=ProductResolution(
            canonicalProductID=f"{resolution_source.value}:850000001",
            source=resolution_source,
            confidence=0.92,
            nutritionSnapshot=NutritionSnapshot(
                energyKcalPer100g=110,
                proteinGPer100g=15,
                carbsGPer100g=8,
                fatGPer100g=3,
                sugarsGPer100g=4,
                fiberGPer100g=5,
                sodiumMgPer100g=75,
                caffeineMgPer100g=None,
                novaGroup=3,
            ),
            isDirectional=False,
        ),
        resolutionSemantics=[
            ProductResolutionSemantic.canonical,
            ProductResolutionSemantic.providerBacked,
        ],
    )


def test_healthz():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_client_config_contract_shape():
    response = client.get("/v1/client-config")
    assert response.status_code == 200
    payload = response.json()
    assert payload["environment"] == "dev"
    assert payload["persistenceMode"] == "in_memory"
    assert payload["firebaseAuthEnforced"] is False
    assert payload["appCheckEnforced"] is False
    assert payload["agentProviderMode"] == "local"
    assert payload["flags"]["structuredAnalysis"] is True
    assert payload["killSwitches"]["scanDisabled"] is False


def test_analyze_structured_returns_contract_compatible_payload(monkeypatch):
    sync_request, _ = starter_history_sync_request()
    profile_request = starter_home_request(sync_request.installID)
    services = getattr(app.state, "backend_services", None)
    if services is None:
        services = build_backend_services(Settings())
        app.state.backend_services = services

    monkeypatch.setattr(
        services.resolver,
        "resolve",
        lambda input: ResolverResult(
            product=ProductCandidate(
                id="off:7501031311309",
                name="Greek Yogurt",
                brand="Good Farm",
                productType=ProductType.food,
                barcode="7501031311309",
                headline="Exact barcode match from Open Food Facts.",
                ingredients=[Ingredient(name="Milk"), Ingredient(name="Cultures")],
                claims=["High protein"],
                tags=[],
                alternativeIDs=[],
                notes=["Source: Open Food Facts (resolved)."],
                lookupTokens=["greek", "yogurt"],
                resolution=ProductResolution(
                    canonicalProductID="off:7501031311309",
                    source=ProductResolutionSource.openFoodFacts,
                    confidence=0.91,
                    nutritionSnapshot=None,
                    isDirectional=False,
                ),
            ),
            confidence=ConfidenceLevel.high,
            resolution_confidence=0.91,
            is_directional=False,
            identity_source=ProductResolutionSource.openFoodFacts,
            fact_sources=(ProductResolutionSource.openFoodFacts,),
        ),
        raising=False,
    )
    response = client.post(
        "/v1/scan/analyze",
        json={
            "input": {
                "sourceType": "manualLabel",
                "rawText": "protein, fiber, chia",
                "locale": "en_US",
            },
            "profile": profile_request.profile.model_dump(mode="json"),
            "recentScans": [item.model_dump(by_alias=True, mode="json") for item in sync_request.scans[0:1]],
            "recentCheckIns": [item.model_dump(by_alias=True, mode="json") for item in sync_request.checkIns[0:1]],
            "installID": sync_request.installID,
        },
    )
    assert response.status_code == 200
    analysis = response.json()["analysis"]
    assert analysis["analysis_id"].startswith("analysis-manualLabel")
    assert analysis["lens_scores"]["body_comp"] >= 0
    assert analysis["medical_safety"]["disclaimer_needed"] is True
    assert analysis["resolved_product"]["name"] == "Greek Yogurt"
    assert analysis["resolved_product"]["resolution_semantics"] == ["canonical", "provider_backed"]
    assert analysis["resolved_product"]["resolution"]["source"] == "openFoodFacts"
    assert analysis["resolved_product"]["resolution"]["confidence"] == pytest.approx(0.91)
    assert analysis["resolved_product"]["resolution"]["is_directional"] is False


def test_analyze_structured_accepts_scan_context_and_applies_it(monkeypatch):
    sync_request, _ = starter_history_sync_request()
    profile_request = starter_home_request(sync_request.installID)
    services = getattr(app.state, "backend_services", None)
    if services is None:
        services = build_backend_services(Settings())
        app.state.backend_services = services

    product = make_provider_backed_product(ProductResolutionSource.openFoodFacts)
    monkeypatch.setattr(services.resolver, "resolve", lambda input: make_resolver_result(product), raising=False)

    base_request = {
        "input": {
            "sourceType": "manualBarcode",
            "barcode": product.barcode,
            "locale": "en_US",
        },
        "profile": profile_request.profile.model_dump(mode="json"),
        "recentScans": [item.model_dump(by_alias=True, mode="json") for item in sync_request.scans[0:1]],
        "recentCheckIns": [item.model_dump(by_alias=True, mode="json") for item in sync_request.checkIns[0:1]],
        "installID": sync_request.installID,
    }

    response_without = client.post("/v1/scan/analyze", json=base_request)
    assert response_without.status_code == 200

    response_with = client.post(
        "/v1/scan/analyze",
        json={
            **base_request,
            "scanContext": {
                "cycle_phase": "menstrual",
                "is_in_anabolic_window": True,
                "sleep_hours": 5.4,
                "hrv_milliseconds": 44,
                "resting_heart_rate": 58,
            },
        },
    )
    assert response_with.status_code == 200

    baseline_lenses = response_without.json()["analysis"]["lens_scores"]
    contextual_lenses = response_with.json()["analysis"]["lens_scores"]

    assert contextual_lenses["energy"] > baseline_lenses["energy"]
    assert contextual_lenses["body_comp"] > baseline_lenses["body_comp"]


def test_analyze_product_accepts_optional_scan_context_and_is_backward_compatible(monkeypatch):
    services = getattr(app.state, "backend_services", None)
    if services is None:
        services = build_backend_services(Settings())
        app.state.backend_services = services

    product = ProductCandidate(
        id="off:850000001",
        name="Balanced Protein Yogurt",
        brand="Good Farm",
        productType=ProductType.food,
        barcode="850000001",
        headline="Provider-backed protein and fiber anchor.",
        ingredients=[Ingredient(name="Cultured milk"), Ingredient(name="Chia fiber")],
        claims=["15g protein", "5g fiber"],
        tags=[],
        alternativeIDs=[],
        notes=[],
        lookupTokens=["protein yogurt", "chia", "cultures"],
        resolution=ProductResolution(
            canonicalProductID="off:850000001",
            source=ProductResolutionSource.openFoodFacts,
            confidence=0.92,
            nutritionSnapshot=NutritionSnapshot(
                energyKcalPer100g=110,
                proteinGPer100g=15,
                carbsGPer100g=8,
                fatGPer100g=3,
                sugarsGPer100g=4,
                fiberGPer100g=5,
                sodiumMgPer100g=75,
                caffeineMgPer100g=None,
                novaGroup=3,
            ),
            isDirectional=False,
        ),
        resolutionSemantics=[
            ProductResolutionSemantic.canonical,
            ProductResolutionSemantic.providerBacked,
        ],
    )
    monkeypatch.setattr(services.resolver, "resolve", lambda input: make_resolver_result(product), raising=False)

    base_request = {
        "input": {
            "sourceType": "manualBarcode",
            "barcode": "850000001",
            "locale": "en_US",
        },
        "userContext": starter_user_context().model_dump(mode="json"),
        "installID": "install-prd5-scan-context",
    }

    response_without = client.post("/analyzeProduct", json=base_request)
    assert response_without.status_code == 200

    response_with = client.post(
        "/analyzeProduct",
        json={
            **base_request,
            "scanContext": {
                "cycle_phase": "menstrual",
                "is_in_anabolic_window": True,
                "sleep_hours": 5.4,
                "hrv_milliseconds": 44,
                "resting_heart_rate": 58,
            },
        },
    )
    assert response_with.status_code == 200

    baseline = response_without.json()["analysis"]
    contextual = response_with.json()["analysis"]
    baseline_lenses = {item["lens"]: item["score"] for item in baseline["lensScores"]}
    contextual_lenses = {item["lens"]: item["score"] for item in contextual["lensScores"]}

    assert contextual_lenses["energyMood"] > baseline_lenses["energyMood"]
    assert contextual_lenses["bodyCompositionStrength"] > baseline_lenses["bodyCompositionStrength"]


@pytest.mark.parametrize(
    ("resolution_source", "expected_reason", "expected_why_today"),
    [
        (
            ProductResolutionSource.openFoodFacts,
            "Exact packaged-food match from Open Food Facts.",
            "Product identity came from Open Food Facts.",
        ),
        (
            ProductResolutionSource.usdaFoodDataCentral,
            "Matched against USDA FoodData Central for nutrient-backed food facts.",
            "Product facts came from USDA FoodData Central.",
        ),
        (
            ProductResolutionSource.nihDSLD,
            "Matched against NIH DSLD for provider-backed supplement facts.",
            "Product identity came from NIH DSLD.",
        ),
        (
            ProductResolutionSource.localCatalog,
            "Matched against the local WellnessLens catalog for a stable product record.",
            "Product identity came from the local WellnessLens catalog.",
        ),
    ],
)
def test_provider_backed_resolution_messages_reflect_actual_source(
    resolution_source: ProductResolutionSource,
    expected_reason: str,
    expected_why_today: str,
):
    product = make_provider_backed_product(resolution_source)
    input = ScanInput(sourceType=ScanSource.manualBarcode, barcode=product.barcode, locale="en_US")

    analysis = build_scan_analysis(
        input,
        starter_user_context(),
        resolution=make_resolver_result(product),
    )
    envelope = build_analysis_envelope(
        input,
        starter_user_context(),
        recent_scans=[],
        recent_checkins=[],
        resolution=make_resolver_result(product),
    )

    resolution_reason = next(item for item in analysis.topReasons if item.title == "Resolution signal")

    assert resolution_reason.detail == expected_reason
    assert expected_why_today in envelope.whyToday
    if resolution_source != ProductResolutionSource.openFoodFacts:
        assert "Open Food Facts" not in resolution_reason.detail
        assert "Open Food Facts" not in " ".join(envelope.whyToday)


def test_build_scan_analysis_scores_provider_backed_protein_fiber_food_strongly():
    product = ProductCandidate(
        id="off:850000001",
        name="Balanced Protein Yogurt",
        brand="Good Farm",
        productType=ProductType.food,
        barcode="850000001",
        headline="Provider-backed protein and fiber anchor.",
        ingredients=[Ingredient(name="Cultured milk"), Ingredient(name="Chia fiber")],
        claims=["15g protein", "5g fiber"],
        tags=[],
        alternativeIDs=[],
        notes=[],
        lookupTokens=["protein yogurt", "chia", "cultures"],
        resolution=ProductResolution(
            canonicalProductID="off:850000001",
            source=ProductResolutionSource.openFoodFacts,
            confidence=0.92,
            nutritionSnapshot=NutritionSnapshot(
                energyKcalPer100g=110,
                proteinGPer100g=15,
                carbsGPer100g=8,
                fatGPer100g=3,
                sugarsGPer100g=4,
                fiberGPer100g=5,
                sodiumMgPer100g=75,
                caffeineMgPer100g=None,
                novaGroup=3,
            ),
            isDirectional=False,
        ),
        resolutionSemantics=[
            ProductResolutionSemantic.canonical,
            ProductResolutionSemantic.providerBacked,
        ],
    )

    analysis = build_scan_analysis(
        ScanInput(sourceType=ScanSource.manualBarcode, barcode="850000001", locale="en_US"),
        starter_user_context(),
        resolution=make_resolver_result(product),
    )

    assert lens_score(analysis, WellnessLensKind.energyMood) >= 80
    assert lens_score(analysis, WellnessLensKind.gutComfort) >= 85
    assert lens_score(analysis, WellnessLensKind.bodyCompositionStrength) >= 75
    assert overall_score(analysis) >= 75


def test_build_scan_analysis_softens_high_sugar_high_caffeine_drink():
    product = ProductCandidate(
        id="off:850000002",
        name="Spark Rush Energy Drink",
        brand="Rush Lab",
        productType=ProductType.food,
        barcode="850000002",
        headline="Fast buzz with rougher stability.",
        ingredients=[Ingredient(name="Cane sugar"), Ingredient(name="Caffeine"), Ingredient(name="Natural flavors")],
        claims=["Fast focus"],
        tags=[],
        alternativeIDs=[],
        notes=[],
        lookupTokens=["energy drink", "cane sugar", "caffeine"],
        resolution=ProductResolution(
            canonicalProductID="off:850000002",
            source=ProductResolutionSource.openFoodFacts,
            confidence=0.9,
            nutritionSnapshot=NutritionSnapshot(
                energyKcalPer100g=52,
                proteinGPer100g=0,
                carbsGPer100g=13,
                fatGPer100g=0,
                sugarsGPer100g=13,
                fiberGPer100g=0,
                sodiumMgPer100g=32,
                caffeineMgPer100g=58,
                novaGroup=4,
            ),
            isDirectional=False,
        ),
        resolutionSemantics=[
            ProductResolutionSemantic.canonical,
            ProductResolutionSemantic.providerBacked,
        ],
    )

    analysis = build_scan_analysis(
        ScanInput(sourceType=ScanSource.manualBarcode, barcode="850000002", locale="en_US"),
        starter_user_context(),
        resolution=make_resolver_result(product),
    )

    assert lens_score(analysis, WellnessLensKind.energyMood) < 55
    assert lens_score(analysis, WellnessLensKind.hormoneBalance) < 55
    assert overall_score(analysis) < 55


def test_build_scan_analysis_softens_nova4_processed_snack():
    product = ProductCandidate(
        id="off:899900001",
        name="Crunch Lab Snack",
        brand="Crunch Lab",
        productType=ProductType.food,
        barcode="899900001",
        headline="Ultra-processed snack with softer digestion support.",
        ingredients=[Ingredient(name="Corn flour"), Ingredient(name="Natural flavors"), Ingredient(name="Maltodextrin")],
        claims=["Crunchy"],
        tags=[],
        alternativeIDs=[],
        notes=[],
        lookupTokens=["crunchy snack", "natural flavors", "maltodextrin"],
        resolution=ProductResolution(
            canonicalProductID="off:899900001",
            source=ProductResolutionSource.openFoodFacts,
            confidence=0.89,
            nutritionSnapshot=NutritionSnapshot(
                energyKcalPer100g=470,
                proteinGPer100g=4,
                carbsGPer100g=56,
                fatGPer100g=23,
                sugarsGPer100g=6,
                fiberGPer100g=2,
                sodiumMgPer100g=420,
                caffeineMgPer100g=None,
                novaGroup=4,
            ),
            isDirectional=False,
        ),
        resolutionSemantics=[
            ProductResolutionSemantic.canonical,
            ProductResolutionSemantic.providerBacked,
        ],
    )

    analysis = build_scan_analysis(
        ScanInput(sourceType=ScanSource.manualBarcode, barcode="899900001", locale="en_US"),
        starter_user_context(),
        resolution=make_resolver_result(product),
    )

    assert lens_score(analysis, WellnessLensKind.gutComfort) < 60
    assert lens_score(analysis, WellnessLensKind.hormoneBalance) < 60
    assert overall_score(analysis) < 60


def test_build_scan_analysis_applies_training_and_short_sleep_to_protein_anchor():
    product = ProductCandidate(
        id="off:850000001",
        name="Balanced Protein Yogurt",
        brand="Good Farm",
        productType=ProductType.food,
        barcode="850000001",
        headline="Provider-backed protein and fiber anchor.",
        ingredients=[Ingredient(name="Cultured milk"), Ingredient(name="Chia fiber")],
        claims=["15g protein", "5g fiber"],
        tags=[],
        alternativeIDs=[],
        notes=[],
        lookupTokens=["protein yogurt", "chia", "cultures"],
        resolution=ProductResolution(
            canonicalProductID="off:850000001",
            source=ProductResolutionSource.openFoodFacts,
            confidence=0.92,
            nutritionSnapshot=NutritionSnapshot(
                energyKcalPer100g=110,
                proteinGPer100g=15,
                carbsGPer100g=8,
                fatGPer100g=3,
                sugarsGPer100g=4,
                fiberGPer100g=5,
                sodiumMgPer100g=75,
                caffeineMgPer100g=None,
                novaGroup=3,
            ),
            isDirectional=False,
        ),
        resolutionSemantics=[
            ProductResolutionSemantic.canonical,
            ProductResolutionSemantic.providerBacked,
        ],
    )

    baseline = build_scan_analysis(
        ScanInput(sourceType=ScanSource.manualBarcode, barcode="850000001", locale="en_US"),
        starter_user_context(),
        resolution=make_resolver_result(product),
    )
    contextual = build_scan_analysis(
        ScanInput(sourceType=ScanSource.manualBarcode, barcode="850000001", locale="en_US"),
        starter_user_context(),
        resolution=make_resolver_result(product),
        scan_context=ScanContext(
            cycle_phase=ScanCyclePhase.menstrual,
            is_in_anabolic_window=True,
            sleep_hours=5.4,
            hrv_milliseconds=44,
            resting_heart_rate=58,
        ),
    )

    assert lens_score(contextual, WellnessLensKind.energyMood) > lens_score(baseline, WellnessLensKind.energyMood)
    assert lens_score(contextual, WellnessLensKind.bodyCompositionStrength) > lens_score(baseline, WellnessLensKind.bodyCompositionStrength)
    assert overall_score(contextual) > overall_score(baseline)


def test_build_scan_analysis_keeps_directional_meal_conservative():
    product = ProductCandidate(
        id="directional:chicken-bowl",
        name="Chicken bowl read",
        brand="Directional meal",
        productType=ProductType.food,
        barcode=None,
        headline="Meal snapshot with protein and greens cues.",
        ingredients=[Ingredient(name="Chicken"), Ingredient(name="Greens"), Ingredient(name="Beans")],
        claims=[],
        tags=[],
        alternativeIDs=[],
        notes=["Directional meal inference only."],
        lookupTokens=["grilled chicken", "greens", "beans"],
        resolution=ProductResolution(
            canonicalProductID=None,
            source=ProductResolutionSource.agentInferred,
            confidence=0.44,
            nutritionSnapshot=None,
            isDirectional=True,
        ),
        resolutionSemantics=[
            ProductResolutionSemantic.provisional,
            ProductResolutionSemantic.directional,
            ProductResolutionSemantic.lowConfidence,
        ],
    )

    analysis = build_scan_analysis(
        ScanInput(sourceType=ScanSource.mealPhoto, rawText="grilled chicken bowl", locale="en_US"),
        starter_user_context(),
        resolution=make_resolver_result(product, confidence=ConfidenceLevel.low),
    )

    assert analysis.confidence == ConfidenceLevel.low
    assert analysis.resolvedProduct.resolutionSemantics == [
        ProductResolutionSemantic.provisional,
        ProductResolutionSemantic.directional,
        ProductResolutionSemantic.lowConfidence,
    ]
    assert "Directional read only" in analysis.overallSummary
    assert lens_score(analysis, WellnessLensKind.energyMood) >= 60


def test_build_scan_analysis_keeps_provider_backed_supplement_on_conservative_path():
    product = ProductCandidate(
        id="dsld:steady-capsules",
        name="Steady Capsules",
        brand="Inner Balance",
        productType=ProductType.supplement,
        barcode="888800001",
        headline="Provider-backed supplement that stays on the conservative path.",
        ingredients=[Ingredient(name="Lactobacillus blend"), Ingredient(name="Vegetable capsule")],
        claims=["Gut support"],
        tags=[],
        alternativeIDs=[],
        notes=[],
        lookupTokens=["probiotic", "capsules"],
        resolution=ProductResolution(
            canonicalProductID="dsld:steady-capsules",
            source=ProductResolutionSource.nihDSLD,
            confidence=0.88,
            nutritionSnapshot=NutritionSnapshot(
                energyKcalPer100g=300,
                proteinGPer100g=24,
                carbsGPer100g=40,
                fatGPer100g=8,
                sugarsGPer100g=24,
                fiberGPer100g=0,
                sodiumMgPer100g=15,
                caffeineMgPer100g=80,
                novaGroup=4,
            ),
            isDirectional=False,
        ),
        resolutionSemantics=[
            ProductResolutionSemantic.canonical,
            ProductResolutionSemantic.providerBacked,
        ],
    )

    baseline = build_scan_analysis(
        ScanInput(sourceType=ScanSource.manualBarcode, barcode="888800001", locale="en_US"),
        starter_user_context(),
        resolution=make_resolver_result(product),
    )
    contextual = build_scan_analysis(
        ScanInput(sourceType=ScanSource.manualBarcode, barcode="888800001", locale="en_US"),
        starter_user_context(),
        resolution=make_resolver_result(product),
        scan_context=ScanContext(
            cycle_phase=ScanCyclePhase.luteal,
            is_in_anabolic_window=True,
            sleep_hours=5.1,
            hrv_milliseconds=28,
            resting_heart_rate=74,
            wrist_temperature_delta_celsius=0.4,
        ),
    )

    assert contextual.lensScores == baseline.lensScores
    assert lens_score(contextual, WellnessLensKind.energyMood) == 60
    assert lens_score(contextual, WellnessLensKind.hormoneBalance) == 60


def test_build_scan_analysis_is_deterministic_with_same_scan_context():
    product = ProductCandidate(
        id="off:850000001",
        name="Balanced Protein Yogurt",
        brand="Good Farm",
        productType=ProductType.food,
        barcode="850000001",
        headline="Provider-backed protein and fiber anchor.",
        ingredients=[Ingredient(name="Cultured milk"), Ingredient(name="Chia fiber")],
        claims=["15g protein", "5g fiber"],
        tags=[],
        alternativeIDs=[],
        notes=[],
        lookupTokens=["protein yogurt", "chia", "cultures"],
        resolution=ProductResolution(
            canonicalProductID="off:850000001",
            source=ProductResolutionSource.openFoodFacts,
            confidence=0.92,
            nutritionSnapshot=NutritionSnapshot(
                energyKcalPer100g=110,
                proteinGPer100g=15,
                carbsGPer100g=8,
                fatGPer100g=3,
                sugarsGPer100g=4,
                fiberGPer100g=5,
                sodiumMgPer100g=75,
                caffeineMgPer100g=None,
                novaGroup=3,
            ),
            isDirectional=False,
        ),
        resolutionSemantics=[
            ProductResolutionSemantic.canonical,
            ProductResolutionSemantic.providerBacked,
        ],
    )
    scan_context = ScanContext(
        cycle_phase=ScanCyclePhase.menstrual,
        is_in_anabolic_window=True,
        sleep_hours=5.4,
        hrv_milliseconds=44,
        resting_heart_rate=58,
    )

    first = build_scan_analysis(
        ScanInput(sourceType=ScanSource.manualBarcode, barcode="850000001", locale="en_US"),
        starter_user_context(),
        resolution=make_resolver_result(product),
        scan_context=scan_context,
    )
    second = build_scan_analysis(
        ScanInput(sourceType=ScanSource.manualBarcode, barcode="850000001", locale="en_US"),
        starter_user_context(),
        resolution=make_resolver_result(product),
        scan_context=scan_context,
    )

    assert first.lensScores == second.lensScores
    assert first.topReasons == second.topReasons
    assert first.warnings == second.warnings


def test_profile_sync_history_sync_and_home_flow():
    home_request = starter_home_request("install-home-test")
    sync_request, _ = starter_history_sync_request()
    sync_request.installID = "install-home-test"

    profile_response = client.post("/v1/profile/sync", json=home_request.model_dump(mode="json"))
    assert profile_response.status_code == 200

    history_response = client.post("/v1/history/sync", json=sync_request.model_dump(by_alias=True, mode="json"))
    assert history_response.status_code == 200
    assert len(history_response.json()["scans"]) == 1
    assert history_response.json()["favorites"][0]["related_product_id"] == sync_request.favorites[0].relatedProductID

    home_response = client.post("/v1/home", json=home_request.model_dump(mode="json"))
    assert home_response.status_code == 200
    payload = home_response.json()
    assert payload["payload"]["todayFocus"]["title"]
    assert payload["payloadV2"]["hero"]["whyNow"]

    insights_response = client.post(
        "/v1/home/weekly-insights",
        json={
            "userContext": home_request.profile.userContext.model_dump(mode="json"),
            "installID": "install-home-test",
        },
    )
    assert insights_response.status_code == 200
    assert insights_response.json()["insights"]


def test_fixture_exports_match_expected_files():
    fixture_dir = Path(__file__).parent / "fixtures"
    for name, expected in fixture_models().items():
        fixture_path = fixture_dir / name
        assert fixture_path.exists(), f"Missing fixture file {fixture_path}"
        actual = json.loads(fixture_path.read_text())
        assert actual == expected


def test_delete_profile_clears_state_and_is_idempotent():
    install_id = "install-delete-test"
    home_request = starter_home_request(install_id)
    sync_request, _ = starter_history_sync_request()
    sync_request.installID = install_id

    profile_response = client.post(
        "/v1/profile/sync", json=home_request.model_dump(mode="json")
    )
    assert profile_response.status_code == 200

    history_response = client.post(
        "/v1/history/sync", json=sync_request.model_dump(by_alias=True, mode="json")
    )
    assert history_response.status_code == 200
    assert len(history_response.json()["scans"]) >= 1

    services = app.state.backend_services
    populated_state = services.repository.get_state(install_id)
    assert populated_state.profile is not None
    assert populated_state.scan_events

    delete_response = client.delete(
        "/v1/profile", headers={"X-Wellness-Install-ID": install_id}
    )
    assert delete_response.status_code == 200

    wiped_state = services.repository.get_state(install_id)
    assert wiped_state.profile is None
    assert wiped_state.scan_events == {}
    assert wiped_state.checkin_events == {}
    assert wiped_state.favorites == {}
    assert wiped_state.memory_items == {}
    assert wiped_state.scan_decisions == {}

    # Idempotent: deleting an already-empty profile still returns 200.
    repeat_response = client.delete(
        "/v1/profile", headers={"X-Wellness-Install-ID": install_id}
    )
    assert repeat_response.status_code == 200


def test_delete_profile_requires_install_id_header():
    response = client.delete("/v1/profile")
    assert response.status_code == 400
    assert "X-Wellness-Install-ID" in response.json()["detail"]


# ---------------------------------------------------------------------------
# Subscription receipt endpoints
# ---------------------------------------------------------------------------


def _subscription_report_body(install_id: str, *, expires_offset: float = 600.0) -> dict:
    from app.date_utils import apple_timestamp_now

    now = apple_timestamp_now()
    return {
        "installID": install_id,
        "productID": "com.aldoolivas.wellnesslens.plus",
        "originalTransactionID": "1000000000000001",
        "transactionID": "1000000000000001",
        "purchasedAt": now - 5,
        "expiresAt": now + expires_offset,
        "revokedAt": None,
        "tier": "plus",
        "rawTransactionJWS": "fake.jws.payload",
    }


def test_subscription_report_persists_grant_and_returns_active_state():
    body = _subscription_report_body("install-subs-active")

    response = client.post("/v1/subscriptions/report", json=body)
    assert response.status_code == 200

    payload = response.json()
    assert payload["installID"] == body["installID"]
    assert payload["tier"] == "plus"
    assert payload["state"] == "active"
    assert payload["rawTransactionJWS"] == "fake.jws.payload"

    status_response = client.get(
        "/v1/subscriptions/status",
        headers={"X-Wellness-Install-ID": body["installID"]},
    )
    assert status_response.status_code == 200
    status_payload = status_response.json()
    assert status_payload["grant"]["state"] == "active"
    assert status_payload["grant"]["tier"] == "plus"


def test_subscription_report_marks_expired_grant_when_expiration_is_past():
    body = _subscription_report_body("install-subs-expired", expires_offset=-600.0)

    response = client.post("/v1/subscriptions/report", json=body)
    assert response.status_code == 200
    assert response.json()["state"] == "expired"


def test_subscription_report_marks_revoked_when_revocation_present():
    from app.date_utils import apple_timestamp_now

    body = _subscription_report_body("install-subs-revoked")
    body["revokedAt"] = apple_timestamp_now() - 60

    response = client.post("/v1/subscriptions/report", json=body)
    assert response.status_code == 200
    assert response.json()["state"] == "revoked"


def test_subscription_status_requires_install_id_header():
    response = client.get("/v1/subscriptions/status")
    assert response.status_code == 400


def test_subscription_status_returns_null_grant_when_nothing_stored():
    response = client.get(
        "/v1/subscriptions/status",
        headers={"X-Wellness-Install-ID": "install-no-grant"},
    )
    assert response.status_code == 200
    assert response.json()["grant"] is None


def test_subscription_notification_accepts_signed_payload_and_is_idempotent():
    body = {"signedPayload": "eyJhbGciOiJFUzI1NiJ9.FAKE.SIG"}
    first = client.post("/v1/subscriptions/notification", json=body)
    assert first.status_code == 200

    # Re-entering with the same payload must be a no-op so Apple's retries are
    # safe. Nothing is persisted yet so idempotence is trivially satisfied;
    # the check enforces that nothing 4xx/5xx leaks out.
    second = client.post("/v1/subscriptions/notification", json=body)
    assert second.status_code == 200


def test_delete_profile_also_clears_subscription_grant():
    install_id = "install-delete-subscription"
    report_body = _subscription_report_body(install_id)
    client.post("/v1/subscriptions/report", json=report_body)

    # Sanity: grant is present.
    before = client.get(
        "/v1/subscriptions/status",
        headers={"X-Wellness-Install-ID": install_id},
    )
    assert before.json()["grant"] is not None

    delete = client.delete(
        "/v1/profile", headers={"X-Wellness-Install-ID": install_id}
    )
    assert delete.status_code == 200

    after = client.get(
        "/v1/subscriptions/status",
        headers={"X-Wellness-Install-ID": install_id},
    )
    assert after.status_code == 200
    assert after.json()["grant"] is None


# ---------------------------------------------------------------------------
# Rate limiting
# ---------------------------------------------------------------------------


def test_rate_limit_on_scan_analyze_returns_429_after_threshold(monkeypatch):
    # Default limit for this route is 30/minute. Reset the limiter so previous
    # tests don't pollute the bucket, then force a lower threshold to keep the
    # test fast.
    from app.main import limiter

    limiter.reset()

    sync_request, _ = starter_history_sync_request()
    profile_request = starter_home_request(sync_request.installID)
    services = app.state.backend_services or build_backend_services(Settings())
    app.state.backend_services = services

    product = make_provider_backed_product(ProductResolutionSource.openFoodFacts)
    monkeypatch.setattr(
        services.resolver, "resolve", lambda input: make_resolver_result(product), raising=False
    )

    body = {
        "input": {
            "sourceType": "manualBarcode",
            "barcode": product.barcode,
            "locale": "en_US",
        },
        "profile": profile_request.profile.model_dump(mode="json"),
        "recentScans": [],
        "recentCheckIns": [],
        "installID": "install-rate-limit-test",
    }
    headers = {"X-Wellness-Install-ID": "install-rate-limit-test"}

    # Drive traffic up to the limit. 30/minute is the configured ceiling.
    successful = 0
    for _ in range(35):
        response = client.post("/v1/scan/analyze", json=body, headers=headers)
        if response.status_code == 200:
            successful += 1
        elif response.status_code == 429:
            break
        else:
            raise AssertionError(f"Unexpected status {response.status_code}: {response.text}")

    assert successful == 30, f"Expected to reach the 30-request limit, got {successful}."

    # One more call must be 429.
    throttled = client.post("/v1/scan/analyze", json=body, headers=headers)
    assert throttled.status_code == 429
    assert "Rate limit exceeded" in throttled.json()["detail"]

    limiter.reset()


def test_healthz_is_exempt_from_rate_limiting():
    from app.main import limiter

    limiter.reset()

    # Cap higher than the global default to prove exemption kicks in.
    for _ in range(200):
        response = client.get("/healthz")
        assert response.status_code == 200


# ---------------------------------------------------------------------------
# CORS hardening
# ---------------------------------------------------------------------------


def test_cors_is_off_by_default_so_browsers_cannot_call_the_api():
    # When the whitelist is empty (default), CORSMiddleware is NOT installed,
    # so preflight requests do not get an `Access-Control-Allow-Origin` header
    # back. That keeps a malicious site from driving the API via the browser.
    response = client.options(
        "/v1/home",
        headers={
            "Origin": "https://attacker.example.com",
            "Access-Control-Request-Method": "POST",
        },
    )
    assert "access-control-allow-origin" not in {
        name.lower() for name in response.headers.keys()
    }


def test_cors_allows_configured_origins_when_env_populated(monkeypatch):
    monkeypatch.setenv(
        "WELLNESSLENS_CORS_ALLOW_ORIGINS",
        "https://wellnesslens.app,https://admin.wellnesslens.app",
    )
    get_settings.cache_clear()

    # Re-instantiate the TestClient against a freshly-built FastAPI app so the
    # CORS middleware is wired with the new setting.
    import importlib

    import app.main as main_module

    importlib.reload(main_module)
    fresh_client = TestClient(main_module.app)

    try:
        response = fresh_client.options(
            "/v1/home",
            headers={
                "Origin": "https://wellnesslens.app",
                "Access-Control-Request-Method": "POST",
            },
        )
        assert response.headers.get("access-control-allow-origin") == "https://wellnesslens.app"

        blocked = fresh_client.options(
            "/v1/home",
            headers={
                "Origin": "https://attacker.example.com",
                "Access-Control-Request-Method": "POST",
            },
        )
        # Non-whitelisted origin: the header must not be echoed back, which
        # makes the browser block the request client-side.
        assert blocked.headers.get("access-control-allow-origin") != "https://attacker.example.com"
    finally:
        monkeypatch.delenv("WELLNESSLENS_CORS_ALLOW_ORIGINS", raising=False)
        get_settings.cache_clear()
        importlib.reload(main_module)


def test_enforced_auth_rejects_missing_headers(monkeypatch):
    monkeypatch.setenv("WELLNESSLENS_FIREBASE_AUTH_ENABLED", "true")
    monkeypatch.setenv("WELLNESSLENS_APP_CHECK_ENFORCED", "true")
    get_settings.cache_clear()

    request = starter_home_request("install-secure-home")
    response = client.post("/v1/home", json=request.model_dump(mode="json"))

    assert response.status_code == 401
    assert response.json()["detail"] == "Missing Authorization header."

    monkeypatch.delenv("WELLNESSLENS_FIREBASE_AUTH_ENABLED", raising=False)
    monkeypatch.delenv("WELLNESSLENS_APP_CHECK_ENFORCED", raising=False)
    get_settings.cache_clear()


def test_enforced_auth_verifies_tokens(monkeypatch):
    monkeypatch.setenv("WELLNESSLENS_FIREBASE_AUTH_ENABLED", "true")
    monkeypatch.setenv("WELLNESSLENS_APP_CHECK_ENFORCED", "true")
    get_settings.cache_clear()

    monkeypatch.setattr("app.main.verify_firebase_id_token", lambda header: {"sub": "user-123"})
    monkeypatch.setattr("app.main.verify_firebase_app_check_token", lambda token: {"sub": "app-123"})

    request = starter_home_request("install-verified-home")
    response = client.post(
        "/v1/home",
        json=request.model_dump(mode="json"),
        headers={
            "Authorization": "Bearer valid-token",
            "X-Firebase-AppCheck": "valid-app-check",
        },
    )

    assert response.status_code == 200

    monkeypatch.delenv("WELLNESSLENS_FIREBASE_AUTH_ENABLED", raising=False)
    monkeypatch.delenv("WELLNESSLENS_APP_CHECK_ENFORCED", raising=False)
    get_settings.cache_clear()


def test_enforced_auth_rejects_invalid_tokens(monkeypatch):
    monkeypatch.setenv("WELLNESSLENS_FIREBASE_AUTH_ENABLED", "true")
    get_settings.cache_clear()

    def fail_auth(_: str):
        raise SecurityVerificationError("Invalid Firebase ID token: bad token")

    monkeypatch.setattr("app.main.verify_firebase_id_token", fail_auth)

    request = starter_home_request("install-invalid-home")
    response = client.post(
        "/v1/home",
        json=request.model_dump(mode="json"),
        headers={"Authorization": "Bearer fake-token"},
    )

    assert response.status_code == 401
    assert "Invalid Firebase ID token" in response.json()["detail"]

    monkeypatch.delenv("WELLNESSLENS_FIREBASE_AUTH_ENABLED", raising=False)
    get_settings.cache_clear()


def test_home_uses_persisted_profile_as_source_of_truth():
    stored = starter_home_request("install-authoritative-home")
    response = client.post("/v1/profile/sync", json=stored.model_dump(mode="json"))
    assert response.status_code == 200

    overridden = stored.model_copy(deep=True)
    overridden.activeGoals[0].title = "Injected goal title"
    overridden.activeGoals[0].summary = "Injected summary"

    home = client.post("/v1/home", json=overridden.model_dump(mode="json"))
    assert home.status_code == 200
    payload = home.json()["payload"]
    assert payload["todayFocus"]["title"] == stored.activeGoals[0].title
    assert payload["todayFocus"]["summary"] == stored.activeGoals[0].summary


def test_history_sync_is_idempotent_and_preserves_existing_conflicts(caplog):
    sync_request, _ = starter_history_sync_request()
    sync_request.installID = "install-sync-merge"

    first = client.post("/v1/history/sync", json=sync_request.model_dump(by_alias=True, mode="json"))
    assert first.status_code == 200

    stale = sync_request.model_copy(deep=True)
    stale.scanDecisions[0].note = "STALE NOTE WON'T APPLY"
    stale.scanDecisions[0].resolvedAt = None
    stale.favorites[0].summary = "Changed favorite summary"

    with caplog.at_level("WARNING"):
        second = client.post("/v1/history/sync", json=stale.model_dump(by_alias=True, mode="json"))

    assert second.status_code == 200
    payload = second.json()
    assert payload["scanDecisions"][0]["note"] == sync_request.scanDecisions[0].note
    assert payload["favorites"][0]["summary"] == sync_request.favorites[0].summary
    assert "history_sync_conflict" in caplog.text


def test_product_resolver_barcode_hit_returns_resolved_product(monkeypatch):
    resolver = ProductResolver(Settings())

    monkeypatch.setattr(
        resolver,
        "_get_json",
        lambda url: {
            "status": 1,
            "product": {
                "code": "7501031311309",
                "product_name": "Greek Yogurt",
                "brands": "Good Farm",
                "ingredients_text": "Milk, Cultures",
                "ingredients_tags": ["en:milk"],
                "categories_tags": ["en:yogurts"],
                "labels_tags": ["en:high-protein"],
                "nutrition_data": "on",
                "nutriments": {
                    "energy-kcal_100g": 98,
                    "proteins_100g": 10,
                    "carbohydrates_100g": 4,
                    "fat_100g": 2,
                    "sugars_100g": 4,
                    "fiber_100g": 0,
                },
            },
        },
    )

    result = resolver.resolve(
        ScanInput(
            sourceType=ScanSource.liveBarcode,
            barcode="7501031311309",
            locale="en_US",
        )
    )

    assert result.confidence == ConfidenceLevel.high
    assert result.is_directional is False
    assert result.product.name == "Greek Yogurt"
    assert result.product.brand == "Good Farm"
    assert result.product.resolution is not None
    assert result.product.resolution.source == ProductResolutionSource.openFoodFacts
    assert result.product.resolution.isDirectional is False
    assert result.product.resolution.canonicalProductID == "off:7501031311309"
    assert result.product.resolution.nutritionSnapshot.proteinGPer100g == pytest.approx(10)
    assert result.product.resolutionSemantics == [
        ProductResolutionSemantic.canonical,
        ProductResolutionSemantic.providerBacked,
    ]
    assert result.identity_source == ProductResolutionSource.openFoodFacts
    assert result.fact_sources == (ProductResolutionSource.openFoodFacts,)


def test_product_resolver_label_search_falls_back_to_directional_without_exact_match(monkeypatch):
    resolver = ProductResolver(Settings(usda_api_key="demo-usda-key"))

    monkeypatch.setattr(
        resolver,
        "_get_json",
        lambda url: {
            "products": [
                {
                    "code": "111",
                    "product_name": "Chocolate Wafer",
                    "brands": "Snack Co",
                    "ingredients_text": "Sugar, wheat flour",
                    "ingredients_tags": ["en:sugar"],
                    "categories_tags": ["en:biscuits"],
                    "labels_tags": [],
                    "nutrition_data": "on",
                    "nutriments": {"energy-kcal_100g": 460},
                }
            ]
        },
    )
    monkeypatch.setattr(
        resolver,
        "_post_json",
        lambda *args, **kwargs: pytest.fail("USDA enrichment should not run for directional matches."),
    )

    result = resolver.resolve(
        ScanInput(
            sourceType=ScanSource.labelPhoto,
            rawText="collagen peptides vanilla creamer",
            locale="en_US",
        )
    )

    assert result.is_directional is True
    assert result.product.name == "Directional label read"
    assert result.product.brand == "Directional read"
    assert result.product.resolution is not None
    assert result.product.resolution.source == ProductResolutionSource.agentInferred
    assert result.product.resolution.isDirectional is True
    assert result.product.resolutionSemantics == [
        ProductResolutionSemantic.provisional,
        ProductResolutionSemantic.directional,
        ProductResolutionSemantic.lowConfidence,
    ]
    assert result.identity_source == ProductResolutionSource.agentInferred
    assert result.fact_sources == (ProductResolutionSource.agentInferred,)
    assert result.fallback_reason in {"off_search_unranked", "off_search_low_confidence"}


def test_product_resolver_mexico_seed_catalog_adds_nom_signals(monkeypatch):
    resolver = ProductResolver(Settings())

    monkeypatch.setattr(resolver, "_get_json", lambda url: {"products": []})

    result = resolver.resolve(
        ScanInput(
            sourceType=ScanSource.labelPhoto,
            rawText="Bebida energetica con azucar EXCESO AZUCARES CONTIENE CAFEINA EVITAR EN NINOS",
            productTypeHint=ProductType.food,
            locale="es_MX",
        )
    )

    assert result.is_directional is False
    assert result.identity_source == ProductResolutionSource.localCatalog
    assert result.product.mexicoNutritionSignals is not None
    assert MexicoWarningLabel.excessSugars in result.product.mexicoNutritionSignals.warningLabels
    assert result.product.mexicoNutritionSignals.containsCaffeineWarning is True

    analysis = build_scan_analysis(
        input=ScanInput(sourceType=ScanSource.labelPhoto, rawText="bebida energetica", locale="es_MX"),
        user_context=starter_user_context(),
        resolution=result,
    )
    assert any(reason.title == "Mexico label signal" for reason in analysis.topReasons)
    assert any("Senales de etiqueta Mexico" in warning for warning in analysis.warnings)


def test_product_resolver_partial_mexico_label_stays_directional_with_signals(monkeypatch):
    resolver = ProductResolver(Settings())

    monkeypatch.setattr(resolver, "_get_json", lambda url: {"products": []})

    result = resolver.resolve(
        ScanInput(
            sourceType=ScanSource.labelPhoto,
            rawText="Gomitas aciduladas EXCESO SODIO CONTIENE EDULCORANTES sucralosa",
            productTypeHint=ProductType.food,
            locale="es_MX",
        )
    )

    assert result.is_directional is True
    assert result.identity_source == ProductResolutionSource.agentInferred
    assert result.product.mexicoNutritionSignals is not None
    assert MexicoWarningLabel.excessSodium in result.product.mexicoNutritionSignals.warningLabels
    assert result.product.mexicoNutritionSignals.containsSweetenerWarning is True


def test_product_resolver_enriches_nutrients_with_usda_only_for_strong_match(monkeypatch):
    resolver = ProductResolver(Settings(usda_api_key="demo-usda-key"))

    monkeypatch.setattr(
        resolver,
        "_get_json",
        lambda url: {
            "status": 1,
            "product": {
                "code": "012345678905",
                "product_name": "Protein Oats",
                "brands": "Steady Foods",
                "ingredients_text": "Oats, milk protein",
                "ingredients_tags": ["en:oats", "en:milk-protein"],
                "categories_tags": ["en:breakfast-cereals"],
                "labels_tags": ["en:high-protein"],
                "nutrition_data": "on",
                "nutriments": {
                    "energy-kcal_100g": 380,
                    "proteins_100g": 15,
                },
            },
        },
    )
    captured_requests: list[dict] = []

    def _fake_post_json(url: str, payload: dict, *, extra_headers: dict | None = None) -> dict:
        captured_requests.append(
            {"url": url, "payload": payload, "extra_headers": extra_headers or {}}
        )
        return {
            "foods": [
                {
                    "gtinUpc": "012345678905",
                    "description": "Protein Oats",
                    "brandOwner": "Steady Foods",
                    "foodNutrients": [
                        {"nutrientName": "Energy", "value": 380},
                        {"nutrientName": "Protein", "value": 15},
                        {"nutrientName": "Carbohydrate, by difference", "value": 42},
                        {"nutrientName": "Total lipid (fat)", "value": 6},
                        {"nutrientName": "Total Sugars", "value": 5},
                        {"nutrientName": "Fiber, total dietary", "value": 8},
                        {"nutrientName": "Sodium, Na", "value": 210},
                    ],
                }
            ]
        }

    monkeypatch.setattr(resolver, "_post_json", _fake_post_json)

    result = resolver.resolve(
        ScanInput(
            sourceType=ScanSource.manualBarcode,
            barcode="012345678905",
            locale="en_US",
        )
    )

    assert result.is_directional is False
    assert result.product.resolution is not None
    assert result.product.resolution.source == ProductResolutionSource.openFoodFacts
    assert result.product.resolution.nutritionSnapshot.carbsGPer100g == pytest.approx(42)
    assert result.product.resolution.nutritionSnapshot.fiberGPer100g == pytest.approx(8)
    assert result.product.resolutionSemantics == [
        ProductResolutionSemantic.canonical,
        ProductResolutionSemantic.providerBacked,
    ]
    assert result.identity_source == ProductResolutionSource.openFoodFacts
    assert result.fact_sources == (
        ProductResolutionSource.openFoodFacts,
        ProductResolutionSource.usdaFoodDataCentral,
    )
    assert "USDA FoodData Central" in " ".join(result.product.notes)

    # R-6: the USDA api key must travel via the `X-Api-Key` header instead
    # of the query string. Verify both directions so a future refactor can't
    # silently regress the exposure.
    assert captured_requests, "USDA POST should have been invoked for strong matches."
    for call in captured_requests:
        assert "api_key=" not in call["url"], (
            "USDA api key must not appear in the request URL (seen in logs). "
            f"URL was: {call['url']}"
        )
        assert call["extra_headers"].get("X-Api-Key") == "demo-usda-key", (
            "USDA api key must be passed via the X-Api-Key header."
        )


def test_product_resolver_dsld_label_search_returns_provider_backed_supplement(monkeypatch):
    resolver = ProductResolver(Settings(usda_api_key="demo-usda-key"))

    def fake_get_json(url: str):
        if "search-filter" in url:
            return {
                "hits": [
                    {
                        "_id": "33919",
                        "_source": {
                            "fullName": "Magnesium Glycinate",
                            "brandName": "Vinco's",
                            "allIngredients": [
                                {"name": "Magnesium Glycinate", "notes": ""},
                                {"name": "Magnesium", "notes": "Magnesium (Form: from Magnesium Glycinate)"},
                            ],
                            "claims": [{"langualCodeDescription": "Structure/Function"}],
                            "productType": {"langualCodeDescription": "Mineral"},
                        },
                    }
                ]
            }
        if url.endswith("/label/33919"):
            return {
                "id": "33919",
                "fullName": "Magnesium Glycinate",
                "brandName": "Vinco's",
                "upcSku": "7 39930 19531 8",
                "ingredientRows": [
                    {"name": "Magnesium Glycinate", "notes": None},
                    {"name": "Magnesium", "notes": "Magnesium (Form: from Magnesium Glycinate)"},
                ],
                "otheringredients": {"ingredients": [{"name": "Xylitol"}]},
                "statements": [
                    {
                        "type": "Suggested/Recommended/Usage/Directions",
                        "notes": "Take one teaspoon daily.",
                    }
                ],
                "claims": [{"langualCodeDescription": "Structure/Function"}],
                "productType": {"langualCodeDescription": "Mineral"},
            }
        pytest.fail(f"Unexpected URL: {url}")

    monkeypatch.setattr(resolver, "_get_json", fake_get_json)
    monkeypatch.setattr(
        resolver,
        "_post_json",
        lambda *args, **kwargs: pytest.fail("USDA enrichment should not run for NIH DSLD matches."),
    )

    result = resolver.resolve(
        ScanInput(
            sourceType=ScanSource.manualLabel,
            rawText="magnesium glycinate",
            productTypeHint=ProductType.supplement,
            locale="en_US",
        )
    )

    assert result.is_directional is False
    assert result.product.productType == ProductType.supplement
    assert result.product.name == "Magnesium Glycinate"
    assert result.product.resolution is not None
    assert result.product.resolution.source == ProductResolutionSource.nihDSLD
    assert result.product.resolution.canonicalProductID == "dsld:33919"
    assert result.product.resolutionSemantics == [
        ProductResolutionSemantic.canonical,
        ProductResolutionSemantic.providerBacked,
    ]
    assert result.identity_source == ProductResolutionSource.nihDSLD
    assert result.fact_sources == (ProductResolutionSource.nihDSLD,)


def test_product_resolver_barcode_falls_back_to_dsld_after_off_miss(monkeypatch):
    resolver = ProductResolver(Settings())
    requested_urls: list[str] = []

    def fake_get_json(url: str):
        requested_urls.append(url)
        if "/api/v2/product/" in url:
            return {"status": 0}
        if "search-filter" in url:
            return {
                "hits": [
                    {
                        "_id": "33919",
                        "_source": {
                            "fullName": "Magnesium Glycinate",
                            "brandName": "Vinco's",
                            "allIngredients": [{"name": "Magnesium Glycinate", "notes": ""}],
                            "claims": [{"langualCodeDescription": "Structure/Function"}],
                            "productType": {"langualCodeDescription": "Mineral"},
                        },
                    }
                ]
            }
        if url.endswith("/label/33919"):
            return {
                "id": "33919",
                "fullName": "Magnesium Glycinate",
                "brandName": "Vinco's",
                "upcSku": "7 39930 19531 8",
                "ingredientRows": [{"name": "Magnesium Glycinate", "notes": None}],
                "otheringredients": {"ingredients": []},
                "statements": [],
                "claims": [{"langualCodeDescription": "Structure/Function"}],
                "productType": {"langualCodeDescription": "Mineral"},
            }
        pytest.fail(f"Unexpected URL: {url}")

    monkeypatch.setattr(resolver, "_get_json", fake_get_json)

    result = resolver.resolve(
        ScanInput(
            sourceType=ScanSource.manualBarcode,
            barcode="739930195318",
            locale="en_US",
        )
    )

    assert result.is_directional is False
    assert result.product.resolution is not None
    assert result.product.resolution.source == ProductResolutionSource.nihDSLD
    assert result.identity_source == ProductResolutionSource.nihDSLD
    assert result.product.resolutionSemantics == [
        ProductResolutionSemantic.canonical,
        ProductResolutionSemantic.providerBacked,
    ]
    assert any("/api/v2/product/" in url for url in requested_urls)
    assert any("search-filter" in url for url in requested_urls)


def test_product_resolver_dsld_miss_falls_back_to_directional(monkeypatch):
    resolver = ProductResolver(Settings())

    monkeypatch.setattr(resolver, "_get_json", lambda url: {"hits": []})

    result = resolver.resolve(
        ScanInput(
            sourceType=ScanSource.manualLabel,
            rawText="mystery herbal powder",
            productTypeHint=ProductType.supplement,
            locale="en_US",
        )
    )

    assert result.is_directional is True
    assert result.product.resolution is not None
    assert result.product.resolution.source == ProductResolutionSource.agentInferred
    assert result.product.productType == ProductType.supplement
    assert result.product.resolutionSemantics == [
        ProductResolutionSemantic.provisional,
        ProductResolutionSemantic.directional,
        ProductResolutionSemantic.lowConfidence,
    ]
    assert result.identity_source == ProductResolutionSource.agentInferred
    assert result.fallback_reason == "dsld_search_empty"


def test_product_resolver_food_scope_still_uses_off(monkeypatch):
    resolver = ProductResolver(Settings())
    requested_urls: list[str] = []

    def fake_get_json(url: str):
        requested_urls.append(url)
        if "/api/v2/product/" in url:
            return {
                "status": 1,
                "product": {
                    "code": "7501031311309",
                    "product_name": "Greek Yogurt",
                    "brands": "Good Farm",
                    "ingredients_text": "Milk, Cultures",
                    "ingredients_tags": ["en:milk"],
                    "categories_tags": ["en:yogurts"],
                    "labels_tags": ["en:high-protein"],
                    "nutrition_data": "on",
                    "nutriments": {"energy-kcal_100g": 98, "proteins_100g": 10},
                },
            }
        pytest.fail(f"Unexpected URL: {url}")

    monkeypatch.setattr(resolver, "_get_json", fake_get_json)

    result = resolver.resolve(
        ScanInput(
            sourceType=ScanSource.manualBarcode,
            barcode="7501031311309",
            productTypeHint=ProductType.food,
            locale="en_US",
        )
    )

    assert result.is_directional is False
    assert result.product.resolution is not None
    assert result.product.resolution.source == ProductResolutionSource.openFoodFacts
    assert result.identity_source == ProductResolutionSource.openFoodFacts
    assert not any("api.ods.od.nih.gov" in url for url in requested_urls)


def test_build_scan_analysis_marks_low_confidence_on_resolutionless_fallback():
    analysis = build_scan_analysis(
        ScanInput(
            sourceType=ScanSource.manualLabel,
            rawText="protein, fiber, chia, blueberries",
            locale="en_US",
        ),
        starter_home_request("install-semantic-test").profile.userContext,
    )

    assert analysis.resolvedProduct.resolution is None
    assert analysis.resolvedProduct.resolutionSemantics == [ProductResolutionSemantic.lowConfidence]
