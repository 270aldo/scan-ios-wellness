# WellnessLens Production Setup Checklist

## Purpose
This checklist turns the current repo scaffold into a real `dev -> staging -> prod` rollout path for WellnessLens.

## Current Repo Baseline
- Bundle ID in repo today: `com.aldoolivas.WellnessLens`
- Product IDs in repo today:
  - `com.aldoolivas.wellnesslens.plus`
  - `com.aldoolivas.wellnesslens.pro`
- Runtime defaults in repo today:
  - `WLBackendBaseURL=""`
  - `WLFirebaseEnabled=false`
  - `WLStoreKitEnabled=false`
  - `WLUseDemoData=true`
  - `WLUseAppCheckDebugProvider=false`
- Backend, agent service, Terraform, client config fetch, history sync, and backend diagnostics are already scaffolded in this repo.

## Environment Matrix
Use separate projects and app registrations from day one.

| Environment | GCP Project ID | Firebase Project | iOS Bundle ID | Cloud Run URL | Status |
| --- | --- | --- | --- | --- | --- |
| dev | `wellnesslens-dev` | `wellnesslens-dev` | `com.aldoolivas.WellnessLens.dev` | pending | pending |
| staging | `wellnesslens-staging` | `wellnesslens-staging` | `com.aldoolivas.WellnessLens.staging` | pending | pending |
| prod | `wellnesslens-prod` | `wellnesslens-prod` | `com.aldoolivas.WellnessLens` | pending | pending |

## Accounts To Create Or Confirm
- Google Cloud organization or billing account with permission to create projects.
- Firebase access on all three projects.
- Apple Developer Program team.
- App Store Connect app record for WellnessLens.
- DNS/domain ownership for API and app endpoints.
- GitHub access for CI secrets and deployments.

## Inputs Needed Before Deployment
- Final `project_id` values for `dev`, `staging`, `prod`.
- Final bundle IDs for each environment.
- Deployment region. Recommended: `us-central1`.
- Custom domains, if any.
- Support email, privacy policy URL, terms URL.
- Confirmation whether push notifications ship in v1.
- Confirmation whether Vertex launches in `staging` only first.

## Firebase Setup
Complete these steps for `dev`, `staging`, and `prod`.

1. Create or select the GCP project.
2. Add Firebase to the project.
3. Register the iOS app with the exact bundle ID for that environment.
4. Download `GoogleService-Info.plist`.
5. Enable Firebase Authentication and turn on Anonymous sign-in.
6. Create Firestore in Native mode.
7. Enable App Check and register the app with App Attest.
8. If using Remote Config, enable Google Analytics for the project.
9. If using FCM, upload the APNs auth key in Firebase Cloud Messaging settings.

## GCP Services To Enable
These are already reflected in Terraform and should be enabled in each project.

- Artifact Registry
- Cloud Build
- Cloud Run
- Firestore API
- Firebase Management API
- IAM API
- Logging
- Monitoring
- Secret Manager
- Cloud Storage
- Vertex AI

## Service Accounts
Create or let Terraform create these service accounts in each environment.

- `wl-backend-api-<env>`
- `wl-agent-service-<env>`
- `wl-ci-deployer-<env>`

## Secrets Inventory
Store these in Secret Manager. Never put them in source control.

| Secret | Required | Notes |
| --- | --- | --- |
| `firebase-admin-json` | optional | Prefer IAM in Cloud Run. Use only if local admin tooling needs it. |
| `app-store-connect` | yes for subscription validation | Store Issuer ID, Key ID, private key, and app identifiers. |
| `vertex-runtime` | maybe | Only needed if the agent adapter needs extra runtime config beyond IAM. |
| `apns-auth-key` | yes if shipping push | Store the `.p8`, Key ID, Team ID, bundle IDs. |
| `backend-signing-key` | recommended | For signed internal service-to-service callbacks if added later. |

## Apple / App Store Setup
- Confirm the production bundle ID that matches the App Store app.
- Create matching app IDs for `dev` and `staging` if you want installable parallel builds.
- Enable App Attest capability.
- **Enable HealthKit capability** on the production `com.aldoolivas.WellnessLens` App ID (and on the dev/staging App IDs when they exist). The repo already ships the `com.apple.developer.healthkit` entitlement in `WellnessLens/Support/WellnessLens.entitlements`, but Apple requires the matching capability on the App ID and a regenerated provisioning profile before any signed build will pass `HKHealthStore.isHealthDataAvailable` checks.
  - Clinical Records are not read, so the narrower `com.apple.developer.healthkit.access` array is intentionally omitted.
- Create App Store Connect subscriptions for:
  - `com.aldoolivas.wellnesslens.plus`
  - `com.aldoolivas.wellnesslens.pro`
- Create an App Store Connect API key for server-side subscription work.
- Create one APNs auth key for push if notifications ship in v1.

## iOS Repo Work Still Required
- Add environment-specific `GoogleService-Info.plist` files.
- Add `.xcconfig` files for `dev`, `staging`, and `prod`.
- Add an `.entitlements` file with the App Attest capability for non-debug builds.
- Wire scheme-specific values for:
  - `WLBackendBaseURL`
  - `WLFirebaseEnabled`
  - `WLStoreKitEnabled`
  - `WLUseDemoData`
  - `WLUseAppCheckDebugProvider`
- Keep `WLUseAppCheckDebugProvider=false` outside local development.

## Backend Deployment Checklist
1. Create Artifact Registry repository.
2. Build and push `backend-api` image.
3. Build and push `agent-service` image.
4. Apply Terraform for the target environment.
5. Attach Cloud Run services to their service accounts.
6. Inject environment variables and secrets.
7. Verify `/healthz`, `/v1/client-config`, `/v1/home`, and `/v1/scan/analyze`.
8. Turn on Firestore-backed persistence in staging.
9. Turn on Firebase Auth validation in staging.
10. Deploy Firestore security rules from `firestore.rules` **before** opening traffic. See "Firestore Security Rules" below.
11. Turn on App Check enforcement only after metrics look clean.

## Firestore Security Rules
- Source of truth: `firestore.rules` at the repo root.
- Posture: deny-by-default; only the Firebase Admin SDK (used by `backend-api`) can write; authenticated clients can read only `wellness_users/{userId}` where `userId == request.auth.uid`.
- Deploy via Firebase CLI from the repo root:
  ```bash
  firebase use <gcp-project-id>
  firebase deploy --only firestore:rules
  ```
- Full-fidelity local validation needs Java + the Firebase emulator:
  ```bash
  firebase emulators:exec --only firestore --project demo-wellnesslens 'echo OK'
  ```
  The CI/CD pipeline should run this on every PR that touches `firestore.rules`.
- Every promotion to staging or prod must re-deploy rules if the file changed; Terraform does not manage rules (by design — rules should evolve with app code, not infra).

## Vertex / Agent Launch Checklist
- Start with the deterministic local provider still enabled in the app.
- Keep the cloud agent behind a feature flag.
- Configure:
  - `WELLNESSLENS_AGENT_PROVIDER=vertex`
  - `WELLNESSLENS_AGENT_VERTEX_PROJECT=<project>`
  - `WELLNESSLENS_AGENT_VERTEX_LOCATION=us-central1`
  - `WELLNESSLENS_AGENT_VERTEX_MODEL=gemini-2.5-pro`
- Validate structured strategist replies in staging before exposing them to all premium users.

## CI/CD Checklist
- Add GitHub Actions secrets for deploy.
- Enable build on push for backend and agent services.
- Run backend tests on every merge.
- Run iOS tests before staging promotion.
- Gate `prod` deploy behind manual approval.

## Smoke Tests Required Before TestFlight
- Cold start with Firebase enabled.
- Anonymous auth succeeds.
- App Check token is attached to backend calls.
- Structured scan succeeds remotely.
- Structured scan falls back locally when backend is unavailable.
- `v1/home` succeeds remotely.
- `v1/history/sync` reconciles local and remote records.
- Subscription purchase and restore work in sandbox.
- Backend diagnostics screen reflects live status accurately.
- HealthKit authorization prompt appears on first scan when the user opts in (requires HealthKit capability enabled on the App ID and a regenerated provisioning profile).
- Account deletion from Profile wipes local state, returns to onboarding, and the backend responds 200 on `DELETE /v1/profile`.
- Paywall shows localized price, subscription period, auto-renewal disclosure, and tappable Terms of Use and Privacy Policy links before any StoreKit confirmation prompt.
- With Firestore rules deployed, a direct client-side Firestore read of another user's document fails with `PERMISSION_DENIED`.

## What To Hand Off To Me
When the accounts are ready, hand off this exact package:

- `dev`, `staging`, `prod` GCP project IDs
- The three `GoogleService-Info.plist` files
- Region selection
- Final bundle IDs
- App Store Connect API key package
- APNs auth key package
- Domain and DNS owner/contact
- Privacy policy URL
- Terms URL
- Support email
- Decision on Vertex rollout timing

## Recommended Launch Order
1. Finish `dev` setup and deploy Cloud Run services.
2. Wire `staging` iOS config and verify full smoke tests.
3. Upload `staging` to internal TestFlight.
4. Turn on Firestore, Auth, and App Check in `staging`.
5. Freeze contracts.
6. Promote the same path to `prod`.
