from __future__ import annotations

import json
from pathlib import Path

from fastapi.testclient import TestClient

from app.main import app
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
