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
