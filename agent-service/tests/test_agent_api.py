from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app


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
