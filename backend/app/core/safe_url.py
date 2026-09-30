"""Walidacja zewnętrznych adresów URL przed pobieraniem przez backend."""

from __future__ import annotations

import asyncio
import ipaddress
import socket
from urllib.parse import urlsplit


class UnsafeUrlError(ValueError):
    """Adres wskazuje poza publiczny internet albo ma niedozwolony format."""


def _is_public_ip(value: str) -> bool:
    ip = ipaddress.ip_address(value.split("%", 1)[0])
    return ip.is_global


async def validate_public_http_url(url: str) -> str:
    """Dopuszcza wyłącznie HTTP(S), którego host rozwiązuje się publicznie.

    Sprawdzenie jest wykonywane także dla każdego przekierowania przez kod
    wywołujący. Blokuje m.in. localhost, sieci prywatne, link-local, adresy
    chmurowych usług metadanych i hosty zapisane w nietypowej postaci IP.
    """
    value = (url or "").strip()
    parsed = urlsplit(value)
    if parsed.scheme.lower() not in {"http", "https"}:
        raise UnsafeUrlError("Link musi zaczynać się od http:// albo https://.")
    if not parsed.hostname:
        raise UnsafeUrlError("Link nie zawiera prawidłowej domeny.")
    if parsed.username is not None or parsed.password is not None:
        raise UnsafeUrlError("Link nie może zawierać danych logowania.")

    hostname = parsed.hostname.rstrip(".").casefold()
    if hostname == "localhost" or hostname.endswith((".localhost", ".local", ".internal")):
        raise UnsafeUrlError("Link prowadzi do niedozwolonego adresu lokalnego.")

    try:
        literal_ip = ipaddress.ip_address(hostname.split("%", 1)[0])
    except ValueError:
        literal_ip = None
    if literal_ip is not None:
        if not literal_ip.is_global:
            raise UnsafeUrlError("Link prowadzi do niedozwolonego adresu lokalnego.")
        return value

    port = parsed.port or (443 if parsed.scheme.lower() == "https" else 80)
    try:
        addresses = await asyncio.to_thread(
            socket.getaddrinfo,
            hostname,
            port,
            type=socket.SOCK_STREAM,
        )
    except (socket.gaierror, OSError) as exc:
        raise UnsafeUrlError("Nie udało się odnaleźć domeny z podanego linku.") from exc

    resolved = {entry[4][0] for entry in addresses if entry[4]}
    if not resolved or any(not _is_public_ip(address) for address in resolved):
        raise UnsafeUrlError("Link prowadzi do niedozwolonego adresu lokalnego.")
    return value
