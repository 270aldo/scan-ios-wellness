from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app
from app.scan_verdict_runtime import get_scan_verdict_assets
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
