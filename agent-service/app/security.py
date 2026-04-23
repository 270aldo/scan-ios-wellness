from __future__ import annotations

from dataclasses import dataclass

import firebase_admin
from firebase_admin import app_check, auth


class SecurityVerificationError(RuntimeError):
    """Raised when Firebase-backed request verification fails."""


@dataclass(frozen=True)
class VerifiedRequestContext:
    auth_claims: dict | None = None
    app_check_claims: dict | None = None


def _ensure_firebase_app() -> firebase_admin.App:
    try:
        return firebase_admin.get_app()
    except ValueError:
        return firebase_admin.initialize_app()


def verify_firebase_id_token(authorization: str) -> dict:
    token = authorization.removeprefix("Bearer").strip()
    if not token:
        raise SecurityVerificationError("Missing bearer token.")

    try:
        _ensure_firebase_app()
        return auth.verify_id_token(token, check_revoked=True)
    except Exception as exc:  # pragma: no cover - depends on Firebase runtime
        raise SecurityVerificationError(f"Invalid Firebase ID token: {exc}") from exc


def verify_firebase_app_check_token(token: str) -> dict:
    cleaned = token.strip()
    if not cleaned:
        raise SecurityVerificationError("Missing App Check token.")

    try:
        _ensure_firebase_app()
        return app_check.verify_token(cleaned)
    except Exception as exc:  # pragma: no cover - depends on Firebase runtime
        raise SecurityVerificationError(f"Invalid Firebase App Check token: {exc}") from exc
