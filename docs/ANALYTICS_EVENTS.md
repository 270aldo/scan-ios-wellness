# Analytics Events

## Activation
- `onboarding_started`
- `onboarding_completed`
- `first_scan_completed`
- `first_favorite_saved`
- `notification_preference_set`

## Daily Assistant Usage
- `daily_brief_viewed`
- `scan_started`
- `scan_completed`
- `meal_snapshot_started`
- `meal_snapshot_completed`
- `analysis_saved_to_favorites`
- `feedback_prompt_opened`
- `feedback_saved`

## Monetization
- `paywall_viewed`
- `subscription_purchase_started`
- `subscription_purchase_completed`
- `subscription_restore_completed`

## Quality And Safety
- `analysis_safety_guard_applied`
- `analysis_low_confidence`
- `analysis_feedback_marked_helpful`
- `analysis_feedback_marked_unhelpful`

## Notes
- Keep event names stable and lowercase snake_case.
- Do not attach sensitive freeform health notes to analytics payloads.
- Use aggregate counters and safe enums where possible.
