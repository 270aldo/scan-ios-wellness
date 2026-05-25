# Launch Master Plan

Fecha: 2026-04-22  
Repo: `/Users/aldoolivas/IOS_ngx-silver`  
Producto: `WellnessLens`  
Estado actual consolidado: `no listo`

## Objetivo

Convertir la auditoria de launch readiness y App Store approval en un plan operativo unico para llevar el proyecto de:

1. `no listo`
2. `listo para TestFlight interno`
3. `listo para TestFlight externo`
4. `listo para App Review`
5. `listo para comercializar`

Este documento consolida:

- auditoria de repo, backend y servicios
- hallazgos de App Store / privacy / HealthKit / subscriptions
- gaps tecnicos y externos al repo
- prioridades reales de ejecucion

## Veredicto consolidado

El repo ya tiene producto real y no es un prototipo vacio:

- iOS tiene onboarding, tabs, scan flow, analysis surface, profile, history, check-ins, coach, premium gating y persistencia local
- `backend-api` ya expone home, scan analysis, sync, history, memory y favorites
- `agent-service` ya expone `scan verdict` y `coach reply`
- build y tests actuales pasan

Pero hoy el proyecto sigue bloqueado para App Review por cuatro grupos de problemas:

1. trust/compliance: consentimiento AI no honrado, account deletion ausente, privacy layer incompleta
2. monetizacion: StoreKit release incompleto y paywall no conforme
3. produccion real: envs/URLs/plists/deploys pendientes o no verificables desde repo
4. packaging final: copy interna de fase/demo, metadata y QA de release insuficientes

## Reglas operativas

- No mezclar fases: cerrar primero confianza/compliance y App Review blockers.
- No abrir refactors grandes antes de cerrar blockers de aprobacion.
- No introducir nuevas features de producto hasta salir de Fase 1.
- Toda tarea debe terminar con evidencia:
  - archivos tocados
  - test/comando corrido
  - riesgo residual
- Si una tarea depende de App Store Connect, legal, GCP o DNS, marcarla como `externa` y no inventar cierre.

## Etapas objetivo

### Etapa A — Listo para TestFlight interno

Definicion:

- build signed usa backend staging real
- StoreKit sandbox funcional
- HealthKit capability valida
- consent AI honrado
- privacy/legal minima visible en app

### Etapa B — Listo para TestFlight externo

Definicion:

- smoke tests completos en staging
- account deletion funcional
- App Privacy / privacy manifest alineados
- review notes y demo path preparados

### Etapa C — Listo para App Review

Definicion:

- blockers P0 cerrados
- metadata completa en App Store Connect
- IAP/subscriptions revisables por Apple
- URLs reales y funcionales
- no copy interna de demo/fase en el build final

### Etapa D — Listo para comercializar

Definicion:

- validacion y observabilidad de suscripciones
- hardening backend / auth / App Check / rate limits
- localizacion prioritaria
- QA mas alla del happy path

## Scorecard consolidado

- producto: `6/10`
- UX: `5/10`
- funcionalidad: `6/10`
- arquitectura: `5/10`
- privacidad/compliance: `1.5/10`
- monetizacion: `2.5/10`
- App Store readiness: `2/10`

## Workstreams

### WS1 — Trust / Privacy / Compliance

Incluye:

- consentimiento AI y salud
- privacy policy / terms / support
- privacy manifest
- App Privacy / Nutrition Labels
- account deletion / export
- disclosure de terceros AI
- HealthKit compliance

### WS2 — Monetizacion / StoreKit / Paywall

Incluye:

- StoreKit real en release
- `transaction.finish()`
- `Transaction.updates`
- paywall conforme a Apple
- products/subscription groups en App Store Connect
- restore / manage subscription
- validacion server-side posterior

### WS3 — Infra / Entornos / Seguridad productiva

Incluye:

- URLs reales
- Firebase / App Check / App Attest
- Cloud Run
- Firestore persistence y reglas
- backend/agent auth hardening
- secretos y despliegue real

### WS4 — Packaging / Metadata / Review Ops

Incluye:

- screenshots
- support URL
- privacy policy URL
- terms URL / EULA
- review notes
- demo mode explanation
- IAP review info
- copy final de usuario

### WS5 — QA / Accessibility / Localization / Maintainability

Incluye:

- smoke tests manuales y automatizados
- Dynamic Type / VoiceOver / contrast
- localizacion `es-MX` / `en`
- UI tests
- deuda tecnica critica post-launch

## Prioridad maestra

### P0 — Blockers de aprobacion

Estos bloquean cualquier submit serio a App Review.

| ID | Tema | Workstream | Severidad | Estado |
|---|---|---|---|---|
| B-01 | Account deletion inexistente | WS1 | critica | abierto |
| B-02 | `PrivacyInfo.xcprivacy` ausente | WS1 | critica | abierto |
| B-03 | Paywall sin disclosure conforme | WS2 | critica | abierto |
| B-04 | StoreKit 2 incompleto: sin `transaction.finish()` ni listener de updates | WS2 | critica | abierto |
| B-05 | HealthKit entitlement/capability ausente | WS1 | critica | abierto |
| B-06 | Release hereda `WL_STOREKIT_ENABLED = NO` | WS2 | critica | abierto |
| B-07 | Release no tiene backend real verificable | WS3 | critica | abierto |
| B-08 | Disclosure insuficiente de AI / third-party AI | WS1 | alta | abierto |
| B-09 | Privacy Policy / Terms / Support no accesibles en app | WS1 / WS4 | alta | abierto |
| B-10 | Metadata App Store Connect no preparada | WS4 | critica | externo |
| B-11 | Subscriptions/App Store Connect products no listos | WS2 / WS4 | critica | externo |
| B-12 | Firestore / data deletion / privacy paths no cerrados | WS1 / WS3 | critica | abierto |
| B-13 | Consentimiento AI no honrado; health processing hardcodeado | WS1 | critica | abierto |
| B-14 | Copy interna de preview/fase/demo visible al usuario | WS4 | alta | abierto |

### P1 — Blockers de comercializacion

| ID | Tema | Workstream | Severidad | Estado |
|---|---|---|---|---|
| C-01 | Validacion server-side de suscripciones | WS2 | alta | abierto |
| C-02 | Guard para write-back a HealthKit solo con alta confianza | WS1 | alta | abierto |
| C-03 | Rate limiting / abuse protection backend | WS3 | media | abierto |
| C-04 | Export de datos / consent withdrawal | WS1 | alta | abierto |
| C-05 | Monitoring y alertas de agent fallback / 5xx / quota | WS3 | media | abierto |
| C-06 | Review notes y flujo de testing claros para reviewer | WS4 | media | abierto |

### P2 — Calidad y escalabilidad

| ID | Tema | Workstream | Severidad | Estado |
|---|---|---|---|---|
| Q-01 | Dynamic Type / VoiceOver / contrast | WS5 | media | abierto |
| Q-02 | Localizacion `es-MX` / `en` | WS5 | media | abierto |
| Q-03 | UI tests / smoke automation | WS5 | media | abierto |
| Q-04 | Deuda tecnica de archivos gigantes | WS5 | media | abierto |
| Q-05 | Release engineering / archive / TestFlight automation | WS5 | media | abierto |

## Dependencias criticas

### Dependencia 1

`B-13` debe cerrarse antes de cualquier submit interno a testers externos.

Razon:

- hoy el trust model esta roto
- no tiene sentido perfeccionar paywall o metadata mientras la app ignora el consentimiento AI

### Dependencia 2

`B-04`, `B-06` y `B-11` deben cerrarse juntos.

Razon:

- no sirve arreglar el paywall si release sigue en demo billing
- no sirve activar StoreKit si App Store Connect no tiene products listos

### Dependencia 3

`B-05` y `C-02` deben cerrarse antes de shipping con HealthKit activo.

Razon:

- primero capability/entitlement
- luego control de precision para no escribir datos falsos

### Dependencia 4

`B-01`, `B-09`, `B-10` y `B-12` forman el bloque minimo de privacidad/compliance.

Razon:

- Apple no va a separar account deletion de privacy policy y retention

### Dependencia 5

`B-07` y WS3 deben estar en staging real antes de TestFlight interno.

Razon:

- sin backend real no se valida nada que importe para launch

## Fases de ejecucion

## Fase 0 — Trust Model y bloqueos duros

Objetivo:

- reparar lo que hoy seria percibido como enganoso o no confiable

### Scope

1. cerrar `B-13`
2. cerrar `B-14`
3. definir politica operativa de consentimientos

### Tareas

#### 0.1 AI consent gating real

Implementar guardas efectivas para que:

- si `userProfile.consentFlags.aiProcessing == false`
  - `scan verdict` use agente deterministico local
  - `coach` use agente deterministico local
  - no se envie request remota a `agent-service`

Archivos principales:

- `/Users/aldoolivas/IOS_ngx-silver/WellnessLens/App/AppModel.swift`
- `/Users/aldoolivas/IOS_ngx-silver/WellnessLens/App/OnboardingState.swift`
- posiblemente `/Users/aldoolivas/IOS_ngx-silver/WellnessLens/Infrastructure/PlatformServices.swift`

#### 0.2 Health processing consent real

Dejar de hardcodear `healthDataProcessing: true` y exponer un consentimiento real y entendible.

#### 0.3 Scrub de copy interna

Eliminar de user-facing strings:

- `preview`
- `this phase`
- `phase 1`
- `deterministic fallback`
- `demo mode`

Archivos principales:

- `/Users/aldoolivas/IOS_ngx-silver/WellnessLens/Features/Analysis/AnalysisView.swift`
- `/Users/aldoolivas/IOS_ngx-silver/WellnessLens/Features/Profile/ProfileView.swift`
- `/Users/aldoolivas/IOS_ngx-silver/WellnessLens/Features/History/HistoryView.swift`
- `/Users/aldoolivas/IOS_ngx-silver/WellnessLens/Domain/DailyAssistantContracts.swift`

### Definition of Done

- ningún request remoto de AI sale cuando AI consent está apagado
- `healthDataProcessing` ya no está hardcodeado
- grep de strings internas problemáticas no arroja resultados user-facing
- tests nuevos cubren el gating

### Verificacion minima

```bash
xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

## Fase 1 — Blockers de aprobacion

Objetivo:

- dejar el producto en estado razonable para TestFlight interno y camino a App Review

### Scope

1. account deletion
2. privacy manifest y legal links
3. HealthKit capability correcta
4. paywall conforme
5. StoreKit funcional en release
6. metadata y App Store Connect basicos

### Tareas

#### 1.1 Account deletion

- endpoint backend para borrar cuenta/datos asociados
- UI visible en profile/account settings
- comportamiento claro si hay suscripcion activa

#### 1.2 Privacy manifest

Crear `PrivacyInfo.xcprivacy` y validar las razones de API accedidas.

#### 1.3 Privacy Policy / Terms / Support en app

Agregar una superficie legal accesible desde perfil y paywall.

#### 1.4 HealthKit entitlement y capability

- declarar entitlement
- activar capability en App ID
- verificar prompt real en build firmado

#### 1.5 StoreKit release real

- activar StoreKit en release
- agregar `transaction.finish()`
- agregar `Transaction.updates`
- comprobar purchase y restore en sandbox

#### 1.6 Paywall conforme

Debe mostrar o delegar correctamente:

- precio
- periodo
- renovacion
- restore
- privacy / terms

#### 1.7 App Store Connect minimo viable

Externo:

- app record
- support URL
- privacy policy URL
- subscription group
- products Plus/Pro
- review notes

### Definition of Done

- build release ya no opera en demo billing
- privacy/legal visibles dentro de app
- reviewer puede ver y probar IAP
- account deletion existe y es encontrable
- HealthKit no depende de un estado roto de entitlements

### Verificacion minima

```bash
xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
pytest /Users/aldoolivas/IOS_ngx-silver/backend-api/tests/
pytest /Users/aldoolivas/IOS_ngx-silver/agent-service/tests/
```

## Fase 2 — Blockers de comercializacion

Objetivo:

- hacer que el producto no solo pase Review, sino que sea vendible y operable

### Scope

1. backend productivo endurecido
2. suscripciones auditables
3. precision y seguridad sobre HealthKit
4. observabilidad

### Tareas

#### 2.1 Validacion server-side de suscripciones

- App Store Server API o equivalente
- reflejo de estado de subscription fuera del cliente

#### 2.2 Guard para HealthKit write-back

Solo permitir escritura si el origen es suficientemente confiable.

#### 2.3 Firestore/data governance

- reglas reales
- delete path completo
- retention clara

#### 2.4 Rate limiting y hardening backend

- auth/app check verificados en staging/prod
- rate limits
- despliegues reproducibles

#### 2.5 Monitoring

- fallback rate de `agent-service`
- 5xx y latencia
- errores de StoreKit / restore

### Definition of Done

- comercializacion ya no depende solo de verificacion cliente
- datos de salud no se escriben con confianza insuficiente
- backend ya no tiene modos peligrosos en un deploy accidental
- hay alertas para fallos reales de produccion

## Fase 3 — Calidad, accesibilidad y escalabilidad

Objetivo:

- reducir riesgo post-launch y preparar iteracion ordenada

### Scope

1. accessibility
2. localization
3. UI smoke automation
4. release engineering
5. deuda tecnica critica

### Tareas

#### 3.1 Accessibility

- VoiceOver en flujos primarios
- Dynamic Type
- contrast
- acciones destructivas bien etiquetadas

#### 3.2 Localization

- definir idiomas de launch
- `es-MX`
- `en`

#### 3.3 UI smoke tests

- onboarding
- scan
- paywall
- delete account
- restore

#### 3.4 Release engineering

- archive path
- TestFlight automation
- checklist de release

#### 3.5 Deuda tecnica

Prioridad alta para dividir:

- `AppModel.swift`
- `AnalysisView.swift`
- `PlatformServices.swift`

### Definition of Done

- build final usable por gente real con settings de accesibilidad
- regression risk menor
- camino de release repetible

## Owners sugeridos

No son personas; son carriles de trabajo.

| Carril | Responsabilidad |
|---|---|
| iOS-App | consentimiento, paywall, profile/account, StoreKit, HealthKit, copy |
| Backend-API | account deletion, export, subscription validation, Firestore governance |
| Agent-Service | disclosure/data contract, logging, observability, gating alignment |
| Infra-Release | Firebase, App Check, App Attest, Cloud Run, secrets, deploys |
| Product-Legal | privacy policy, terms, support, App Store metadata, review notes |
| QA-Launch | smoke matrix, accessibility, localization, App Review rehearsal |

## Orden recomendado de trabajo paralelo

### Paralelo permitido

- WS1 consent/privacy con WS2 StoreKit/paywall
- WS4 metadata con WS3 infra externa
- QA puede preparar matriz mientras desarrollo cierra Fase 1

### No paralelizar todavia

- refactor grande de arquitectura
- nuevas features PRD 5+
- localizacion masiva antes de fijar copy final

## Criterios de salida por etapa

### Para decir `listo para TestFlight interno`

- Fase 0 cerrada
- Fase 1 parcialmente cerrada con:
  - `B-13`, `B-14`, `B-04`, `B-05`, `B-06`, `B-07`
- staging real operando
- sandbox purchase y restore verificados

### Para decir `listo para TestFlight externo`

- Fase 1 cerrada completa
- smoke matrix principal ejecutada
- metadata minima preparada

### Para decir `listo para App Review`

- P0 cerrados
- App Store Connect completo
- reviewer path documentado

### Para decir `listo para comercializar`

- Fase 2 cerrada
- monitoreo y operaciones productivas listas

## Checklist operativo de cada bloque

Antes de marcar cualquier bloque como cerrado:

1. identificar archivos exactos
2. implementar cambios minimos suficientes
3. correr verificacion local
4. documentar riesgos residuales
5. actualizar este documento o el handoff activo

## Prompt optimizado para la siguiente conversacion

Usa este prompt base en una nueva conversacion cuando quieras ejecutar el plan:

```text
Quiero ejecutar el plan maestro de launch readiness y App Store approval para `/Users/aldoolivas/IOS_ngx-silver`.

Modo de trabajo:
- No improvises roadmap nuevo.
- Usa como fuente de verdad:
  1. `/Users/aldoolivas/IOS_ngx-silver/AGENTS.md`
  2. `/Users/aldoolivas/IOS_ngx-silver/docs/PROJECT_STATUS.md`
  3. `/Users/aldoolivas/IOS_ngx-silver/docs/CLAUDE_HANDOFF_SUMMARY.md`
  4. `/Users/aldoolivas/IOS_ngx-silver/docs/ADAPTED_PRDS_NEXT.md`
  5. `/Users/aldoolivas/IOS_ngx-silver/docs/LAUNCH_MASTER_PLAN.md`

Objetivo de esta conversacion:
- Ejecutar solo la fase/bloque que yo indique.
- No tocar fases posteriores salvo cambios estrictamente necesarios.
- Antes de editar, resume:
  - objetivo del bloque
  - archivos probables
  - riesgos
  - criterios de done
- Luego implementa.
- Luego verifica con comandos reales.
- Luego entrega:
  - cambios hechos
  - archivos tocados
  - tests/comandos corridos
  - si el bloque queda cerrado o que falta exactamente

Reglas duras:
- Mantén compatibilidad con `ScanAnalysis` y `AnalysisEnvelope`.
- No hagas rewrites destructivos.
- No rompas la separación entre scan verdict y coach.
- Preserva cambios existentes del worktree.
- Si algo depende de App Store Connect, legal, Firebase, GCP o DNS y no está en el repo, dilo explícitamente y no lo inventes.

Bloque a ejecutar ahora:
- [PEGAR AQUI EL BLOQUE EXACTO, por ejemplo: “Fase 0 · 0.1 AI consent gating real + 0.2 health processing consent real”]
```

## Siguiente paso recomendado

Abrir la siguiente conversacion ejecutando solo:

- `Fase 0 · 0.1 AI consent gating real`
- `Fase 0 · 0.2 health processing consent real`
- `Fase 0 · 0.3 scrub de copy interna`

Ese es el primer corte correcto. No conviene empezar por paywall ni por infraestructura antes de reparar confianza y consentimiento.
