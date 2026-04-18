# AGENTS.md

This file is the root handoff for coding agents working in `/Users/aldoolivas/IOS_ngx-silver`.

## Read first

Before changing code, read these files in this order:

1. `docs/PROJECT_STATUS.md`
2. `docs/CLAUDE_HANDOFF_SUMMARY.md`
3. `docs/ADAPTED_PRDS_NEXT.md`

## Current architecture

- The repo already has a working legacy scan pipeline built around `ScanAnalysis` and `AnalysisEnvelope`.
- LILA v2 was added incrementally under `WellnessLens/Domain/LILA/`.
- The bridge layer lives in `WellnessLens/Domain/LILA/LILACompatibility.swift`.
- `ScanVerdictAgent` is intentionally separate from the strategist or coach path.
- `agent-service` is the dedicated backend service for structured strategist replies and scan verdicts.
- `backend-api` is the app-facing backend for home, history, sync, and scan orchestration payloads.

## Current milestone state

- Foundation-first is implemented.
- PRD 1 "Scan Verdict Surface" is implemented on the real repo.
- PRD 2 "Runtime Prompt + Schema Real" is implemented in `agent-service`.
- PRD 3 and later are not implemented yet.

## Hard guardrails

- Do not start from scratch.
- Do not rename the project or module. Keep `WellnessLens`.
- Keep compatibility with `ScanAnalysis` and `AnalysisEnvelope`.
- Keep the scan verdict prompt separate from the coach prompt.
- Do not do destructive rewrites.
- Expect a dirty worktree and preserve user changes.

## Files with active UI or UX work

Do not casually overwrite these files:

- `WellnessLens/DesignSystem/WLComponents.swift`
- `WellnessLens/DesignSystem/WLTheme.swift`
- `WellnessLens/Features/Home/HomeView.swift`
- `WellnessLens/Features/Pantry/PantryView.swift`
- `WellnessLens/Features/Strategist/StrategistChatView.swift`
- `WellnessLens/WellnessLensApp.swift`

If a task requires touching them, make the smallest viable change and preserve the current visual direction.

## Key paths

- LILA domain: `WellnessLens/Domain/LILA/`
- Compatibility bridge: `WellnessLens/Domain/LILA/LILACompatibility.swift`
- Scan verdict agent: `WellnessLens/Infrastructure/ScanVerdictAgent.swift`
- HealthKit service: `WellnessLens/Infrastructure/HealthKitService.swift`
- App state owner: `WellnessLens/App/AppModel.swift`
- Agent runtime assets: `agent-service/assets/scan_verdict/`
- Agent runtime loader: `agent-service/app/scan_verdict_runtime.py`
- Agent contracts: `agent-service/app/contracts.py`
- Agent service: `agent-service/app/service.py`

## Runtime assets already in repo

The scan verdict runtime now uses real repo-stored assets:

- `agent-service/assets/scan_verdict/LILA_SystemPrompt.md`
- `agent-service/assets/scan_verdict/ScanVerdictSchema.json`
- `agent-service/assets/scan_verdict/LILA_GoldenExamples.md`

These are validated at runtime. Do not replace them with invented content.

## Verification commands

Run these before calling work complete:

```bash
xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
pytest /Users/aldoolivas/IOS_ngx-silver/agent-service/tests/test_agent_api.py
```

## Working assumptions

- `artifacts/ui-audit/` contains audit screenshots and working collateral. Treat it as reference material, not product code.
- The safest next implementation track is PRD 3: a separate coach agent that consumes `ScanVerdict` and memory without blocking scans.
- If provider-backed scan verdict behavior is being changed, preserve deterministic local fallback.
