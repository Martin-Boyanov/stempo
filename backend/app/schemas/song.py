from __future__ import annotations

from pydantic import BaseModel
from typing import Optional


class SongResolveResponse(BaseModel):
    resolved_by: str
    song_uuid: Optional[str] = None
    isrc: Optional[str] = None
    spotify_id: Optional[str] = None
    data: dict


class SongBpmResponse(BaseModel):
    resolved_by: str
    song_uuid: Optional[str] = None
    isrc: Optional[str] = None
    spotify_id: Optional[str] = None
    track_name: Optional[str] = None
    credit_name: Optional[str] = None
    release_date: Optional[str] = None
    tempo: Optional[float] = None
    time_signature: Optional[int] = None
    danceability: Optional[float] = None
    energy: Optional[float] = None


class SongBpmBatchRequest(BaseModel):
    spotify_ids: list[str]


class SongBpmBatchItem(BaseModel):
    spotify_id: str
    tempo: Optional[float] = None
    found: bool = False


class SongBpmBatchResponse(BaseModel):
    items: list[SongBpmBatchItem]
