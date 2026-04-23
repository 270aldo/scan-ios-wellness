# SwiftUI Redesign Spec v1

Last updated: 2026-04-17

## Purpose

This document turns the current UX audit into an implementation-oriented redesign spec for the existing `WellnessLens` iOS app.

The goal is not a rewrite.

The goal is to sharpen the product so it feels like a native, premium, fitness-luxury personal wellness agent for women roughly 22-55, while preserving:

- the current SwiftUI foundation
- the current color palette
- the existing `ScanAnalysis` and `AnalysisEnvelope` compatibility path
- the newer LILA `ScanVerdict` model
- the current feature surfaces that already work

This spec is intentionally reversible.
Any future implementation should be phased, diff-friendly, and easy to back out if a direction does not hold up.

## Product Positioning

`WellnessLens` should not feel like:

- a calorie tracker
- a generic ingredient scanner
- a chat app with wellness flavor
- a dashboard of loosely related features

`WellnessLens` should feel like:

- a personal wellness intelligence layer
- a product decision engine for food, supplements, and beauty-adjacent choices
- a context-aware agent that knows the user and explains tradeoffs clearly
- a premium native iOS product with calm confidence

Core promise:

> WellnessLens reads what the user scans through her goals, sensitivities, body context, and routine, then returns a concrete recommendation with consequences, benefits, and next steps.

## Current Strengths

The repo already has strong product ingredients:

- multi-input scan system: barcode, label photo, meal snapshot, menu scan
- user calibration through onboarding
- visible memory, routine, pantry, and strategist layers
- LILA `ScanVerdict` model with fit, watchouts, better swap, follow-up prompt, and lens scores
- a premium visual direction already present in `WLTheme` and `WLComponents`
- a good split between deterministic fallback and richer agent-backed output

The redesign should amplify these strengths, not replace them.

## Main UX Problems

### 1. The app reads as a suite of features, not one intelligence system

The user can scan, check in, open pantry, view history, and ask strategist, but the product voice is still distributed across surfaces instead of feeling unified.

### 2. Too many cards have similar visual weight

Important decisions and secondary context often sit too close together in emphasis.
This weakens the feeling of clarity and certainty.

### 3. The personalized value is often implicit instead of explicit

The domain clearly supports goals like skin, energy, digestion, hormone support, and strength.
The UI does not always say early enough:

- why this matters for you
- what this helps
- what this hurts
- what to do next

### 4. The app sometimes explains capability before outcome

This is especially noticeable in scan-related surfaces.
The product should lead with consequence, not input method.

### 5. The visual language is premium, but not yet fully native-modern

The current direction is attractive, but sometimes closer to a custom editorial card stack than to a refined modern iOS surface hierarchy.

## Visual Direction

### Design keywords

- fitness luxury
- soft precision
- premium clarity
- feminine without fragility
- high trust
- native first

### Palette

Keep the existing palette in `WLTheme`.
Do not rebrand colors.

Use the current colors with more discipline:

- background stays soft, airy, luminous
- content cards become quieter and cleaner
- rose/lilac act as intentional highlights, not constant fill colors
- success/caution carry decision meaning more clearly

### Typography

Keep the rounded system feel.
Strengthen hierarchy through usage, not through new fonts.

Target hierarchy:

- hero: one statement only
- decision headline: strongest content text
- supporting explanation: quieter body copy
- metadata: pills, badges, confidence, source

### Motion

Use fewer but more meaningful transitions:

- hero state changes
- scan-to-analysis continuity
- expanding contextual modules
- strategist composer and transcript anchoring

Avoid decorative animation that does not carry hierarchy.

## Liquid Glass Guidance

The repo already experiments with Liquid Glass in the design system.
That is useful, but future implementation needs tighter rules.

Apple guidance is clear:

- Liquid Glass belongs primarily to the functional layer
- use it sparingly
- avoid flooding content surfaces with custom glass treatments

Recommended usage in this app:

- tab bar
- navigation and toolbar affordances
- strategist composer
- primary floating or high-value controls
- selected pills and contextual status chips
- compact transient overlays

Avoid using Liquid Glass as the default material for long reading surfaces.
Most content cards should remain standard material or quiet custom surfaces.

## Screen-by-Screen Spec

## 1. Home

### Current role

Home acts as a daily dashboard with multiple modules and a reasonable hero.

### Problem

It still feels like a collection of modules instead of the command center of a personal agent.

### New role

Home becomes the agent console.

It should answer three questions immediately:

1. What matters most today?
2. What is the latest meaningful decision?
3. What should I do next?

### Proposed hierarchy

1. Daily hero
2. Latest verdict
3. Primary next action
4. Deeper context modules

### New Home hero

The hero should contain:

- one short daily focus line
- one contextual interpretation of body signal or current goal
- one primary CTA
- one secondary CTA

It should not try to summarize the whole app.

### Latest verdict block

Move this to a more dominant role directly below hero when available.

It should show:

- product name
- fit title
- one-line headline
- one-line personal reason
- quick CTA to review or rescan

### Secondary modules

Keep these, but reduce visual competition:

- daily brief
- signals
- pantry
- strategist note
- goals
- sample reads

Only one module should feel primary at a time.

### Desired emotional tone

The user should feel:

- guided
- understood
- not overloaded

## 2. Scan

### Current role

Scan is already structurally strong and supports multiple inputs.

### Problem

The page still frames the experience too much around capture method rather than decision outcome.

### New role

Scan becomes the product intelligence entry point.

### Hero direction

The hero should promise outcome, for example:

- scan something and see how it affects skin, energy, digestion, and strength
- get a clear read, not a generic ingredient dump

### Proposed structure

1. Hero outcome statement
2. Primary scan actions
3. Secondary input methods
4. What you will get
5. Sample reads as proof

### New supporting section: What you will get

Show a small preview card with:

- fit verdict
- lens impact
- watchouts
- better swap

This helps the user understand why scanning matters before scanning.

### Interaction priority

Keep capture flows as they are architecturally.
Only change framing and hierarchy first.

## 3. Analysis

### Current role

This is already the strongest candidate for the product centerpiece.

### Problem

It contains the right information, but the screen can still feel like a sophisticated result page rather than the core decision engine of the app.

### New role

Analysis becomes the signature product moment.

This is where the app proves:

- it knows the user
- it can interpret a product
- it can explain consequence
- it can suggest action

### Proposed hierarchy

1. Decision hero
2. Impact on your goals
3. Why it landed here
4. Watchouts
5. Better swap
6. What to do next

### Decision hero

Must show:

- product name
- fit verdict
- confidence
- a single strong headline
- one personal consequence summary

This should be visually dominant.

### Impact on your goals

The five lenses are a major differentiator and should look premium and personal, not merely analytical.

They should answer:

- where this product helps
- where it weakens the fit
- which lens matters most right now

### Why it landed here

Keep to 2-3 strongest reasons.
The screen should feel decisive, not defensive.

### Watchouts

Limit to max 2 primary watchouts in the first surface.
Additional detail can live below or behind expansion.

### Better swap

Make the swap feel like a premium recommendation, not an afterthought.

### What to do next

Expected actions:

- keep in routine
- save to pantry
- swap instead
- ask strategist
- track effect later

### Desired emotional tone

The user should feel:

- seen
- clear on tradeoffs
- able to act now

## 4. Strategist

### Current role

A context-rich shared chat surface.

### Problem

It still reads as a separate feature rather than the living voice of the whole system.

### New role

Strategist becomes the conversational extension of every major decision.

### Proposed direction

- keep the current native chat model
- strengthen top context ribbon
- make the composer feel more premium and more integrated
- keep visual noise low

### Context ribbon

The ribbon at the top should explain why strategist is qualified to answer right now:

- linked read
- weekly pattern
- latest body signal
- active goal

### Voice

The strategist should always sound like the same intelligence that produced the scan verdict.
It should not feel like another product mode.

### Composer

The composer can use more functional glass emphasis because it is an active interaction layer.

## 5. History

### Current role

History already includes more than archival scans.

### Problem

The page still leans archival in perception.

### New role

History becomes working memory.

### Rename recommendation

Internally the tab can remain `History`.
The screen language should increasingly talk about `Memory`, `Patterns`, `Decisions`, and `Signals`.

### Proposed hierarchy

1. Working memory overview
2. Weekly pattern or narrative
3. Recent decisions
4. Body signals
5. Timeline
6. Archived reads

### Primary product idea

This page should answer:

- what the app is learning
- what keeps repeating
- what decisions are becoming reusable

## 6. Check-In

### Current role

A strong, useful input surface tied to body signals.

### Problem

It still feels somewhat like a structured form.

### New role

Check-In becomes the body-feedback loop that sharpens the agent.

### Proposed direction

- keep it short
- make it feel intimate, premium, and quick
- show how it improves future reads

### Hierarchy

1. current body state
2. core signals
3. optional note
4. linked follow-up from latest scan
5. save and strategist actions

### Special note

Skin should remain a first-class signal when relevant.
This is a differentiator for the target audience.

## 7. Profile

### Current role

Mostly settings and profile summary.

### Problem

It feels more like configuration than identity.

### New role

Profile becomes `Your Lens`.

### Primary purpose

Show the user how the app understands her.

### Proposed hierarchy

1. identity and optimization summary
2. goals and sensitivities
3. guidance style and memory
4. connected health context
5. membership and advanced surfaces

### Desired effect

The user should feel:

- this app has a model of me
- I can tune it
- the rest of the app is derived from this

## 8. Pantry

### Current role

Pantry already works as saved defaults and anchors.

### Problem

The value is smart, but the page can feel a bit utilitarian.

### New role

Pantry becomes the curated library of protected defaults.

### Proposed direction

- frame anchors as premium repeat choices
- reinforce their role in reducing bad decisions on noisy days
- keep the surface sparse and high trust

### Hierarchy

1. pantry hero
2. next pantry move
3. protected anchors
4. actions to promote, review, or remove

## 9. Onboarding

### Current role

The logic is good and richer than a typical onboarding.

### Problem

It can still read as a calibration form instead of a luxury setup ritual.

### New role

Onboarding becomes the first act of personalization.

### Proposed direction

- keep the information architecture largely intact
- improve visual pacing and perceived elegance
- make the user feel the app is building her lens, not collecting fields

### Summary screen

This should feel aspirational and precise:

- what the app will optimize
- what it will watch
- what the first-week loop looks like

## Design System Recommendations

## What to keep

- `WLPalette`
- `WLSpacing`
- rounded typography direction
- hero/content surface split
- custom pills and badges
- adaptive Liquid Glass support for newer iOS

## What to change

### 1. Reduce equal-weight card stacking

Introduce clearer levels:

- hero surface
- decision surface
- quiet content surface
- utility surface

### 2. Refine component roles

Some current components are visually close together.
They should separate more by role than by minor styling differences.

### 3. Tighten glass usage

Functional glass only.
Do not turn every premium surface into glass.

### 4. Clarify semantic tones

Use tone to communicate:

- decision confidence
- fit strength
- caution
- actionability

Not only decoration.

## Native SwiftUI Recommendations

### Keep

- `NavigationStack`
- `TabView`
- sheets for modal detail
- existing custom components where they align with system patterns

### Prefer

- system bar behavior over heavy UIKit appearance overrides where possible
- native toolbars and bar item grouping
- native spacing and safe area behavior
- content-under-bar and tab bar depth where it supports Liquid Glass behavior

### Review later

`WellnessLensApp.swift` currently customizes navigation and tab bar appearance.
This should be audited before any deeper visual refresh, because modern iOS system bars already carry part of the desired look.

## Copy Direction

The product voice should become more decisive and more personal.

### Prefer

- “This is a good fit for your skin and energy goals.”
- “Better as an occasional choice.”
- “This looks supportive for digestion, but weaker for clear skin.”
- “Stronger post-workout option.”
- “Worth keeping close.”

### Avoid

- generic wellness filler
- overexplaining technical inputs
- long disclaimers in primary surfaces
- soft language when the product can be clear

## Implementation Strategy

This redesign should be implemented in phases so every step is reversible.

## Phase 1

Design system refinement only.

Scope:

- introduce clearer surface levels
- tighten semantic styling
- avoid broad behavioral changes

Files likely involved:

- `WellnessLens/WellnessLens/DesignSystem/WLTheme.swift`
- `WellnessLens/WellnessLens/DesignSystem/WLComponents.swift`

## Phase 2

Analysis redesign.

Why first:

- highest product leverage
- strongest differentiator
- easiest place to validate the direction

File:

- `WellnessLens/WellnessLens/Features/Analysis/AnalysisView.swift`

## Phase 3

Home redesign.

Why next:

- makes the whole product feel unified
- raises perceived intelligence immediately

File:

- `WellnessLens/WellnessLens/Features/Home/HomeView.swift`

## Phase 4

Scan reframing.

File:

- `WellnessLens/WellnessLens/Features/Scan/ScanView.swift`

## Phase 5

Strategist, Profile, History, Pantry, Check-In, Onboarding polish.

Files:

- `WellnessLens/WellnessLens/Features/Strategist/StrategistChatView.swift`
- `WellnessLens/WellnessLens/Features/Profile/ProfileView.swift`
- `WellnessLens/WellnessLens/Features/History/HistoryView.swift`
- `WellnessLens/WellnessLens/Features/Pantry/PantryView.swift`
- `WellnessLens/WellnessLens/Features/CheckIn/CheckInView.swift`
- `WellnessLens/WellnessLens/Features/Onboarding/OnboardingView.swift`

## Reversibility Rules

To keep this safe:

- avoid destructive rewrites
- prefer new subviews over replacing large bodies inline
- isolate styling changes in the design system first
- keep product copy centralized where possible
- validate each phase independently
- avoid touching multiple active UI files in one uncontrolled pass

Implementation should preserve the ability to revert any phase independently.

## Success Criteria

The redesign is working if:

- the app feels like one intelligence system, not separate tools
- `Analysis` feels like the signature product moment
- `Home` feels like a personal agent console
- `Scan` sells decision quality, not just capture methods
- `History` feels like memory, not archive
- `Profile` feels like a living user model
- the visual language feels more native and more premium without changing brand colors

## Recommended First Build Sequence

1. Design system surface hierarchy
2. Analysis screen redesign
3. Home screen redesign

That sequence gives the highest signal with the lowest architectural risk.
