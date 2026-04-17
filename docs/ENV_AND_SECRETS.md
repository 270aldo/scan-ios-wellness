# Environment And Secrets

## Existing Runtime Keys
- `WLBackendBaseURL`
- `WLFirebaseEnabled`
- `WLStoreKitEnabled`
- `WLUseDemoData`
- `WLUseAppCheckDebugProvider`
- `WLPlusProductID`
- `WLProProductID`

## Local Files
- `WellnessLens/Support/GoogleService-Info.plist`

## Phase 1 Assumptions
- Demo/local mode remains supported by default.
- StoreKit 2 stays as the subscription path when enabled.
- No AI or vision provider secret is stored in the iOS client.

## Production Secrets Needed Later
- Firebase project configuration
- App Check / App Attest configuration
- App Store Connect products for Plus and Pro
- APNs credentials for Daily Brief notifications
- Backend-managed AI / vision provider keys
- See `docs/PRODUCTION_SETUP_CHECKLIST.md` for the environment-by-environment rollout checklist.

## Rules
- Never hardcode secrets in source.
- Never ship App Check debug provider in production.
- Keep all third-party AI credentials server-side.
- Document any new environment key here before using it.
