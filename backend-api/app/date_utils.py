from __future__ import annotations

from datetime import UTC, datetime

APPLE_REFERENCE_EPOCH = datetime(2001, 1, 1, tzinfo=UTC)


def apple_timestamp_now() -> float:
    return (datetime.now(tz=UTC) - APPLE_REFERENCE_EPOCH).total_seconds()
