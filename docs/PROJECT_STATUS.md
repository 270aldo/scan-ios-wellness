# Project Status

Last updated: 2026-04-21

## Executive summary

This repo is already past the "prototype only" phase.

The current state is:

- legacy scan pipeline still works
- LILA v2 domain exists behind an incremental bridge
- `ScanVerdict` is now a first-class runtime concept
- PRD 1 is implemented in the iOS app
- PRD 2 is implemented in `agent-service`
- PRD 3 coach replies are implemented end-to-end across `agent-service` and iOS
- PRD 4 is now in progress on the real repo, with product identity foundation and shared resolution semantics already implemented
- `StrategistChatView` stays visually unchanged while `AppModel.sendStrategistMessage(...)` routes through `coachAgent`
- fallback behavior remains available when remote provider output is missing or invalid

The repo should be treated as an incremental migration, not a rewrite candidate.

## What is already in place

### Foundation-first milestone

- namespaced LILA v2 domain under `WellnessLens/Domain/LILA/`
- compatibility bridge in `WellnessLens/Domain/LILA/LILACompatibility.swift`
- separate `ScanVerdictAgent`
- minimal `HealthKitService`
- persisted `scanVerdicts`
- `latestVerdict` in `AppModel`
- backend endpoint `POST /v1/scan/verdict`

### PRD 1: Scan Verdict Surface

- `AnalysisView` prioritizes a `ScanVerdict` surface with legacy fallback
- `HomeView` contains a minimal `latestVerdict` surface
- `AppModel` exposes verdict lookup for `ScanAnalysis`
- iOS build and tests were green after the PRD 1 implementation

### PRD 2: Runtime Prompt + Schema Real

- real runtime assets are now stored in:
  - `agent-service/assets/scan_verdict/LILA_SystemPrompt.md`
  - `agent-service/assets/scan_verdict/ScanVerdictSchema.json`
  - `agent-service/assets/scan_verdict/LILA_GoldenExamples.md`
- `agent-service/app/scan_verdict_runtime.py` now:
  - loads assets
  - extracts runtime prompt content
  - fingerprints the asset set into a runtime version
  - validates golden examples
  - validates every returned scan verdict against the real schema
- `agent-service/app/service.py` now:
  - serves real structured scan verdict output
  - attempts provider-backed structured output in Vertex mode
  - falls back to deterministic local output if provider execution fails or returns invalid JSON

### PRD 3: Coach Agent

- real runtime assets are now stored in:
  - `agent-service/assets/coach_agent/LILA_CoachPrompt.md`
  - `agent-service/assets/coach_agent/CoachReplySchema.json`
  - `agent-service/assets/coach_agent/LILA_CoachGoldenExamples.md`
- `agent-service/app/coach_runtime.py` now:
  - loads and fingerprints coach assets
  - validates golden examples at startup
  - validates every `CoachReply` against the repo-stored schema
- `agent-service` now serves `POST /v1/coach/reply`
- iOS now contains:
  - `WellnessLens/Infrastructure/CoachAgent.swift`
  - `WellnessLens/Infrastructure/RemoteCoachAgent.swift`
- `AppServices` now exposes `coachAgent`
- `AppModel.sendStrategistMessage(...)` now:
  - appends the user message immediately
  - serializes coach replies to keep thread ordering stable
  - maps `CoachReply` into `ConversationMessage`
  - preserves strategist UI while switching the underlying provider path
- deterministic local fallback remains available offline and is also used when remote coach calls fail
- Gap 1 was closed by translating iOS fallback LILA headlines to es-MX in `LILACompatibility.swift`

### PRD 4: Product Graph / Resolution Layer (partial)

- `WellnessLens/Domain/ProductGraph.swift` now exists in source control with `ProductReference` and `ProductGraphIndex`
- stable product identity is now carried across favorites, pantry, routines, memory, follow-up, and `Experiment.relatedProductID`
- `backend-api/app/product_resolver.py` was modularized internally into resolver steps/providers without changing the public app contract
- backend and iOS now share an explicit `resolution_semantics` layer for:
  - `canonical`
  - `provisional`
  - `directional`
  - `provider_backed`
  - `low_confidence`
- that semantic layer is centralized in:
  - `backend-api/app/product_resolution_semantics.py`
  - `WellnessLens/Domain/ProductResolutionSemantics.swift`
- `ProductCandidate` / `ResolvedProduct` now carry `resolution_semantics` as an additive field
- compatibility with `ScanAnalysis` and `AnalysisEnvelope` remains intact
- no new UI was introduced for manual correction or rich confidence display in this slice

## Verification status

The following commands were run successfully after the PRD 4 shared-resolution-semantics slice:

```bash
pytest /Users/aldoolivas/IOS_ngx-silver/backend-api/tests/test_api.py
pytest /Users/aldoolivas/IOS_ngx-silver/agent-service/tests/
xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

Observed result:

- `backend-api` tests: passed
- `agent-service` tests: passed
- iOS build: passed
- iOS tests: passed

## Important boundaries

- Do not rewrite the app around LILA only. Legacy compatibility still matters.
- Keep `ScanVerdict` separate from strategist or coach prompts.
- Keep compatibility with `ScanAnalysis` and `AnalysisEnvelope`.
- Do not rename the project or module from `WellnessLens`.
- Avoid casually overwriting active UI work in:
  - `WellnessLens/DesignSystem/WLComponents.swift`
  - `WellnessLens/DesignSystem/WLTheme.swift`
  - `WellnessLens/Features/Home/HomeView.swift`
  - `WellnessLens/Features/Pantry/PantryView.swift`
  - `WellnessLens/Features/Strategist/StrategistChatView.swift`
  - `WellnessLens/WellnessLensApp.swift`

## What is still not done

- PRD 4 is not fully closed yet:
  - manual correction UX is not implemented
  - richer confidence / provenance UI is not implemented
  - provider expansion beyond the current OFF / USDA path is still pending
- nutrient intelligence engine that replaces demo heuristics
- broader staging validation of the Vertex provider path with real credentials

## Notes about runtime assets

The original asset bundle existed outside the repo and was imported into source control.

Source found during implementation:

- `/Users/aldoolivas/Downloads/lila-agents.zip`

Imported repo paths:

- `agent-service/assets/scan_verdict/LILA_SystemPrompt.md`
- `agent-service/assets/scan_verdict/ScanVerdictSchema.json`
- `agent-service/assets/scan_verdict/LILA_GoldenExamples.md`
- `agent-service/assets/coach_agent/LILA_CoachPrompt.md`
- `agent-service/assets/coach_agent/CoachReplySchema.json`
- `agent-service/assets/coach_agent/LILA_CoachGoldenExamples.md`

One detail worth knowing:

- `LILA_GoldenExamples.md` narrates 6 cases, but only 5 are scan-verdict JSON examples
- the 6th case is a chat-mode example, not a `ScanVerdict` JSON payload

## Recommended next step

The next safest implementation step is to finish the remaining PRD 4 slices before starting PRD 5:

- add manual correction UX on top of the explicit `resolution_semantics` contract
- add richer confidence / provenance presentation without changing `ScanAnalysis` / `AnalysisEnvelope`
- continue provider expansion while keeping deterministic fallback and coach / scan-verdict separation intact

## Minimal context packet for Claude Code

If another coding agent needs to continue work, give it this exact reading order:

1. `docs/PROJECT_STATUS.md`
2. `docs/CLAUDE_HANDOFF_SUMMARY.md`
3. `docs/ADAPTED_PRDS_NEXT.md`
4. `AGENTS.md`

Then point it at:

- `WellnessLens/Domain/ProductGraph.swift`
- `WellnessLens/Domain/ProductResolutionSemantics.swift`
- `WellnessLens/Domain/LILA/LILACompatibility.swift`
- `WellnessLens/Infrastructure/ScanVerdictAgent.swift`
- `WellnessLens/Infrastructure/CoachAgent.swift`
- `WellnessLens/Infrastructure/RemoteCoachAgent.swift`
- `WellnessLens/App/AppModel.swift`
- `backend-api/app/product_resolution_semantics.py`
- `backend-api/app/product_resolver.py`
- `backend-api/app/services.py`
- `agent-service/app/contracts.py`
- `agent-service/app/coach_runtime.py`
- `agent-service/app/service.py`
- `agent-service/app/scan_verdict_runtime.py`
