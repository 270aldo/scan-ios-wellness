from __future__ import annotations

import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.services import fixture_models


def main() -> None:
    fixture_dir = ROOT / "tests" / "fixtures"
    fixture_dir.mkdir(parents=True, exist_ok=True)

    for name, payload in fixture_models().items():
        (fixture_dir / name).write_text(json.dumps(payload, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
