from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.clients.spotify import SpotifyAuthError, SpotifyClient

bearer_scheme = HTTPBearer(auto_error=False)


async def require_spotify_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict:
    if credentials is None or credentials.scheme.lower() != "bearer" or not credentials.credentials:
        raise HTTPException(status_code=401, detail="Missing Authorization Bearer token")

    client = SpotifyClient()
    try:
        return await client.get_current_user(credentials.credentials)
    except SpotifyAuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
