# WellnessLens Backend Audit Prompt

Use this prompt for the next backend-focused pass:

```text
Actúa como principal backend + contracts engineer sobre el proyecto WellnessLens.

Toma el estado actual del repo iOS como fuente de verdad para auditar la superficie backend visible hoy. No asumas que el backend real está alineado: primero descubre el estado actual, los huecos y el drift.

Objetivo:
1. Auditar completamente qué backend espera hoy el cliente.
2. Identificar qué ya está implementado, qué es stub, qué está muerto, qué depende todavía de fallback local y qué contratos están mezclando legado y v2.
3. Proponer un roadmap backend priorizado para cerrar gaps sin romper el cliente actual.

Contexto crítico que debes respetar:
- `DailyHomePayloadV2` ya existe y el cliente puede sintetizar fallback local.
- `AnalysisEnvelope` es el contrato estructurado clave para scans.
- Existe fallback determinista local y no debe romperse.
- Hay premium gating, entitlements v2, memoria contextual y onboarding resumable.
- No cambies primero el cliente; primero audita y especifica.

Tu trabajo debe cubrir:
- Inventario de endpoints usados por el cliente hoy.
- Requests/responses exactos y su versionado/naming.
- Qué endpoints están declarados pero aparentemente no conectados a ningún flujo real.
- Qué features dependen todavía de motores locales/fallback.
- Qué flags/config runtime alteran el comportamiento backend:
  - `WLBackendBaseURL`
  - `WLFirebaseEnabled`
  - `WLStoreKitEnabled`
  - `WLUseDemoData`
  - `WLUseAppCheckDebugProvider`
  - feature flags in-app
- Riesgos de drift entre:
  - contratos legacy vs `v1/*`
  - `DailyHomeResponse.payload` vs `payloadV2`
  - compare/alternatives/history/brief
  - versionado de schemas y policy versions
- Riesgos de producción:
  - App Check debug provider habilitado por default
  - flags no remotos
  - fallback que puede ocultar errores del backend
  - endpoints sin ownership claro como source of truth

Entregables obligatorios:
1. Una matriz de contratos backend:
   - endpoint
   - request type
   - response type
   - callsite(s) del cliente
   - fallback local asociado
   - estado estimado: live / unclear / dead / stub / drift-risk
2. Lista priorizada de gaps backend por severidad.
3. Decisiones que el backend debe tomar explícitamente para estabilizar contratos.
4. Roadmap en fases:
   - Phase 0: auditoría y observabilidad
   - Phase 1: normalización de contratos críticos
   - Phase 2: eliminación de drift y endpoints muertos
   - Phase 3: flags/config remota y hardening
5. Recomendaciones para no romper el cliente actual durante la migración.
6. Propuesta de pruebas contractuales y smoke tests end-to-end.

Busca especialmente:
- `WellnessBackendAPI`
- `HTTPWellnessBackendAPI`
- `RuntimeConfiguration`
- `WellnessFeatureFlags`
- `AppModel`
- `DailyHomePayloadV2`
- `AnalysisEnvelope`
- onboarding complete
- weekly insights
- history
- favorites
- memory upsert
- scan decisions
- structured scan
- compareProducts
- resolveScan
- daily brief

Formato de salida:
- auditoría concreta
- matriz de contratos
- lista priorizada de riesgos
- roadmap de implementación backend
- decisiones abiertas que hay que cerrar
- recomendaciones de compatibilidad cliente/backend
```
