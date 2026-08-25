"""Wspólna, JEDYNA lista modeli Gemini w łańcuchu zapasowym.

UWAGA (naprawa): wcześniej ta sama lista była zduplikowana osobno w
ai_recipe_import.py, promo_ai_scanner.py i gemini_status.py — gdy
rozszerzono ją do 6 modeli w pierwszych dwóch plikach, TRZECI
(gemini_status.py, używany przez panel admina do sprawdzania stanu API)
nigdy nie został zaktualizowany i nadal pokazywał tylko 3 stare modele.
Efekt: administrator patrzący na status widział błędny, nieaktualny
obraz tego, ile modeli faktycznie próbuje aplikacja. Scalenie do
JEDNEGO miejsca eliminuje możliwość powtórzenia się tego rozjazdu w
przyszłości — każdy plik importuje stąd, zamiast trzymać własną kopię.

Kolejność (priorytet użycia) ustalona świadomie: trzy najnowsze modele
na start, potem trzy wcześniej używane jako dalszy zapas. Identyfikatory
API zweryfikowane bezpośrednio w oficjalnej dokumentacji Google
(ai.google.dev) — "gemini-3-flash" bez przyrostka nie jest prawidłowym
identyfikatorem, poprawna nazwa to "gemini-3-flash-preview".
"""

GEMINI_MODEL_PRIMARY = "gemini-3.5-flash"
GEMINI_MODEL_SECONDARY = "gemini-3-flash-preview"
GEMINI_MODEL_TERTIARY = "gemini-3.1-flash-lite"
GEMINI_MODEL_QUATERNARY = "gemini-3.7-flash"
GEMINI_MODEL_QUINARY = "gemini-3.6-flash"
GEMINI_MODEL_FALLBACK = "gemini-3.5-flash-lite"

GEMINI_MODELS = [
    GEMINI_MODEL_PRIMARY,
    GEMINI_MODEL_SECONDARY,
    GEMINI_MODEL_TERTIARY,
    GEMINI_MODEL_QUATERNARY,
    GEMINI_MODEL_QUINARY,
    GEMINI_MODEL_FALLBACK,
]

GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
