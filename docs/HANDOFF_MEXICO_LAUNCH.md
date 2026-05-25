# Handoff Mexico Launch

Fecha: 2026-05-25
Repo local origen: `/Users/aldoolivas/IOS_ngx-silver`
Rama de trabajo: `feat/launch-readiness`
Remoto principal: `origin` -> `https://github.com/270aldo/scan-ios-wellness.git`

## Estado actual

WellnessLens ya no debe tratarse como app desde cero. La base actual tiene:

- iOS app `WellnessLens` con scan, analysis, home, history, pantry, coach, premium gating y persistencia local.
- `backend-api` para home, scan analysis, sync, history, memory, favorites y resolver de producto.
- `agent-service` separado para `scan verdict`, `coach reply` y ahora extraction nutricional.
- Compatibilidad viva con `ScanAnalysis` y `AnalysisEnvelope`.
- LILA v2 bajo `WellnessLens/Domain/LILA/`.

## Cambios recientes de Mexico launch

Implementado y pusheado:

- `MexicoNutritionSignals` en backend e iOS.
- Detector deterministico de senales NOM-051 en `backend-api/app/mexico_nutrition.py`.
- Catalogo semilla mexicano en `backend-api/app/product_resolver.py`.
- Scoring local usa sellos/advertencias para tags, razones y warnings.
- Analysis muestra pills compactas de `Etiqueta Mexico` sin redisenar la app.
- `agent-service` expone `POST /v1/nutrition/extract`.
- Extractor local estructurado en `agent-service/app/nutrition_extraction.py`.
- Tests backend y agent-service para senales Mexico y extraction.
- Docs de estado actualizados.
- `docs/LAUNCH_MASTER_PLAN.md` queda incluido como plan operativo de launch readiness.

## Validacion hecha

Pasaron:

```bash
python3 -m compileall backend-api/app agent-service/app
pytest backend-api/tests/
pytest agent-service/tests/
git diff --check
```

Resultados observados:

- backend-api: 46 passed
- agent-service: 74 passed
- whitespace/check diff: passed

Bloqueado en la Mac origen:

```bash
xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project /Users/aldoolivas/IOS_ngx-silver/WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

Motivo: `xcode-select` apunta a `/Library/Developer/CommandLineTools`, no a full Xcode.

## Primeros pasos en la otra Mac

```bash
git clone https://github.com/270aldo/scan-ios-wellness.git
cd scan-ios-wellness
git checkout feat/launch-readiness
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Despues correr:

```bash
pytest backend-api/tests/
pytest agent-service/tests/
xcodebuild -project WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project WellnessLens.xcodeproj -scheme WellnessLens -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

## Proximas decisiones tecnicas

1. Conectar iOS al endpoint `POST /v1/nutrition/extract`.
2. Respetar `aiProcessing`: si esta apagado, no llamar Gemini/agent-service para extraction.
3. Mantener Gemini/Vertex como extractor y explicador, no como autoridad de score.
4. Ampliar catalogo semilla Mexico con productos reales frecuentes.
5. Preparar staging real: backend URL, agent-service URL, Firebase, App Check, StoreKit sandbox y Vertex credentials.
6. Cerrar App Store blockers del `LAUNCH_MASTER_PLAN`.
7. Probar monetizacion: Free limitado, Plus scans/historial, Pro coach/patrones.

## Guardrails

- No reiniciar desde cero.
- No renombrar `WellnessLens`.
- No borrar `DemoScanService`; ocultar o mover copy dev/demo fuera de Release.
- No mezclar prompt de scan verdict con coach.
- Mantener fallbacks locales hasta despues de launch estable.
- Cualquier cambio provider-backed debe conservar fallback deterministico.

## Lectura recomendada antes de seguir

1. `AGENTS.md`
2. `docs/PROJECT_STATUS.md`
3. `docs/CLAUDE_HANDOFF_SUMMARY.md`
4. `docs/ADAPTED_PRDS_NEXT.md`
5. `docs/LAUNCH_MASTER_PLAN.md`
