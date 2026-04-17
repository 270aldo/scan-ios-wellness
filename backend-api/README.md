# WellnessLens Backend API

FastAPI service that provides the first production slice for WellnessLens:

- Contract-compatible endpoints for the current iOS client.
- Backend-managed client config and feature flags.
- Sync-safe persistence abstraction with in-memory and Firestore backends.
- GCP-ready deployment path for Cloud Run.

## Local run

```bash
cd backend-api
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --reload
```

## Local tests

```bash
cd backend-api
source .venv/bin/activate
pytest
```

## Environment

- `WELLNESSLENS_ENV`
- `WELLNESSLENS_USE_FIRESTORE`
- `WELLNESSLENS_FIREBASE_AUTH_ENABLED`
- `WELLNESSLENS_APP_CHECK_ENFORCED`
- `WELLNESSLENS_MINIMUM_SUPPORTED_VERSION`
- `WELLNESSLENS_MINIMUM_SUPPORTED_BUILD`
- `WELLNESSLENS_COPY_VERSION`

## Implemented endpoints

- `GET /healthz`
- `GET /v1/client-config`
- `POST /analyzeProduct`
- `POST /saveCheckIn`
- `POST /v1/scan/analyze`
- `POST /v1/scan/feedback`
- `POST /v1/home`
- `POST /v1/home/weekly-insights`
- `POST /v1/profile/sync`
- `POST /v1/onboarding/complete`
- `POST /v1/history/sync`
- `POST /v1/scans/decision`
- `POST /v1/favorites`
- `POST /v1/memory/upsert`

## Notes

- Dates intentionally use Apple Foundation JSON date semantics: numeric seconds since `2001-01-01T00:00:00Z`.
- Contract fixtures are generated into `tests/fixtures/` by `scripts/export_fixtures.py`.
- Deprecated routes from the audit are intentionally not implemented in this slice.
