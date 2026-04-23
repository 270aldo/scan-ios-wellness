# WellnessLens Refactor Plan

This document captures the known architectural debt surfaced during the 2026-04
launch audit and the plan to repay it in follow-up slices. It exists so that
the launch-readiness work (blockers B-1 through B-14 plus security-focused
R-1 through R-7) can ship without being blocked by large refactors, while
still holding the team accountable to close the debt.

## Hot files (LOC at audit close)

| File | Lines | Why it grew | First follow-up slice |
|---|---|---|---|
| `WellnessLens/App/AppModel.swift` | 2,500+ | Single `@Observable` owns every mutable surface: onboarding, scan lifecycle, paywall, coach, HealthKit, history sync | Split via `AppModel+*.swift` extensions (see below) |
| `WellnessLens/Features/Analysis/AnalysisView.swift` | 1,500+ | One SwiftUI view contains every analysis presentation card plus enum-to-copy helpers | Extract remaining subviews into dedicated files |
| `WellnessLens/Infrastructure/PlatformServices.swift` | 990 | `StoredAppState` + `AppDataStore` + `AppServices` factory in one file | Move `StoredAppState` to `Domain/StoredAppState.swift`; move factory to `AppServicesFactory.swift` |
| `WellnessLens/Features/Onboarding/OnboardingView.swift` | 880 | Flow view, plan preview, summary, disclosures all in one file | Split by step |
| `WellnessLens/Features/History/HistoryView.swift` | 1,070 | Every history card lives in the view file | Extract `HistoryWeeklyFallbackCard`, `HistoryPatternCard`, `HistoryWeeklyNarrativeCard` |
| `WellnessLensTests/WellnessLensTests.swift` | 3,900+ | Single test target with every subsystem's suite | Split by feature into `AppModelTests.swift`, `StoreKitTests.swift`, `HealthKitTests.swift`, `SubscriptionReportTests.swift`, `AccountDeletionTests.swift`, `ConsentGatingTests.swift` |

## The `AppModel` split pattern

Proven in this slice with `AppModel+AccountDeletion.swift`: an extension in a
separate file keeps visibility rules simple when the moved methods only touch
`internal` members. The main `AppModel.swift` keeps the storage declarations
and any helper that needs to access `private` members (like `coachReplyTask`).

Next slices — one per file, each fully green against the existing suite
before merging:

1. `AppModel+Subscriptions.swift` — `purchase(_:)`, `purchase(from:)`,
   `restorePurchases()`, `presentUpgradePaywall(_:)`, `dismissPaywall()`,
   `refreshEntitlementSnapshot()`.
2. `AppModel+HealthKit.swift` — `currentBiometricsSnapshotIfAllowed()`,
   HealthKit authorization flows, any write-back helpers.
3. `AppModel+Scan.swift` — `analyzeBarcode`, `analyzeLabel`, scan event
   composition, `reconcileScanVerdictsIfNeeded`, `generateScanVerdict`,
   `generateCoachReply`.
4. `AppModel+Onboarding.swift` — `startOnboardingIfNeeded`,
   `updateOnboardingDraft`, `completeOnboarding`, migration helpers.
5. `AppModel+HistorySync.swift` — `syncHistoryIfNeeded`, `bootstrap`
   orchestration excluding unrelated work.

Each step trims ~200-400 lines from `AppModel.swift`. None changes behavior;
each must leave all 106+ tests green and must not introduce new `fileprivate`
leaks (prefer `internal` over widening to `public`).

## Acceptance criteria for the refactor slices

For any slice that moves code:

1. `xcodebuild -scheme WellnessLens build` passes.
2. `xcodebuild -scheme WellnessLens test` runs the full suite with zero
   failures and zero skips.
3. The diff is **pure movement**: no behavior change, no logic change, no
   new dependencies. `git diff --stat` shows identical net LOC across the
   moved files (allow ±10 for doc comments and `// Moved to …` anchors).
4. No `private` widening that is not justified by the move itself; when a
   member must become `internal`, add an inline comment explaining why and
   mention the extension file that now consumes it.
5. `WellnessLensTests/WellnessLensTests.swift` stays whole in this slice but
   is split in a dedicated later slice so moved code does not also shuffle
   its tests in the same PR.

## Non-goals

- Replacing `@Observable` with TCA or ReSwift. The current model works.
- Introducing a DI container. `AppServices` is already the single seam.
- Rewriting the deterministic scoring engine.
- Changing any user-visible copy (Spanish or English) as part of the move.

## Risk notes

- `resetToFreshState` touches `coachReplyTask?.cancel()` and reads from
  several `private` properties. It stays in `AppModel.swift` across all
  splits. Extensions call it as an `internal` helper.
- `StoreKitSubscriptionController` already escapes `AppModel` and lives in
  `BackendServices.swift`. No refactor should move purchase mechanics back
  into `AppModel`.
- The paywall sheet (`PhaseTwoPaywallSheet`) reads
  `model.services.configuration` and `model.services.subscription` directly.
  Any split that renames `services` must update the paywall too.

## Tracking

Open follow-up issues with titles of the form
`refactor: AppModel+Subscriptions extraction` and reference this document so
the rationale does not have to be re-derived each time.
