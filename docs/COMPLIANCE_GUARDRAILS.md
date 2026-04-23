# Compliance Guardrails

## Approved Product Framing
- decision support for wellness
- general wellness nutrition intelligence
- personalized guidance
- habit and nutrition pattern assistant

## Disallowed Framing
- diagnosis
- treatment
- cure
- reverse condition
- direct biomarker measurement
- replacement for a clinician

## Output Guardrails
- Favor phrases like `may support`, `can help guide`, `is more aligned with`, `may feel gentler`.
- Avoid certainty when confidence is medium or low.
- Always include a wellness disclaimer when analysis is shown.
- Convert unsafe phrases to softer wellness language before rendering.

## Data Guardrails
- Do not use sensitive wellness data for advertising or targeting.
- Keep AI processing and analytics behind explicit consent flags.
- Keep secrets out of the client and maintain delete/export paths before production.

## Operational Guardrails
- Keep debug providers off in production.
- Log moderation and safety-guard applications with non-sensitive payloads only.
