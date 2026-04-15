from pydantic import BaseModel


class SongResolveResponse(BaseModel):
    resolved_by: str
    song_uuid: str | None = None
    isrc: str | None = None
    spotify_id: str | None = None
    data: dict


class SongBpmResponse(BaseModel):
    resolved_by: str
    song_uuid: str | None = None
    isrc: str | None = None
    spotify_id: str | None = None
    track_name: str | None = None
    credit_name: str | None = None
    release_date: str | None = None
    tempo: float | None = None
    time_signature: int | None = None
    danceability: float | None = None
    energy: float | None = None


class SongBpmBatchRequest(BaseModel):
    spotify_ids: list[str]


class SongBpmBatchItem(BaseModel):
    spotify_id: str
    tempo: float | None = None
    found: bool = False


class SongBpmBatchResponse(BaseModel):
    items: list[SongBpmBatchItem]
