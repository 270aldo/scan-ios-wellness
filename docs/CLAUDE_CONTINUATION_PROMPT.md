# Prompt Para Nueva Conversación

Trabaja sobre este repo local: `/Users/aldoolivas/IOS_ngx-silver`.

Primero lee:
- `/Users/aldoolivas/IOS_ngx-silver/docs/CLAUDE_HANDOFF_SUMMARY.md`
- `/Users/aldoolivas/IOS_ngx-silver/docs/ADAPTED_PRDS_NEXT.md`

Contexto obligatorio:
- No empieces desde cero.
- El repo ya tiene backend, strategist, contratos estructurados y pipeline legacy funcional.
- Ya existe un milestone foundation-first implementado:
  - dominio LILA v2 namespaced bajo `LILADomain`
  - bridge incremental en `WellnessLens/Domain/LILA/LILACompatibility.swift`
  - `ScanVerdictAgent` separado
  - `HealthKitService` mínimo
  - persistencia de `scanVerdicts`
  - `latestVerdict` en `AppModel`
  - endpoint backend separado `POST /v1/scan/verdict`

Restricciones:
- No hagas rewrite destructivo.
- No renombres proyecto/módulo.
- No pises cambios activos de UI/UX en:
  - `WellnessLens/DesignSystem/WLComponents.swift`
  - `WellnessLens/DesignSystem/WLTheme.swift`
  - `WellnessLens/Features/Home/HomeView.swift`
  - `WellnessLens/Features/Pantry/PantryView.swift`
  - `WellnessLens/Features/Strategist/StrategistChatView.swift`
  - `WellnessLens/WellnessLensApp.swift`
- Mantén compatibilidad con `ScanAnalysis` + `AnalysisEnvelope`.

Objetivo de esta conversación:
- continuar con el siguiente PRD adaptado y ejecutarlo sobre el repo real, no sobre el plan original teórico.

Orden recomendado:
1. Implementar `PRD 1. Scan Verdict Surface`
2. Si sobra tiempo, dejar listo el arranque de `PRD 2. Runtime Prompt + Schema Real`

Lo que espero como salida:
- cambios de código reales
- build y tests corriendo
- explicación corta de:
  - qué se tocó
  - qué se verificó
  - qué falta para el siguiente PRD

No repitas el análisis ya hecho. Continúa desde el estado actual del repositorio.
