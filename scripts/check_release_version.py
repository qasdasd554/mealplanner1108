"""Fail CI when the backend-only fallback differs from Flutter's version."""

from __future__ import annotations

import sys
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPOSITORY_ROOT / "backend"))

from app.core.release_version import (  # noqa: E402
    BACKEND_ONLY_FALLBACK_VERSION,
    parse_pubspec_version,
)


def main() -> int:
    pubspec = REPOSITORY_ROOT / "frontend" / "pubspec.yaml"
    mobile_version = parse_pubspec_version(pubspec.read_text(encoding="utf-8"))
    if BACKEND_ONLY_FALLBACK_VERSION != mobile_version:
        print(
            "Niezgodne wersje: frontend "
            f"{mobile_version}, backend {BACKEND_ONLY_FALLBACK_VERSION}."
        )
        return 1
    print(f"Wersje są zgodne: {mobile_version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
