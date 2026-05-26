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

## Mexico-Specific Guardrails (NOM-051 + COFEPRIS)

- Las señales de "Exceso de ..." (calorías, azúcares, sodio, grasas saturadas, grasas trans) son **información regulatoria oficial** según la NOM-051. Se comunican como datos, no como juicios de valor sobre el producto completo.
- Nunca se usa el lenguaje de sellos NOM-051 para recomendar o desaconsejar el consumo del producto en su totalidad.
- En contextos de embarazo, postparto, perimenopausia y menopausia se mantiene el estándar más alto de humildad epistémica y derivación a profesionales de la salud.
- Todo el lenguaje de veredictos, razones y watchouts debe seguir la guía `MEXICO_CLAIMS_GUIDE.md` (tabla Safe / Gray / Red).
- El posicionamiento general del producto en México es: **herramienta de información y apoyo a la toma de decisiones personales de bienestar**, nunca como fuente de consejo médico, nutricional clínico o terapéutico.
