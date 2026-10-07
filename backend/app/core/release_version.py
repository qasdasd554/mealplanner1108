"""Jednoznaczne ustalanie wersji API na podstawie wersji aplikacji."""

from __future__ import annotations

import os
import re
from pathlib import Path

_VERSION_PATTERN = re.compile(
    r"^\s*version\s*:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$",
    re.MULTILINE,
)

# Obraz Rendera może zawierać wyłącznie katalog backend. Test kontraktu
# porównuje tę wartość z frontend/pubspec.yaml, więc każda zmiana wersji
# aplikacji bez aktualizacji backendu zatrzyma CI przed wdrożeniem.
BACKEND_ONLY_FALLBACK_VERSION = "1.0.58"


def parse_pubspec_version(contents: str) -> str:
    """Zwraca część semantyczną z `version: 1.2.3+456`."""
    match = _VERSION_PATTERN.search(contents)
    if match is None:
        raise ValueError("pubspec.yaml nie zawiera prawidłowego pola version")
    return match.group(1)


def resolve_release_version() -> str:
    """Czyta wersję mobilną, z bezpiecznym fallbackiem dla obrazu backendu.

    Render zwykle klonuje całe repozytorium, więc wersja synchronizuje się
    automatycznie. Gdy obraz zawiera wyłącznie katalog backend, można podać
    `APP_VERSION`; ostatnia wartość jest tylko awaryjna.
    """
    configured = os.getenv("APP_VERSION", "").strip()
    if configured:
        if not re.fullmatch(r"\d+\.\d+\.\d+", configured):
            raise RuntimeError("APP_VERSION musi mieć format X.Y.Z")
        return configured

    repository_root = Path(__file__).resolve().parents[3]
    pubspec = repository_root / "frontend" / "pubspec.yaml"
    if pubspec.is_file():
        return parse_pubspec_version(pubspec.read_text(encoding="utf-8"))

    return BACKEND_ONLY_FALLBACK_VERSION


APP_VERSION = resolve_release_version()
