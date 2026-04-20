from __future__ import annotations

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.config import get_settings
from app.security import SecurityVerificationError
from app.services import fixture_models, starter_history_sync_request, starter_home_request


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
    assert payload["flags"]["structuredAnalysis"] is True
    assert payload["killSwitches"]["scanDisabled"] is False


def test_analyze_structured_returns_contract_compatible_payload():
    sync_request, _ = starter_history_sync_request()
    profile_request = starter_home_request(sync_request.installID)
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


def test_profile_sync_history_sync_and_home_flow():
    home_request = starter_home_request("install-home-test")
    sync_request, _ = starter_history_sync_request()
    sync_request.installID = "install-home-test"

    profile_response = client.post("/v1/profile/sync", json=home_request.model_dump(mode="json"))
    assert profile_response.status_code == 200

    history_response = client.post("/v1/history/sync", json=sync_request.model_dump(by_alias=True, mode="json"))
    assert history_response.status_code == 200
    assert len(history_response.json()["scans"]) == 1

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
