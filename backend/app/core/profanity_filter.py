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
#
# UWAGA (naprawa): "suka"/"suki"/"suko" były wcześniej w liście rdzeni
# powyżej (dopasowanie prefiksowe) — ale "suki" jest jednocześnie
# dosłownym PREFIKSEM zupełnie niewinnego słowa "sukienki" (i całej
# rodziny: sukienka, sukience, sukienek...). Efekt: komentarz "Kupiłem
# sukienki" byłby błędnie zablokowany jako wulgarny. Przeniesione tutaj
# — wymaga DOKŁADNEGO dopasowania całego słowa, nie tylko prefiksu.
_PROFANITY_EXACT_WORDS = {
    "cwel",
    "cwele",
    "suka", "suki", "suko", "sukami", "sukach",
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

    # KROK 1: dopasowanie na POJEDYNCZYCH słowach (podzielonych po dowolnym
    # znaku niebędącym literą/cyfrą) — najbardziej niezawodne, zero ryzyka
    # fałszywych trafień na granicy słów.
    tokens = [t for t in re.split(r"[^a-z0-9]+", normalized) if t]
    for token in tokens:
        for root in _PROFANITY_ROOTS:
            if re.search(root, token):
                return True
    if any(t in _PROFANITY_EXACT_WORDS for t in tokens):
        return True

    # KROK 2: obejście przez rozdzielenie POJEDYNCZYCH LITER (np. "k u r w
    # a", "k.u.r.w.a") — łączymy TYLKO sąsiadujące, jednoznakowe "słowa"
    # (bo tak wyglądają realne próby obejścia filtra), NIGDY całych,
    # normalnych, wieloznakowych słów ze sobą.
    #
    # UWAGA (naprawa): wcześniej ten krok "ściskał" CAŁY tekst na raz
    # (usuwając WSZYSTKIE spacje na raz, łącznie z tymi między zupełnie
    # różnymi, normalnymi słowami), co dawało fałszywe trafienia —
    # np. zdanie "Kupiłem mąkę, sukienki nie kupiłem" było błędnie
    # blokowane, bo "mąkę, sukienki" po ściśnięciu zawierało "suki"
    # (koniec jednego słowa + początek drugiego). Teraz łączymy tylko
    # sekwencje pojedynczych liter, które same w sobie nie są normalnymi
    # polskimi słowami.
    i = 0
    while i < len(tokens):
        if len(tokens[i]) == 1:
            j = i
            combined = ""
            while j < len(tokens) and len(tokens[j]) == 1:
                combined += tokens[j]
                j += 1
            if len(combined) >= 3:
                for root in _PROFANITY_ROOTS:
                    if re.search(root, combined):
                        return True
                if combined in _PROFANITY_EXACT_WORDS:
                    return True
            i = j
        else:
            i += 1

    return False
