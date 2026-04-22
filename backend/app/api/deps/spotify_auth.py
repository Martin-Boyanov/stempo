from __future__ import annotations

import time

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from typing import Optional

from app.clients.spotify import SpotifyAuthError, SpotifyClient

bearer_scheme = HTTPBearer(auto_error=False)
_TOKEN_VALIDATION_TTL_SECONDS = 120.0
_token_validation_cache: dict[str, tuple[float, dict]] = {}


async def require_spotify_token(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
) -> dict:
    if credentials is None or credentials.scheme.lower() != "bearer" or not credentials.credentials:
        raise HTTPException(status_code=401, detail="Missing Authorization Bearer token")

    token = credentials.credentials
    now = time.monotonic()
    cached = _token_validation_cache.get(token)
    if cached is not None:
        expires_at, payload = cached
        if expires_at > now:
            return payload
        _token_validation_cache.pop(token, None)

    client = SpotifyClient()
    try:
        payload = await client.get_current_user(token)
        _token_validation_cache[token] = (
            now + _TOKEN_VALIDATION_TTL_SECONDS,
            payload,
        )
        return payload
    except SpotifyAuthError as exc:
        _token_validation_cache.pop(token, None)
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
