# Architecture Decisions

## ADR-001: Deterministic-first pipeline
- Status: accepted
- Decision: keep `AnalysisEngine` as the primary scoring engine and use enrichment layers on top of it.
- Why: preserves fast fallback behavior, low latency, and auditable reasoning.

## ADR-002: Client-first phase 1
- Status: accepted
- Decision: implement phase 1 primarily in the iOS client with local orchestration and backend-ready contracts.
- Why: the current workspace has no backend service implementation. Shipping local scaffolding avoids blocking phase 1.

## ADR-003: Dual-write migration strategy
- Status: accepted
- Decision: keep existing `ScanAnalysis`, `ScanRecord`, and `CheckInEntry` flows working while introducing `AnalysisEnvelope`, `ScanEvent`, and `CheckInEvent`.
- Why: reduces blast radius and keeps the current UI functional during migration.

## ADR-004: Single visible assistant voice
- Status: accepted
- Decision: expose one assistant experience in the UI and keep internal specialization behind the orchestrator boundary.
- Why: matches the PRD and avoids user-facing agent fragmentation.

## ADR-005: Wellness-safe language
- Status: accepted
- Decision: route all structured analysis through a `SafetyClaimsGuard`.
- Why: centralizes wellness framing and reduces App Review and compliance drift.

## ADR-006: Guest-first identity
- Status: accepted
- Decision: keep anonymous/local identity as the default for phase 1 and avoid embedding remote AI credentials in the client.
- Why: supports low-friction use and keeps secrets server-side only.

## ADR-007: Entitlements gate capabilities, not the deterministic core
- Status: accepted
- Decision: map premium access through `WellnessEntitlement` and `AccessPolicy`, while keeping the deterministic scan engine available to every tier.
- Why: phase 2 should monetize enrichment layers without breaking the fast fallback or Phase 1 core flows.

## ADR-008: Phase 2 remains local-first
- Status: accepted
- Decision: implement `PatternAgent`, weekly narrative v2, pantry seeding, and contextual paywalls primarily in the iOS client, with backend contracts remaining optional.
- Why: the repo still does not ship a production backend service, and local deterministic enrichment keeps the rollout incremental, reversible, and testable.

## ADR-009: Home content and Home hierarchy are separate contracts
- Status: accepted
- Decision: keep `DailyHomePayload` as the content payload for Home, and add `DailyHomePayloadV2` as a separate hierarchy contract that decides hero emphasis, primary module, visible secondary modules, deferred modules, and suppressed redundant modules.
- Why: the previous Home implementation forced the SwiftUI layer to invent hierarchy from flat content atoms. Separating content from placement lets the backend and client share the same prioritization language without duplicating all copy fields or breaking the existing fallback payload.
