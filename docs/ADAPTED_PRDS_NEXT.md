# Adapted PRDs Next

Estos PRDs están adaptados al estado real del repo después del milestone foundation-first.

## PRD 1. Scan Verdict Surface

### Estado
Implementado y verificado en el repo real.

### Objetivo
Hacer que `ScanVerdict` sea la salida principal visible para la usuaria sin romper el flujo legacy existente.

### Contexto
- Ya existe `latestVerdict` en `AppModel`.
- Ya existe persistencia de `scanVerdicts`.
- El UI todavía sigue priorizando `ScanAnalysis` / `AnalysisEnvelope`.

### Entregables
- Result screen con jerarquía:
  - fit
  - headline
  - primaryReason
  - max 2 watchouts
  - betterSwap
  - follow-up prompt
- Home surface mínima que pueda leer `latestVerdict`
- Mantener compatibilidad con views existentes mientras se migra

### Archivos probables
- `WellnessLens/Features/Scan/...`
- `WellnessLens/Features/Home/HomeView.swift`
- nuevos subviews dedicados

### Guardrails
- no rehacer todo el Home
- no tocar branding/avatar todavía
- no acoplar UI directo al strategist

### Definition of Done
- scan exitoso muestra surface basada en `ScanVerdict`
- fallback sigue funcionando si solo hay legacy analysis
- tests de presentación añadidos

## PRD 2. Runtime Prompt + Schema Real

### Estado
Implementado y verificado en `agent-service`.

### Objetivo
Conectar `lila-agents.zip` al runtime real del `Scan Verdict Agent`, sin mezclarlo con el strategist.

### Contexto
- `lila-agents.zip` ya existe, pero hoy solo hay scaffold local.
- Ya existe endpoint `POST /v1/scan/verdict` en `agent-service`.

### Entregables
- almacenar en repo:
  - `LILA_SystemPrompt.md`
  - `ScanVerdictSchema.json`
  - `LILA_GoldenExamples.md`
- crear capa de carga/parsing/versionado
- hacer que `agent-service` produzca output estructurado real siguiendo schema
- mantener fallback determinístico local

### Guardrails
- prompt de `scan verdict` separado del prompt de coach
- no meter memoria conversacional aquí
- no romper tests actuales

### Definition of Done
- endpoint `scan/verdict` responde bajo schema estable
- golden examples validables
- fallback local disponible si provider falla

## PRD 3. Coach Agent Separado

### Estado
Implementado y verificado en backend + iOS.

### Objetivo
Formalizar el `Coach Agent` como servicio independiente que consuma `ScanVerdict`, check-ins y memoria.

### Contexto
- strategist actual existe
- thread/UI actual existe
- no debe mezclarse con `scan verdict`

### Entregables
- contrato explícito `CoachReply`
- service separado en backend
- adapter temporal para reutilizar `StrategistChatView` sin cambiar su UI
- consumo de:
  - latest verdict
  - check-ins
  - memory items
  - pattern insights

### Guardrails
- no reescribir strategist UI completo
- mantener hilo compartido si conviene
- no bloquear scans por el coach

### Definition of Done
- coach responde desde contrato propio
- `POST /v1/coach/reply` responde bajo schema estable
- golden examples del coach validan al startup
- iOS usa `RemoteCoachAgent` con auto-fallback a `DeterministicCoachAgent`
- `AppModel.sendStrategistMessage(...)` integra el coach sin tocar visualmente `StrategistChatView`

## PRD 4. Product Graph / Resolution Layer

### Objetivo
Salir del modo demo de catálogo y resolución heurística.

### Entregables
- barcode resolution real
- OCR pipeline real
- meal/menu confidence explícita
- arquitectura para fuentes:
  - Open Food Facts
  - USDA FoodData Central
  - DSLD
  - cosmética después si aplica

### Guardrails
- no destruir `DemoScanService`
- mantener confidence visible
- corrección manual siempre disponible

### Definition of Done
- barcode real resuelve productos reales
- meal/menu mantiene confidence low/medium cuando aplique
- tests backend del resolver

## PRD 5. Nutrient Intelligence Engine

### Objetivo
Reemplazar el scoring por tags con un motor más serio basado en nutrientes/contexto.

### Contexto
- hoy el fallback usa `AnalysisEngine` legacy
- LILA v2 ya soporta estructura mucho más rica

### Entregables
- engine vectorial mínimo con:
  - macros
  - azúcar
  - fibra
  - cafeína
  - proteína
  - ultra-processing
  - contexto ciclo
  - contexto fitness
  - contexto sueño/recovery

### Guardrails
- explicabilidad obligatoria
- no claims médicos
- fallback auditable

### Definition of Done
- veredictos responden a contexto biológico real
- tests unitarios de scoring

## Orden recomendado
1. PRD 4: Product Graph / Resolution Layer
2. PRD 5: Nutrient Intelligence Engine
