# WellnessLens Agent Service

Structured strategist service for the WellnessLens production stack.

## Scope

- Exposes a dedicated API for cloud strategist replies.
- Exposes a dedicated API for structured scan verdicts.
- Keeps the strategist off the synchronous scan path.
- Uses repo-stored runtime assets for the scan verdict prompt, schema, and golden examples.
- Supports a deterministic local provider and a Vertex path with schema validation plus local fallback.
- Returns only structured outputs so iOS can keep a strict contract boundary.

## Endpoints

- `GET /healthz`
- `POST /v1/strategist/reply`
- `POST /v1/scan/verdict`

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

## Scan Verdict Runtime Assets

The scan verdict runtime is loaded from:

- `agent-service/assets/scan_verdict/LILA_SystemPrompt.md`
- `agent-service/assets/scan_verdict/ScanVerdictSchema.json`
- `agent-service/assets/scan_verdict/LILA_GoldenExamples.md`

The service fingerprints those files into a runtime version, validates the golden examples at startup/load time, and validates every provider/local verdict against the real schema before returning it.
