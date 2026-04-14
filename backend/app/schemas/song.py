from pydantic import BaseModel


class SongResolveResponse(BaseModel):
    resolved_by: str
    song_uuid: str | None = None
    isrc: str | None = None
    spotify_id: str | None = None
    data: dict
