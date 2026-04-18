# Project Status

Last updated: 2026-04-17

## Executive summary

This repo is already past the "prototype only" phase.

The current state is:

- legacy scan pipeline still works
- LILA v2 domain exists behind an incremental bridge
- `ScanVerdict` is now a first-class runtime concept
- PRD 1 is implemented in the iOS app
- PRD 2 is implemented in `agent-service`
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

## Verification status

The following commands were run successfully after the PRD 2 implementation:

```bash
pytest /Users/aldoolivas/IOS_ngx-silver/agent-service/tests/test_agent_api.py
xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

Observed result:

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

- PRD 3: separate coach agent contract and runtime
- real product graph and resolution layer
- nutrient intelligence engine that replaces demo heuristics
- remote iOS hookup to live scan verdict provider behavior
- broader staging validation of the Vertex provider path with real credentials

## Notes about runtime assets

The original asset bundle existed outside the repo and was imported into source control.

Source found during implementation:

- `/Users/aldoolivas/Downloads/lila-agents.zip`

Imported repo paths:

- `agent-service/assets/scan_verdict/LILA_SystemPrompt.md`
- `agent-service/assets/scan_verdict/ScanVerdictSchema.json`
- `agent-service/assets/scan_verdict/LILA_GoldenExamples.md`

One detail worth knowing:

- `LILA_GoldenExamples.md` narrates 6 cases, but only 5 are scan-verdict JSON examples
- the 6th case is a chat-mode example, not a `ScanVerdict` JSON payload

## Recommended next step

The next safest implementation step is PRD 3:

- formalize a separate coach agent
- keep it consuming `ScanVerdict`, check-ins, and memory
- do not block scan execution on coach availability

## Minimal context packet for Claude Code

If another coding agent needs to continue work, give it this exact reading order:

1. `docs/PROJECT_STATUS.md`
2. `docs/CLAUDE_HANDOFF_SUMMARY.md`
3. `docs/ADAPTED_PRDS_NEXT.md`
4. `AGENTS.md`

Then point it at:

- `WellnessLens/Domain/LILA/LILACompatibility.swift`
- `WellnessLens/Infrastructure/ScanVerdictAgent.swift`
- `WellnessLens/App/AppModel.swift`
- `agent-service/app/contracts.py`
- `agent-service/app/service.py`
- `agent-service/app/scan_verdict_runtime.py`
