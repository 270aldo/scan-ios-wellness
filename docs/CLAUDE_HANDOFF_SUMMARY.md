# Claude Handoff Summary

Estado reflejado en este handoff: 2026-04-21

## Contexto real del repo
- El repo **no** estaba vacío ni “solo prototipo local”. Ya existían:
  - backend estructurado y contratos en `backend-api/`
  - strategist service en `agent-service/`
  - contrato estructurado de scans en `WellnessLens/Domain/DailyAssistantContracts.swift`
  - strategist thread/UI en `WellnessLens/Features/Strategist/StrategistChatView.swift`
  - flujo actual basado en `ScanAnalysis` + `AnalysisEnvelope`
- Por eso **no** se hizo un rewrite destructivo. Se hizo un puente incremental.

## Lo que se implementó

### 1. Dominio LILA v2 incorporado sin romper el legado
Se agregaron archivos nuevos bajo `WellnessLens/Domain/LILA/`:
- `UserContextV2.swift`
- `FemaleBiology.swift`
- `FitnessProfile.swift`
- `HealthConditions.swift`
- `NutritionProfile.swift`
- `ScanVerdict.swift`
- `LILACompatibility.swift`

Decisión clave:
- El dominio nuevo quedó **namespaced** bajo `LILADomain` para evitar choques con tipos legacy como `UserContext`, `ScanSource`, `LensScore`, etc.
- Se mantuvo `menuPhoto` como caso legacy compatible porque el producto actual ya lo usa.

### 2. Bridge entre legado y LILA
En `LILACompatibility.swift` se agregó:
- mapeo `UserProfile/UserContext legacy -> LILADomain.UserContext`
- mapeo `ScanAnalysis -> LILADomain.ScanVerdict`
- mapeo `AnalysisEnvelope -> LILADomain.ScanVerdict`
- mapeo `LILADomain.ScanVerdict -> AnalysisEnvelope`
- modelo persistible `StoredScanVerdict`

Esto permite:
- conservar el pipeline actual
- generar veredictos LILA encima del motor existente
- migrar sin romper UI ni backend actual

### 3. Scan Verdict Agent separado del Coach/Strategist
Se agregó `WellnessLens/Infrastructure/ScanVerdictAgent.swift`:
- `ScanVerdictRequest`
- `ScanVerdictServing`
- `DeterministicScanVerdictAgent`

Decisión clave:
- `Scan Verdict Agent` queda como capa separada y síncrona.
- El strategist/chat **no** se mezcló con el veredicto.
- Se respeta la arquitectura planeada: `scan verdict` primero, `coach agent` después.

### 4. Persistencia de veredictos LILA
Se modificó `WellnessLens/Infrastructure/PlatformServices.swift`:
- `StoredAppState` ahora incluye `scanVerdicts: [StoredScanVerdict]`
- `schemaVersion` subió a `5`
- la migración sintetiza `scanVerdicts` si no existen, a partir de `scanEvents`
- `AppServices` ahora inyecta:
  - `scanVerdictAgent`
  - `healthKitService`

### 5. AppModel ya genera y guarda veredictos LILA
Se modificó `WellnessLens/App/AppModel.swift`:
- estado nuevo:
  - `scanVerdicts`
  - `latestVerdict`
- en `analyze(_:)` ahora:
  - corre análisis legacy
  - obtiene `AnalysisEnvelope` si aplica
  - pide snapshot a HealthKit
  - genera `LILADomain.ScanVerdict`
  - persiste `StoredScanVerdict`
  - mantiene el pipeline legacy intacto
- se agregó reconciliación `reconcileScanVerdictsIfNeeded()`

### 6. HealthKit mínimo con degradación elegante
Se agregó `WellnessLens/Infrastructure/HealthKitService.swift`:
- `BiometricsSnapshot`
- `HealthAuthorizationState`
- `HealthKitAuthorizationReport`
- `HealthKitServicing`
- `NoopHealthKitService`
- `HealthKitService` real bajo `#if canImport(HealthKit)`

Primer corte soportado:
- permisos JIT
- ciclo menstrual
- workouts
- HRV
- resting heart rate
- sleep
- wrist temperature
- nutrition write-back opcional

Decisión clave:
- el servicio degrada correctamente a `NoopHealthKitService` cuando no hay permisos, no hay HealthKit o no hay datos.

### 7. Info.plist y project.yml preparados para HealthKit
Se agregaron:
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`

También se regeneró el proyecto con `xcodegen`, porque el `.xcodeproj` no conocía los archivos nuevos.

### 8. Backend agent-service ya distingue strategist vs scan verdict
Se modificó:
- `agent-service/app/contracts.py`
- `agent-service/app/service.py`
- `agent-service/app/main.py`
- `agent-service/tests/test_agent_api.py`

Se agregó:
- contrato `ScanVerdictRequest/Response`
- endpoint `POST /v1/scan/verdict`
- implementación local scaffold separada del strategist

Decisión clave:
- el backend ya refleja explícitamente la separación entre:
  - `StrategistReply`
  - `ScanVerdict`

### 9. PRD 4 ya tiene foundation real y semantics compartidas
Se agregaron o formalizaron piezas reales del product graph / resolution layer:
- `WellnessLens/Domain/ProductGraph.swift` con `ProductReference` y `ProductGraphIndex`
- `WellnessLens/Domain/ProductResolutionSemantics.swift`
- `backend-api/app/product_resolution_semantics.py`

También se consolidó identidad estable en superficies ya existentes:
- favorites
- pantry
- routines
- memory
- follow-up
- `Experiment.relatedProductID`

En backend:
- `backend-api/app/product_resolver.py` quedó modularizado internamente en steps/providers sin cambiar el contrato publico
- `ProductCandidate` ahora puede emitir `resolution_semantics`
- `backend-api/app/services.py` dejó de depender de varias heuristicas dispersas para checks direccionales

En iOS:
- `ProductCandidate` y `LILADomain.ResolvedProduct` ahora aceptan `resolution_semantics`
- `ProductGraph` prefiere semantics explicitas y cae al fallback legacy si faltan
- `AnalysisView` consume la semantic compartida para los estados direccionales sin cambiar el texto visible

Semantics formalizadas:
- `canonical`
- `provisional`
- `directional`
- `provider_backed`
- `low_confidence`

Decisiones clave:
- la capa nueva es aditiva y backward compatible
- `ScanAnalysis` y `AnalysisEnvelope` no se rompieron
- no se abrio UI nueva para manual correction ni confidence UX
- no se mezclo este slice con PRD 5

## Lo que NO se hizo todavía
- No se implemento manual correction UX.
- No se implemento una UI mas rica de confidence / provenance; solo quedo la semantica compartida.
- No se expandieron todavia fuentes como `DSLD` o capas cosmeticas.
- No se reemplazó el scoring legacy por un motor nutricional vectorial real.
- No se tocó la experiencia visual del orb/avatar.
- No se hizo rename de marca/proyecto.

## Restricciones importantes encontradas
- El worktree ya tenía cambios activos de UI/UX. **No se deben pisar** estos archivos salvo necesidad real:
  - `WellnessLens/DesignSystem/WLComponents.swift`
  - `WellnessLens/DesignSystem/WLTheme.swift`
  - `WellnessLens/Features/Home/HomeView.swift`
  - `WellnessLens/Features/Pantry/PantryView.swift`
  - `WellnessLens/Features/Strategist/StrategistChatView.swift`
  - `WellnessLens/WellnessLensApp.swift`
- La ruta correcta es incremental con bridge, no rewrite completo.
- El nombre técnico interno debe seguir siendo `WellnessLens` por ahora.

## Verificación ejecutada
- Tests backend-api:
  - `pytest /Users/aldoolivas/IOS_ngx-silver/backend-api/tests/test_api.py`
- Build iOS:
  - `xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
- Tests iOS:
  - `xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO`
- Tests agent-service:
  - `pytest /Users/aldoolivas/IOS_ngx-silver/agent-service/tests/`

Estado verificado:
- tests `backend-api` verdes: `14 tests`
- build verde
- tests iOS verdes: `78 tests`
- tests `agent-service` verdes: `37 tests`

## Lectura recomendada para continuar
- `WellnessLens/Domain/ProductGraph.swift`
- `WellnessLens/Domain/ProductResolutionSemantics.swift`
- `WellnessLens/Domain/LILA/LILACompatibility.swift`
- `WellnessLens/Infrastructure/ScanVerdictAgent.swift`
- `WellnessLens/Infrastructure/HealthKitService.swift`
- `WellnessLens/Infrastructure/PlatformServices.swift`
- `WellnessLens/App/AppModel.swift`
- `backend-api/app/product_resolution_semantics.py`
- `backend-api/app/product_resolver.py`
- `backend-api/app/services.py`
- `agent-service/app/contracts.py`
- `agent-service/app/service.py`
- `agent-service/app/main.py`

## Resumen ejecutivo
La base ya no está en “plan teórico”. Ya existe un primer milestone ejecutable:
- dominio femenino/fitness v2 presente
- veredicto LILA persistido
- HealthKit scaffold listo
- separación `scan verdict` vs `coach`
- product graph foundation presente
- semantics compartidas de resolution/provenance/confidence presentes
- compatibilidad total con el pipeline actual

La siguiente etapa correcta ya no es “meter más teoría”, sino:
1. cerrar los slices restantes de PRD 4: manual correction UX, richer confidence/provenance UX, provider expansion
2. mantener `ScanVerdict` y coach separados mientras cae mas identidad de producto real
3. despues de eso, entrar a PRD 5: nutrient intelligence
