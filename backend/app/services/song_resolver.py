import logging

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.clients.soundcharts import SoundchartsAPIError, SoundchartsClient
from app.services.song_cache import SongCacheService

logger = logging.getLogger("uvicorn.error")


def _log_resolution(source: str, resolved_by: str, song_uuid: str | None, isrc: str | None, spotify_id: str | None) -> None:
    logger.info(
        "song_resolve source=%s resolved_by=%s song_uuid=%s isrc=%s spotify_id=%s",
        source,
        resolved_by,
        song_uuid,
        isrc,
        spotify_id,
    )


def _cached_response(*, resolved_by: str, cache_row, song_uuid: str | None, isrc: str | None, spotify_id: str | None) -> dict:
    response = {"resolved_by": resolved_by, "data": cache_row.payload}
    if resolved_by == "song_uuid":
        response["song_uuid"] = song_uuid or cache_row.song_uuid
    if resolved_by == "isrc":
        response["isrc"] = isrc or cache_row.isrc
    if resolved_by == "spotify_id":
        response["spotify_id"] = spotify_id or cache_row.spotify_id
    return response


async def resolve_song(
    *,
    db: Session,
    client: SoundchartsClient,
    song_uuid: str | None = None,
    isrc: str | None = None,
    spotify_id: str | None = None,
) -> dict:
    if not any([song_uuid, isrc, spotify_id]):
        raise HTTPException(
            status_code=400,
            detail="Provide at least one identifier: song_uuid, isrc, or spotify_id",
        )

    if song_uuid:
        cached = SongCacheService.get_by_song_uuid(db, song_uuid)
        if cached:
            _log_resolution("cache", "song_uuid", song_uuid, isrc, spotify_id)
            return _cached_response(
                resolved_by="song_uuid",
                cache_row=cached,
                song_uuid=song_uuid,
                isrc=isrc,
                spotify_id=spotify_id,
            )

    if isrc:
        cached = SongCacheService.get_by_isrc(db, isrc)
        if cached:
            _log_resolution("cache", "isrc", song_uuid, isrc, spotify_id)
            return _cached_response(
                resolved_by="isrc",
                cache_row=cached,
                song_uuid=song_uuid,
                isrc=isrc,
                spotify_id=spotify_id,
            )

    if spotify_id:
        cached = SongCacheService.get_by_spotify_id(db, spotify_id)
        if cached:
            _log_resolution("cache", "spotify_id", song_uuid, isrc, spotify_id)
            return _cached_response(
                resolved_by="spotify_id",
                cache_row=cached,
                song_uuid=song_uuid,
                isrc=isrc,
                spotify_id=spotify_id,
            )

    try:
        if song_uuid:
            payload = await client.get_song_by_uuid(song_uuid)
            SongCacheService.upsert_song_payload(
                db,
                resolved_by="song_uuid",
                payload=payload,
                requested_song_uuid=song_uuid,
                requested_isrc=isrc,
                requested_spotify_id=spotify_id,
            )
            _log_resolution("soundcharts", "song_uuid", song_uuid, isrc, spotify_id)
            return {"resolved_by": "song_uuid", "song_uuid": song_uuid, "data": payload}

        if isrc:
            payload = await client.get_song_by_isrc(isrc)
            SongCacheService.upsert_song_payload(
                db,
                resolved_by="isrc",
                payload=payload,
                requested_song_uuid=song_uuid,
                requested_isrc=isrc,
                requested_spotify_id=spotify_id,
            )
            _log_resolution("soundcharts", "isrc", song_uuid, isrc, spotify_id)
            return {"resolved_by": "isrc", "isrc": isrc, "data": payload}

        if spotify_id:
            payload = await client.get_song_by_spotify_id(spotify_id)
            SongCacheService.upsert_song_payload(
                db,
                resolved_by="spotify_id",
                payload=payload,
                requested_song_uuid=song_uuid,
                requested_isrc=isrc,
                requested_spotify_id=spotify_id,
            )
            _log_resolution("soundcharts", "spotify_id", song_uuid, isrc, spotify_id)
            return {"resolved_by": "spotify_id", "spotify_id": spotify_id, "data": payload}

    except SoundchartsAPIError as exc:
        if exc.status_code == 404 and song_uuid and isrc:
            try:
                payload = await client.get_song_by_isrc(isrc)
                SongCacheService.upsert_song_payload(
                    db,
                    resolved_by="isrc",
                    payload=payload,
                    requested_song_uuid=song_uuid,
                    requested_isrc=isrc,
                    requested_spotify_id=spotify_id,
                )
                _log_resolution("soundcharts", "isrc", song_uuid, isrc, spotify_id)
                return {"resolved_by": "isrc", "isrc": isrc, "data": payload}
            except SoundchartsAPIError as isrc_exc:
                if isrc_exc.status_code != 404:
                    raise HTTPException(status_code=isrc_exc.status_code, detail=isrc_exc.detail) from isrc_exc

        if exc.status_code == 404 and (song_uuid or isrc) and spotify_id:
            try:
                payload = await client.get_song_by_spotify_id(spotify_id)
                SongCacheService.upsert_song_payload(
                    db,
                    resolved_by="spotify_id",
                    payload=payload,
                    requested_song_uuid=song_uuid,
                    requested_isrc=isrc,
                    requested_spotify_id=spotify_id,
                )
                _log_resolution("soundcharts", "spotify_id", song_uuid, isrc, spotify_id)
                return {"resolved_by": "spotify_id", "spotify_id": spotify_id, "data": payload}
            except SoundchartsAPIError as spotify_exc:
                if spotify_exc.status_code != 404:
                    raise HTTPException(status_code=spotify_exc.status_code, detail=spotify_exc.detail) from spotify_exc

        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    raise HTTPException(status_code=404, detail="Song not found with provided identifiers")
