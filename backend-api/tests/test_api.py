from __future__ import annotations

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import Settings, get_settings
from app.contracts import (
    ConfidenceLevel,
    Ingredient,
    ProductCandidate,
    ProductResolution,
    ProductResolutionSemantic,
    ProductResolutionSource,
    ProductType,
    ScanInput,
    ScanSource,
)
from app.main import app, build_backend_services
from app.product_resolver import ProductResolver, ResolverResult
from app.security import SecurityVerificationError
from app.services import (
    build_scan_analysis,
    fixture_models,
    starter_history_sync_request,
    starter_home_request,
)


client = TestClient(app)


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
    monkeypatch.setattr(
        resolver,
        "_post_json",
        lambda url, payload: {
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
        },
    )

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
