# WellnessLens Infra

Terraform foundation for the WellnessLens production stack on GCP.

## What this baseline provisions

- Required project APIs for Cloud Run, Artifact Registry, Secret Manager, Firestore, Storage, Vertex, Firebase Management, Cloud Build, and Monitoring.
- Dedicated service accounts for the backend API, strategist agent service, and CI deploy lane.
- Artifact Registry repository for container images.
- Cloud Storage bucket for OCR/image assets.
- Secret Manager placeholders for Firebase Admin, App Check, App Store and Vertex-facing secrets.
- Optional Firestore database creation.
- Optional Cloud Run services for `backend-api` and `agent-service`.

## Layout

- `modules/core`: reusable stack module.
- `envs/dev`
- `envs/staging`
- `envs/prod`

Each environment root wires the same core module with environment-specific names.

## Firestore Security Rules

Rules live at the repo root in `firestore.rules` and are deployed with the
Firebase CLI (not Terraform). Keeping rules out of Terraform means the
application team can iterate on them without a full `terraform apply`, and
Firebase validates them in the deploy pipeline.

```bash
# From the repo root
firebase use wellnesslens-prod           # or -staging / -dev
firebase deploy --only firestore:rules
```

Full-fidelity local validation requires Java plus the Firebase emulator:

```bash
firebase emulators:exec --only firestore --project demo-wellnesslens 'echo OK'
```

CI should run the emulator check on every PR that touches `firestore.rules`.
See `docs/PRODUCTION_SETUP_CHECKLIST.md` for the ordering between Terraform
apply, backend deploy, and rules deploy.
