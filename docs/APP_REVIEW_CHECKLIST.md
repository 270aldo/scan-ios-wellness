# App Review Checklist

## Product Access
- App launches in demo/local mode without backend dependency.
- Core onboarding, scan, Daily Brief, feedback, history, and profile flows are reachable.
- Premium surfaces degrade gracefully if StoreKit is disabled.

## Claims And Positioning
- App copy uses wellness guidance framing only.
- No diagnosis, treatment, cure, reversal, or biomarker measurement claims.
- Medical disclaimer is present on structured analysis surfaces.

## Identity And Account
- Guest/anonymous mode works for review and demo.
- Sign in with Apple is required before shipping if social sign-in becomes primary.
- Account deletion flow must exist before production release.

## Privacy
- Privacy policy must be linked in app and App Store metadata.
- Data use, AI processing, analytics, notifications, and retention are disclosed.
- Privacy manifest must be added before production upload.

## Security
- App Check debug provider must remain development-only.
- Production backend must reject requests without valid attestation once enforcement is enabled.

## Review Notes To Provide Later
- Demo mode explanation
- StoreKit product identifiers and test path
- Any non-obvious scan flow or premium gating behavior
