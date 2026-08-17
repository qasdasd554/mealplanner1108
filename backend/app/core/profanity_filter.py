"""Prosty filtr wulgaryzmów dla komentarzy pod przepisami.

UCZCIWA UWAGA O OGRANICZENIACH: to dopasowywanie rdzeni słów po
normalizacji tekstu — wyłapie zdecydowaną większość wprost napisanych
wulgaryzmów (w tym próby ich rozdzielenia spacjami/znakami, np.
"k u r w a" albo "k.u.r.w.a"), ale jak każdy filtr oparty o listę słów,
da się go obejść naprawdę kreatywną pisownią (np. z użyciem cyfr zamiast
liter w nietypowy sposób). To pierwsza, rozsądna linia obrony, nie
gwarancja stuprocentowej skuteczności — pełna, niezawodna moderacja
językowa wymagałaby modelu ML do tego dedykowanego.
"""

from __future__ import annotations

import re

# Rdzenie najczęstszych polskich wulgaryzmów — w formie znormalizowanej
# (małe litery, bez polskich znaków diakrytycznych), żeby jedno wystąpienie
# w liście łapało też odmiany przez przypadki/rodzaje (np. rdzeń "kurw"
# łapie "kurwa", "kurwy", "kurwo" itd. przez zwykłe dopasowanie prefiksu).
_PROFANITY_ROOTS = [
    "kurw",
    "chuj", "huj",
    "pierdol", "pierdziel",
    "jeban", "jebac", "jebi", "zajeb", "wyjeb", "rozjeb", "odjeb",
    "spierdal",
    "skurwi", "skurwy",
    "dziwk",
    "suka", "suki", "suko",
    "pizd",
    "cip[ae]",  # osobny wzorzec (regex) - "cipa"/"cipe" ale nie np. "cipka" w neutralnym kontekscie
    "gowni", "gowno", "gowna",
    "debil",
    "idiot",
    "kretyn",
    "zjeb",
    "pojeb",
]

# Osobne, PEŁNE wyrazy (nie rdzenie) — krótkie słowa, gdzie dopasowanie
# prefiksowe byłoby zbyt ryzykowne (złapałoby niewinne słowa).
_PROFANITY_EXACT_WORDS = {
    "cwel",
    "cwele",
}

_DIACRITIC_MAP = str.maketrans({
    "ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n",
    "ó": "o", "ś": "s", "ź": "z", "ż": "z",
})


def _normalize(text: str) -> str:
    """Małe litery, bez polskich znaków diakrytycznych — baza do obu
    poniższych sposobów dopasowania."""
    return text.lower().translate(_DIACRITIC_MAP)


def _squash(text: str) -> str:
    """Usuwa WSZYSTKO poza literami i cyframi — wyłapuje próby obejścia
    filtra przez rozdzielenie liter spacjami, kropkami, gwiazdkami itp.
    (np. "k u r w a", "k-u-r-w-a", "k*rwa")."""
    return re.sub(r"[^a-z0-9]", "", text)


def contains_profanity(text: str | None) -> bool:
    """Sprawdza, czy tekst zawiera któryś ze znanych wulgaryzmów."""
    if not text:
        return False

    normalized = _normalize(text)
    squashed = _squash(normalized)

    for root in _PROFANITY_ROOTS:
        # Dopasowanie na tekście "ściśniętym" (bez spacji/znaków) —
        # łapie zarówno normalne użycie, jak i próby obejścia filtra.
        if re.search(root, squashed):
            return True

    words = re.findall(r"[a-z0-9]+", normalized)
    if any(w in _PROFANITY_EXACT_WORDS for w in words):
        return True

    return False
