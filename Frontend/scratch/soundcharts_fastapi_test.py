import os
from pathlib import Path
from urllib.parse import quote

import httpx
from fastapi import FastAPI, HTTPException, Query

BASE_URL = "https://customer.api.soundcharts.com"
APP_ID_KEYS = ("SOUNDCHARTS_APP_ID", "SOUNDCHARTS_CLIENT_ID", "CLIENT_ID")
API_KEY_KEYS = ("SOUNDCHARTS_API_KEY", "SOUNDCHARTS_CLIENT_SECRET", "CLIENT_SECRET")

app = FastAPI(title="Soundcharts FastAPI Test")


def _load_dotenv() -> None:
    env_path = Path(".env")
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


_load_dotenv()


def _first_env(*keys: str) -> str | None:
    for key in keys:
        value = os.getenv(key)
        if value:
            return value
    return None


def _auth_headers() -> dict[str, str]:
    app_id = _first_env(*APP_ID_KEYS)
    api_key = _first_env(*API_KEY_KEYS)
    if not app_id or not api_key:
        missing = []
        if not app_id:
            missing.append(f"app id ({', '.join(APP_ID_KEYS)})")
        if not api_key:
            missing.append(f"api key ({', '.join(API_KEY_KEYS)})")
        raise HTTPException(
            status_code=500,
            detail=f"Missing Soundcharts env vars: {', '.join(missing)}",
        )
    return {"x-app-id": app_id, "x-api-key": api_key}


async def _soundcharts_get(path: str, params: dict | None = None) -> dict:
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=20.0) as client:
        response = await client.get(path, headers=_auth_headers(), params=params)

    if response.status_code >= 400:
        detail: dict | str
        try:
            detail = response.json()
        except ValueError:
            detail = response.text
        raise HTTPException(status_code=response.status_code, detail=detail)

    return response.json()


async def _resolve_song(song_uuid: str | None = None, isrc: str | None = None, spotify_id: str | None = None) -> dict:
    if not any([song_uuid, isrc, spotify_id]):
        raise HTTPException(
            status_code=400,
            detail="Provide at least one identifier: song_uuid, isrc, or spotify_id",
        )

    if song_uuid:
        try:
            data = await _soundcharts_get(f"/api/v2.25/song/{quote(song_uuid, safe='')}")
            return {"resolved_by": "song_uuid", "song_uuid": song_uuid, "data": data}
        except HTTPException as exc:
            if exc.status_code != 404:
                raise

    if isrc:
        data = await _soundcharts_get(f"/api/v2.25/song/by-isrc/{quote(isrc, safe='')}")
        return {"resolved_by": "isrc", "isrc": isrc, "data": data}

    if spotify_id:
        data = await _soundcharts_get(
            f"/api/v2.25/song/by-platform/spotify/{quote(spotify_id, safe='')}"
        )
        return {"resolved_by": "spotify_id", "spotify_id": spotify_id, "data": data}

    raise HTTPException(status_code=404, detail="Song not found with provided identifiers")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/soundcharts/song/search")
async def search_song(term: str = Query(..., min_length=1), limit: int = Query(5, ge=1, le=20)) -> dict:
    encoded_term = quote(term, safe="")
    data = await _soundcharts_get(f"/api/v2/song/search/{encoded_term}", params={"offset": 0, "limit": limit})
    return {"term": term, "data": data}


@app.get("/soundcharts/song/{song_uuid}")
async def get_song_by_uuid(
    song_uuid: str, isrc: str | None = Query(default=None), spotify_id: str | None = Query(default=None)
) -> dict:
    return await _resolve_song(song_uuid=song_uuid, isrc=isrc, spotify_id=spotify_id)


@app.get("/soundcharts/song")
async def get_song(
    song_uuid: str | None = Query(default=None),
    isrc: str | None = Query(default=None),
    spotify_id: str | None = Query(default=None),
) -> dict:
    return await _resolve_song(song_uuid=song_uuid, isrc=isrc, spotify_id=spotify_id)


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8010"))
    reload_enabled = os.getenv("RELOAD", "0") == "1"
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=port,
        reload=reload_enabled,
    )
