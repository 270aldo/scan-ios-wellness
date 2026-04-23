from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.security import SecurityVerificationError
from app.coach_runtime import CoachAssetError
from app.scan_verdict_runtime import ScanVerdictAssetError, get_scan_verdict_assets
from app.service import StrategistService, get_settings


client = TestClient(app)


def test_healthz():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_strategist_reply_contract():
    response = client.post(
        "/v1/strategist/reply",
        json={
            "profileSummary": "User is optimizing calmer energy and digestion.",
            "tone": "calm_and_direct",
            "userMessage": "What should I do next?",
            "context": {
                "activeGoals": ["Steadier energy"],
                "recentSignals": ["Energy improved after breakfast"],
                "recentProducts": ["Balanced Protein Yogurt"],
                "openLoops": ["Need a follow-up check-in on the saved breakfast anchor."],
                "memorySummaries": ["Protein-forward breakfasts tend to hold better."],
                "weeklyNarrative": "Momentum is improving when breakfast is less reactive.",
            },
        },
    )
    assert response.status_code == 200
    payload = response.json()["reply"]
    assert payload["source"]
    assert payload["cards"]
    assert payload["safetyNotes"]


def test_scan_verdict_contract():
    assets = get_scan_verdict_assets()
    response = client.post(
        "/v1/scan/verdict",
        json={
            "scanId": "scan-123",
            "productName": "Berry Yogurt",
            "source": "meal_photo",
            "userContextSummary": "User is protecting steadier energy after recent crashes.",
            "structuredSummary": "Likely higher sugar load than ideal for an afternoon anchor.",
        },
    )
    assert response.status_code == 200
    payload = response.json()["verdict"]
    assert payload["fit"] == "occasional"
    assert payload["confidence"] == "low"
    assert len(payload["lensScores"]) == 5
    assert len(payload["watchouts"]) <= 2
    assert payload["reasoningBreakdown"]["agentInsights"]
    assert payload["disclaimer"]
    assets.validate_payload(payload)


def test_scan_verdict_contract_accepts_resolved_product_metadata():
    response = client.post(
        "/v1/scan/verdict",
        json={
            "scanId": "scan-resolved-product",
            "productName": "Balanced Protein Yogurt",
            "source": "barcode",
            "userContextSummary": "User wants steadier energy and calmer digestion this week.",
            "structuredSummary": "Strong packaged-food match with high protein and low sugar.",
            "resolved_product": {
                "product_id": "off:7501031311309",
                "canonical_product_id": "off:7501031311309",
                "name": "Balanced Protein Yogurt",
                "brand": "Good Farm",
                "barcode": "7501031311309",
                "source": "openFoodFacts",
                "confidence": 0.91,
                "ingredients": ["milk", "cultures"],
                "nutrition_snapshot": {
                    "energy_kcal_per_100g": 96,
                    "protein_g_per_100g": 11,
                    "carbs_g_per_100g": 4,
                    "fat_g_per_100g": 3,
                    "sugars_g_per_100g": 4,
                    "fiber_g_per_100g": 0,
                },
                "is_directional": False,
            },
        },
    )

    assert response.status_code == 200
    payload = response.json()["verdict"]
    assert payload["confidence"] == "high"
    assert payload["sources"][0]["organization"] == "Open Food Facts"
    assert payload["sources"][0]["title"] == "Balanced Protein Yogurt"
    assert payload["reasoningBreakdown"]["agentInsights"][0]["insight"]


def test_scan_verdict_directional_resolution_downgrades_confidence_and_adds_watchout():
    response = client.post(
        "/v1/scan/verdict",
        json={
            "scanId": "scan-directional-label",
            "productName": "Directional label read",
            "source": "label_photo",
            "userContextSummary": "User is trying to protect steadier energy and reduce bloating.",
            "structuredSummary": "OCR extracted an incomplete label and no exact packaged-food match was confirmed.",
            "resolved_product": {
                "product_id": "directional:abc123",
                "name": "Directional label read",
                "brand": "Directional read",
                "source": "agentInferred",
                "confidence": 0.42,
                "ingredients": ["oats", "sweetener"],
                "is_directional": True,
            },
        },
    )

    assert response.status_code == 200
    payload = response.json()["verdict"]
    assert payload["confidence"] in {"low", "insufficient"}
    assert payload["sources"][0]["organization"] == "WellnessLens directional resolver"
    assert any(item["title"] == "Producto no resuelto del todo" for item in payload["watchouts"])


def test_scan_verdict_assets_load_and_validate_golden_examples():
    assets = get_scan_verdict_assets()
    assert assets.version
    assert assets.system_prompt.startswith("Eres LILA")
    assert len(assets.golden_example_payloads) >= 5
    for payload in assets.golden_example_payloads:
        assets.validate_payload(payload)


def test_scan_verdict_vertex_provider_falls_back_to_local(monkeypatch):
    monkeypatch.setenv("WELLNESSLENS_AGENT_PROVIDER", "vertex")
    monkeypatch.setenv("WELLNESSLENS_AGENT_VERTEX_PROJECT", "demo-project")
    get_settings.cache_clear()

    def fail_provider(self, request, assets):
        raise RuntimeError("simulated vertex outage")

    monkeypatch.setattr(StrategistService, "_vertex_verdict", fail_provider)
    app.state.strategist_service = StrategistService(settings=get_settings())

    response = client.post(
        "/v1/scan/verdict",
        json={
            "scanId": "scan-vertex-fallback",
            "productName": "Energy Drink",
            "source": "label_photo",
            "userContextSummary": "User is in fase lútea and reports caffeine sensitivity this week.",
            "structuredSummary": "High sugar load with 160mg caffeine and no meaningful protein.",
        },
    )

    assert response.status_code == 200
    payload = response.json()["verdict"]
    assert payload["fit"] == "skip"
    assert payload["reasoningBreakdown"]["agentInsights"][0]["modelUsed"].startswith("deterministic-local/")
    assert "fallback" in payload["reasoningBreakdown"]["agentInsights"][0]["insight"].lower()
    get_scan_verdict_assets().validate_payload(payload)

    monkeypatch.delenv("WELLNESSLENS_AGENT_PROVIDER", raising=False)
    monkeypatch.delenv("WELLNESSLENS_AGENT_VERTEX_PROJECT", raising=False)
    get_settings.cache_clear()
    app.state.strategist_service = StrategistService(settings=get_settings())


@pytest.mark.parametrize(
    ("path", "payload"),
    [
        (
            "/v1/strategist/reply",
            {
                "profileSummary": "User is optimizing calmer energy and digestion.",
                "tone": "calm_and_direct",
                "userMessage": "What should I do next?",
                "context": {
                    "activeGoals": ["Steadier energy"],
                    "recentSignals": [],
                    "recentProducts": [],
                    "openLoops": [],
                    "memorySummaries": [],
                    "weeklyNarrative": None,
                },
            },
        ),
        (
            "/v1/scan/verdict",
            {
                "scanId": "scan-auth-test",
                "productName": "Berry Yogurt",
                "source": "meal_photo",
                "userContextSummary": "User is protecting steadier energy.",
                "structuredSummary": "Likely higher sugar load than ideal.",
            },
        ),
        (
            "/v1/coach/reply",
            {
                "userMessage": "Hola",
                "userContextSummary": "User is testing auth.",
            },
        ),
    ],
)
def test_agent_endpoints_require_auth_when_enforced(monkeypatch, path, payload):
    monkeypatch.setenv("WELLNESSLENS_AGENT_ENV", "prod")
    get_settings.cache_clear()
    app.state.strategist_service = StrategistService(
        settings=get_settings(),
        scan_assets=get_scan_verdict_assets(),
    )

    response = client.post(path, json=payload)

    assert response.status_code == 401
    assert response.json()["detail"] == "Missing Authorization header."

    monkeypatch.delenv("WELLNESSLENS_AGENT_ENV", raising=False)
    get_settings.cache_clear()
    app.state.strategist_service = StrategistService(settings=get_settings())


def test_agent_endpoints_verify_tokens_when_enforced(monkeypatch):
    monkeypatch.setenv("WELLNESSLENS_AGENT_ENV", "prod")
    get_settings.cache_clear()
    monkeypatch.setattr("app.main.verify_firebase_id_token", lambda header: {"sub": "user-123"})
    monkeypatch.setattr("app.main.verify_firebase_app_check_token", lambda token: {"sub": "app-123"})
    app.state.strategist_service = StrategistService(
        settings=get_settings(),
        scan_assets=get_scan_verdict_assets(),
    )

    response = client.post(
        "/v1/coach/reply",
        json={
            "userMessage": "Hola",
            "userContextSummary": "User is testing auth.",
        },
        headers={
            "Authorization": "Bearer valid-token",
            "X-Firebase-AppCheck": "valid-app-check",
        },
    )

    assert response.status_code == 200
    assert response.json()["replyId"]

    monkeypatch.delenv("WELLNESSLENS_AGENT_ENV", raising=False)
    get_settings.cache_clear()
    app.state.strategist_service = StrategistService(settings=get_settings())


def test_agent_endpoints_reject_invalid_tokens(monkeypatch):
    monkeypatch.setenv("WELLNESSLENS_AGENT_ENV", "prod")
    monkeypatch.setenv("WELLNESSLENS_AGENT_APP_CHECK_ENFORCED", "false")
    get_settings.cache_clear()

    def fail_auth(_: str):
        raise SecurityVerificationError("Invalid Firebase ID token: bad token")

    monkeypatch.setattr("app.main.verify_firebase_id_token", fail_auth)
    app.state.strategist_service = StrategistService(
        settings=get_settings(),
        scan_assets=get_scan_verdict_assets(),
    )

    response = client.post(
        "/v1/scan/verdict",
        json={
            "productName": "Berry Yogurt",
            "source": "meal_photo",
            "userContextSummary": "User is testing auth.",
        },
        headers={"Authorization": "Bearer fake-token"},
    )

    assert response.status_code == 401
    assert "Invalid Firebase ID token" in response.json()["detail"]

    monkeypatch.delenv("WELLNESSLENS_AGENT_ENV", raising=False)
    monkeypatch.delenv("WELLNESSLENS_AGENT_APP_CHECK_ENFORCED", raising=False)
    get_settings.cache_clear()
    app.state.strategist_service = StrategistService(settings=get_settings())


def test_agent_startup_fails_when_scan_assets_are_missing(monkeypatch):
    monkeypatch.setenv("WELLNESSLENS_AGENT_SCAN_ASSETS_DIR", "/tmp/does-not-exist")
    get_settings.cache_clear()

    with pytest.raises(ScanVerdictAssetError):
        with TestClient(app):
            pass

    monkeypatch.delenv("WELLNESSLENS_AGENT_SCAN_ASSETS_DIR", raising=False)
    get_settings.cache_clear()


def test_agent_startup_fails_when_coach_assets_are_missing(monkeypatch):
    monkeypatch.setenv("WELLNESSLENS_AGENT_COACH_ASSETS_DIR", "/tmp/does-not-exist")
    get_settings.cache_clear()

    with pytest.raises(CoachAssetError):
        with TestClient(app):
            pass

    monkeypatch.delenv("WELLNESSLENS_AGENT_COACH_ASSETS_DIR", raising=False)
    get_settings.cache_clear()
