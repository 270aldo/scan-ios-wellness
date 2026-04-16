# NGX Scan -> WellnessLens Implementation Plan

## Goal
Transform the current product from an occasional scanner into a daily visual nutrition assistant for women's wellness without replacing the deterministic core.

## Phase 1
- Expand onboarding into a stronger personalization contract.
- Ship a Daily Brief on Home.
- Add Meal Snapshot as a first-class scan mode.
- Introduce structured analysis output and event persistence.
- Add post-meal feedback tied to scans.
- Add favorites and more useful history.
- Add a local root orchestrator and safety claims guard.

## Phase 2
- Add PatternAgent over scan and check-in history.
- Upgrade weekly insight into narrative guidance.
- Add Menu Scanner and Pantry MVP.
- Add contextual paywalls and entitlements.

## Phase 3
- Harden security and compliance.
- Add account deletion and data export.
- Add privacy manifest and App Review/demo mode.
- Add App Check enforcement and evaluation coverage.

## Non-Negotiables
- Preserve the deterministic engine as the fast, auditable fallback.
- Keep one visible assistant voice. Internal agents remain invisible.
- Keep outputs structured, schema-friendly, and reversible.
- Avoid medical claims, diagnoses, or treatment framing.
- Favor incremental, documented, backward-compatible changes.

## Phase 1 Deliverables in This Repo
- `AnalysisEnvelope`, `ScanEvent`, `CheckInEvent`, and related schema models.
- Local event persistence with migration from the existing state file.
- Root orchestrator and safety guard scaffolding.
- Onboarding v2 and Daily Brief UI.
- Meal Snapshot input mode.
- Feedback loop, favorites, and history improvements.
- Updated backend contracts for the new structured payloads.
