from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.deps.spotify_auth import require_spotify_token
from app.clients.soundcharts import SoundchartsClient
from app.db.session import get_db
from app.schemas.song import (
    SongBpmBatchItem,
    SongBpmBatchRequest,
    SongBpmBatchResponse,
    SongBpmResponse,
    SongResolveResponse,
)
from app.services.song_resolver import resolve_song

router = APIRouter(
    prefix="/soundcharts/song",
    tags=["songs"],
    dependencies=[Depends(require_spotify_token)],
)


def _to_bpm_response(result: dict, requested_spotify_id: str | None) -> SongBpmResponse:
    song_data = result.get("data", {}) if isinstance(result, dict) else {}
    song_object = song_data.get("object", {}) if isinstance(song_data, dict) else {}
    audio = song_object.get("audio", {}) if isinstance(song_object, dict) else {}
    isrc_obj = song_object.get("isrc", {}) if isinstance(song_object.get("isrc"), dict) else {}

    return SongBpmResponse(
        resolved_by=result.get("resolved_by"),
        song_uuid=result.get("song_uuid") or song_object.get("uuid"),
        isrc=result.get("isrc") or isrc_obj.get("value"),
        spotify_id=result.get("spotify_id") or requested_spotify_id,
        track_name=song_object.get("name"),
        credit_name=song_object.get("creditName"),
        release_date=song_object.get("releaseDate"),
        tempo=audio.get("tempo"),
        time_signature=audio.get("timeSignature"),
        danceability=audio.get("danceability"),
        energy=audio.get("energy"),
    )


@router.get("/bpm", response_model=SongBpmResponse)
async def get_song_bpm(
    song_uuid: str | None = Query(default=None),
    isrc: str | None = Query(default=None),
    spotify_id: str | None = Query(default=None),
    db: Session = Depends(get_db),
) -> SongBpmResponse:
    try:
        client = SoundchartsClient()
        result = await resolve_song(
            db=db,
            client=client,
            song_uuid=song_uuid,
            isrc=isrc,
            spotify_id=spotify_id,
        )
        return _to_bpm_response(result, spotify_id)
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/bpm/batch", response_model=SongBpmBatchResponse)
async def get_song_bpm_batch(
    payload: SongBpmBatchRequest,
    db: Session = Depends(get_db),
) -> SongBpmBatchResponse:
    spotify_ids = [spotify_id.strip() for spotify_id in payload.spotify_ids if spotify_id and spotify_id.strip()]
    if not spotify_ids:
        return SongBpmBatchResponse(items=[])

    # Preserve order while deduplicating.
    deduped_ids = list(dict.fromkeys(spotify_ids))
    client = SoundchartsClient()
    results: list[SongBpmBatchItem] = []

    for spotify_id in deduped_ids:
        try:
            result = await resolve_song(
                db=db,
                client=client,
                spotify_id=spotify_id,
            )
            bpm = _to_bpm_response(result, spotify_id)
            results.append(
                SongBpmBatchItem(
                    spotify_id=spotify_id,
                    tempo=bpm.tempo,
                    found=bpm.tempo is not None,
                )
            )
        except HTTPException as exc:
            if exc.status_code == 404:
                results.append(SongBpmBatchItem(spotify_id=spotify_id, tempo=None, found=False))
                continue
            raise
        except RuntimeError as exc:
            raise HTTPException(status_code=500, detail=str(exc)) from exc

    return SongBpmBatchResponse(items=results)


@router.get("/{song_uuid}/bpm", response_model=SongBpmResponse)
async def get_song_bpm_by_uuid(
    song_uuid: str,
    isrc: str | None = Query(default=None),
    spotify_id: str | None = Query(default=None),
    db: Session = Depends(get_db),
) -> SongBpmResponse:
    try:
        client = SoundchartsClient()
        result = await resolve_song(
            db=db,
            client=client,
            song_uuid=song_uuid,
            isrc=isrc,
            spotify_id=spotify_id,
        )
        return _to_bpm_response(result, spotify_id)
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/{song_uuid}", response_model=SongResolveResponse)
async def get_song_by_uuid(
    song_uuid: str,
    isrc: str | None = Query(default=None),
    spotify_id: str | None = Query(default=None),
    db: Session = Depends(get_db),
) -> SongResolveResponse:
    try:
        client = SoundchartsClient()
        result = await resolve_song(
            db=db,
            client=client,
            song_uuid=song_uuid,
            isrc=isrc,
            spotify_id=spotify_id,
        )
        return SongResolveResponse(**result)
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("", response_model=SongResolveResponse)
async def get_song(
    song_uuid: str | None = Query(default=None),
    isrc: str | None = Query(default=None),
    spotify_id: str | None = Query(default=None),
    db: Session = Depends(get_db),
) -> SongResolveResponse:
    try:
        client = SoundchartsClient()
        result = await resolve_song(
            db=db,
            client=client,
            song_uuid=song_uuid,
            isrc=isrc,
            spotify_id=spotify_id,
        )
        return SongResolveResponse(**result)
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
