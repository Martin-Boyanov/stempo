import httpx

from app.core.config import get_settings


class SpotifyAuthError(Exception):
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


class SpotifyClient:
    def __init__(self) -> None:
        self.settings = get_settings()

    async def get_current_user(self, access_token: str) -> dict:
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient(base_url=self.settings.spotify_api_base_url, timeout=15.0) as client:
            response = await client.get("/v1/me", headers=headers)

        if response.status_code in (401, 403):
            raise SpotifyAuthError(401, "Invalid or expired Spotify token")
        if response.status_code >= 400:
            raise SpotifyAuthError(response.status_code, "Spotify token validation failed")

        payload = response.json()
        if not isinstance(payload, dict):
            raise SpotifyAuthError(401, "Invalid Spotify token response")
        if not payload.get("id"):
            raise SpotifyAuthError(401, "Spotify token is missing user identity")
        return payload
