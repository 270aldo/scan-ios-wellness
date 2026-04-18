# WellnessLens

WellnessLens is an iPhone-first SwiftUI app for women's wellness scanning. The repo now contains three major surfaces:

- `WellnessLens/`: the iOS client
- `backend-api/`: the structured app backend
- `agent-service/`: the dedicated strategist and scan verdict agent service

The project is no longer in "empty prototype" mode. The repo already has a working legacy pipeline, a staged LILA v2 bridge, a visible scan verdict surface, and a real prompt/schema runtime for the backend scan verdict endpoint.

## Current repo status

### Foundation-first milestone implemented

- LILA v2 domain added under `WellnessLens/Domain/LILA/`
- compatibility bridge kept in `WellnessLens/Domain/LILA/LILACompatibility.swift`
- separate `ScanVerdictAgent` layer in `WellnessLens/Infrastructure/ScanVerdictAgent.swift`
- minimal `HealthKitService` with graceful degradation
- persistence for `scanVerdicts`
- `latestVerdict` available in `AppModel`
- backend endpoint `POST /v1/scan/verdict`

### PRD 1 implemented

- `AnalysisView` prioritizes a `ScanVerdict` surface with legacy fallback
- `HomeView` reads and surfaces `latestVerdict`
- `AppModel` can look up a `ScanVerdict` from a `ScanAnalysis`
- iOS build and tests were green after PRD 1

### PRD 2 implemented

- repo-stored assets for scan verdict runtime:
  - `agent-service/assets/scan_verdict/LILA_SystemPrompt.md`
  - `agent-service/assets/scan_verdict/ScanVerdictSchema.json`
  - `agent-service/assets/scan_verdict/LILA_GoldenExamples.md`
- loader, parsing, schema validation, and asset fingerprint versioning in `agent-service/app/scan_verdict_runtime.py`
- `agent-service` now validates structured output against the real schema
- deterministic local fallback remains available if the provider fails

## Repo map

- `WellnessLens/`: SwiftUI app, domain, features, platform services, tests
- `agent-service/`: FastAPI service for strategist and scan verdict contracts
- `backend-api/`: FastAPI app backend for home, history, scan analysis, and client config
- `infra/`: Terraform for dev, staging, and prod
- `docs/`: architecture notes, handoff docs, rollout notes, and current project status
- `artifacts/ui-audit/`: visual audit screenshots and working collateral; useful context, not core runtime code

## Read this first

If you are continuing work in this repo, start here:

- [docs/PROJECT_STATUS.md](/Users/aldoolivas/IOS_ngx-silver/docs/PROJECT_STATUS.md)
- [docs/CLAUDE_HANDOFF_SUMMARY.md](/Users/aldoolivas/IOS_ngx-silver/docs/CLAUDE_HANDOFF_SUMMARY.md)
- [docs/ADAPTED_PRDS_NEXT.md](/Users/aldoolivas/IOS_ngx-silver/docs/ADAPTED_PRDS_NEXT.md)
- [AGENTS.md](/Users/aldoolivas/IOS_ngx-silver/AGENTS.md)

## Project setup

1. Generate the Xcode project:

```bash
xcodegen generate
```

2. Open the project:

```bash
open WellnessLens.xcodeproj
```

3. Build from the command line:

```bash
xcodebuild -project WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
```

4. Run iOS tests:

```bash
xcodebuild -project WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

5. Run the agent-service tests:

```bash
pytest agent-service/tests/test_agent_api.py
```

## Runtime configuration

The iOS app reads these keys from `Info.plist`, which is generated from [`project.yml`](/Users/aldoolivas/IOS_ngx-silver/project.yml):

- `WLUseDemoData`
- `WLBackendBaseURL`
- `WLFirebaseEnabled`
- `WLStoreKitEnabled`
- `WLUseAppCheckDebugProvider`
- `WLPlusProductID`
- `WLProProductID`

Default behavior stays in demo mode so the app remains usable without backend services.

## Firebase setup

1. Copy `WellnessLens/Support/GoogleService-Info.plist.example` to `WellnessLens/Support/GoogleService-Info.plist`.
2. Replace the placeholder values with your Firebase project values.
3. Set `WLFirebaseEnabled = YES` and `WLUseDemoData = NO`.
4. Set `WLBackendBaseURL` to the API root for your Functions or API gateway.

The project is already configured for:

- `FirebaseCore`
- `FirebaseAuth`
- `FirebaseFirestore`
- `FirebaseFunctions`
- `FirebaseStorage`
- `FirebaseAppCheck`

## Architecture notes

- `WellnessLens/Domain/WellnessCore.swift` still contains the legacy deterministic engine and sample catalog.
- `WellnessLens/Domain/LILA/` contains the namespaced LILA v2 domain and compatibility layer.
- `WellnessLens/Infrastructure/PlatformServices.swift` owns persistence, scan services, and injected platform services.
- `WellnessLens/Infrastructure/BackendServices.swift` contains backend contracts and cloud client plumbing.
- `WellnessLens/App/AppModel.swift` coordinates scans, verdicts, home state, history, check-ins, subscriptions, and onboarding flow.
- `agent-service/` owns structured strategist and scan verdict contracts.
- `backend-api/` owns the app-facing backend for synchronized app payloads.

## Next recommended steps

- PRD 3: formalize the coach agent as a service separate from scan verdict
- Product graph and resolver layer for real barcode and OCR resolution
- Nutrient intelligence engine to replace demo heuristics with richer contextual scoring
- Remote iOS hookup to live `scan/verdict` once staging provider behavior is verified
