from __future__ import annotations

from urllib.parse import quote
from typing import Dict, Optional, Union

import httpx

from app.core.config import get_settings


class SoundchartsAPIError(Exception):
    def __init__(self, status_code: int, detail: Union[dict, str]):
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"Soundcharts API error ({status_code})")


class SoundchartsClient:
    def __init__(self):
        self.settings = get_settings()
        self.settings.validate_soundcharts()

    @property
    def _auth_headers(self) -> dict[str, str]:
        return {
            "x-app-id": self.settings.soundcharts_app_id or "",
            "x-api-key": self.settings.soundcharts_api_key or "",
        }

    async def _get(self, path: str, params: Optional[Dict] = None) -> dict:
        async with httpx.AsyncClient(base_url=self.settings.soundcharts_base_url, timeout=20.0) as client:
            response = await client.get(path, headers=self._auth_headers, params=params)

        if response.status_code >= 400:
            try:
                detail: Union[dict, str] = response.json()
            except ValueError:
                detail = response.text
            raise SoundchartsAPIError(response.status_code, detail)

        return response.json()

    async def get_song_by_uuid(self, song_uuid: str) -> dict:
        return await self._get(f"/api/v2.25/song/{quote(song_uuid, safe='')}")

    async def get_song_by_isrc(self, isrc: str) -> dict:
        return await self._get(f"/api/v2.25/song/by-isrc/{quote(isrc, safe='')}")

    async def get_song_by_spotify_id(self, spotify_id: str) -> dict:
        return await self._get(f"/api/v2.25/song/by-platform/spotify/{quote(spotify_id, safe='')}")
