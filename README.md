# WellnessLens

WellnessLens is an iPhone-first SwiftUI prototype for an inside-out women's wellness scanner. The app ships with a deterministic scoring engine, local OCR fallback, sample catalog data, history, weekly insights, check-ins, demo subscription states, and App Intents hooks for opening key destinations.

## What is implemented

- SwiftUI app shell with onboarding, tabs, and a premium tone.
- Scanner feature with live barcode camera sheet, manual barcode entry, manual ingredient text, and photo OCR fallback.
- Guided demo packs with one-tap food, supplement, and skincare/personal care scenarios.
- Deterministic scoring across five lenses:
  - Glow & Skin
  - Hormone Balance
  - Gut Comfort
  - Energy & Mood
  - Body Composition & Strength
- Unified history with favorites and product comparison.
- Check-ins and simple weekly insight generation.
- Demo-ready subscription states and App Intents routing.
- Clear integration seams for Firebase, cloud scan resolution, and Gemini-backed label parsing.
- Runtime config that can switch between demo mode and cloud mode through `Info.plist`.
- StoreKit 2 live controller plus Firebase-ready bootstrap, identity, and App Check hooks.
- Editable personal context from Profile without replaying onboarding.

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
xcodebuild -project WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' build
```

4. Run tests:

```bash
xcodebuild -project WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Runtime configuration

The app reads these keys from `Info.plist`, which is generated from [`project.yml`](/Users/aldoolivas/IOS_ngx-silver/project.yml):

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
4. Set `WLBackendBaseURL` to the API root for your Functions/API gateway.

The project is already configured to resolve these Firebase packages through XcodeGen:

- `FirebaseCore`
- `FirebaseAuth`
- `FirebaseFirestore`
- `FirebaseFunctions`
- `FirebaseStorage`
- `FirebaseAppCheck`

## Architecture notes

- `WellnessLens/Domain/WellnessCore.swift` contains the public domain model, sample catalog, deterministic analysis engine, and weekly insight engine.
- `WellnessLens/Infrastructure/PlatformServices.swift` contains scan resolution services, local persistence, OCR, camera scanning, and App Intents glue.
- `WellnessLens/Infrastructure/BackendServices.swift` contains backend contracts, cloud client logic, identity providers, and StoreKit subscription plumbing.
- `WellnessLens/Infrastructure/FirebaseBootstrap.swift` contains optional Firebase configuration and App Check bootstrap.
- `WellnessLens/App/AppModel.swift` owns app state and coordinates analysis, history, check-ins, subscriptions, and deep links.
- `WellnessLens/Features/*` contains feature-facing SwiftUI surfaces.

## Next production steps

- Validate the guided demo loop on simulator and device before enabling cloud mode.
- Implement backend endpoints for `analyzeProduct`, `resolveScan`, `saveCheckIn`, and `getWeeklyInsights`.
- Replace the sample catalog with normalized products from Firestore or a catalog service.
- Add real StoreKit product identifiers and attach entitlement gating to premium actions.
- Move Gemini parsing behind Remote Config and App Check-protected endpoints.
