# WellnessLens Agent Service

Structured strategist service for the WellnessLens production stack.

## Scope

- Exposes a dedicated API for cloud strategist replies.
- Keeps the strategist off the synchronous scan path.
- Supports a deterministic local provider today and a pluggable Vertex provider later.
- Returns only structured outputs so iOS can keep a strict contract boundary.

## Endpoints

- `GET /healthz`
- `POST /v1/strategist/reply`

## Local Run

```bash
cd agent-service
uvicorn app.main:app --reload
```

## Environment

- `WELLNESSLENS_AGENT_ENV=dev|staging|prod`
- `WELLNESSLENS_AGENT_PROVIDER=local|vertex`
- `WELLNESSLENS_AGENT_VERTEX_MODEL=gemini-2.5-pro`
- `WELLNESSLENS_AGENT_VERTEX_PROJECT=<gcp-project>`
- `WELLNESSLENS_AGENT_VERTEX_LOCATION=us-central1`

When `WELLNESSLENS_AGENT_PROVIDER=vertex`, the service still validates its request/response contracts locally before returning anything to clients.
