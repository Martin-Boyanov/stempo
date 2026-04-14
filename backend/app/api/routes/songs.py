from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.clients.soundcharts import SoundchartsClient
from app.db.session import get_db
from app.schemas.song import SongResolveResponse
from app.services.song_resolver import resolve_song

router = APIRouter(prefix="/soundcharts/song", tags=["songs"])


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
