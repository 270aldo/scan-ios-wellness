# AI Output Schema

## AnalysisEnvelope
- `analysis_id`: stable UUID
- `timestamp`: ISO8601 timestamp
- `input_type`: `barcode | label_photo | meal_photo | menu_photo | manual`
- `entity_type`: `product | meal | menu_item | supplement`
- `verdict`: `good | adjust | avoid | needs_more_info`
- `overall_score`: integer 0-100
- `lens_scores`: keyed lens scores for `skin`, `hormones`, `gut`, `energy`, `body_comp`
- `why_today`: short contextual reasons
- `green_flags`: positive drivers
- `red_flags`: caution drivers
- `recommended_actions`: simple next actions
- `swap_suggestions`: swap title, reason, priority
- `follow_up_prompt`: question for the next feedback step
- `confidence`: 0.0-1.0
- `medical_safety`: `is_medical_advice`, `disclaimer_needed`, `risk_level`
- `pattern_context`: `used_history`, `relevant_pattern`

## CheckInEvent
- `checkin_id`
- `timestamp`
- `linked_scan_ids`
- `energy`
- `bloating`
- `mood`
- `cravings`
- `skin`
- `satiety`
- `notes`
- `read_helpful`

## Schema Rules
- All backend-facing AI responses must map to these structures.
- Missing fields should resolve to explicit safe defaults, never freeform gaps.
- The client may derive legacy UI models from this schema, but the schema is the source of truth for new features.

## Phase 2 Structured Outputs

### PatternInsight
- `pattern_id`
- `title`
- `summary`
- `signal`: `energy | digestion | routine | menu`
- `confidence`: 0.0-1.0
- `recommended_action`
- `linked_scan_ids`
- `linked_checkin_ids`
- `safety_note`

### WeeklyInsightNarrative
- `headline`
- `pattern_summary`
- `what_to_protect`
- `what_to_reduce`
- `next_experiment`
- `confidence`: 0.0-1.0
- `supporting_pattern_ids`

### DailyHomePayloadV2
- `schema_version`: integer, currently `2`
- `hero`: hierarchy metadata, not duplicate copy
- `hero.emphasis`: `onboarding | protect_momentum | rebuild_momentum | reengage`
- `hero.why_now`: short explanation for why Home is prioritizing the current stack
- `primary_module`: `first_week_plan | daily_brief | active_goals | recommended_swap | open_loops | recent_wins | strategist_note | routine_memory | pantry | sample_reads`
- `secondary_modules`: ordered visible support modules for `More for today`
- `deferred_modules`: valid modules intentionally kept out of the first expanded stack
- `suppressed_modules`: modules hidden because they are redundant or demo-only
- `suppressed_modules[].module`
- `suppressed_modules[].reason`: `redundant_narrative | redundant_memory | demo_only`
- `cta_priority`: mirrors the hero's main action as `RecommendationKind`

## Phase 2 Rules
- Pattern and weekly narrative outputs stay structured and reversible even when generated locally.
- Weekly narrative must fall back to the legacy `WeeklyInsight` layer when there is not enough signal.
- Pantry and entitlement models are local product state, not backend AI outputs.
- `DailyHomePayload` remains the content source of truth for Home modules, while `DailyHomePayloadV2` becomes the hierarchy source of truth.
