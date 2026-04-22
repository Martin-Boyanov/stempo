from __future__ import annotations

from sqlalchemy import or_
from sqlalchemy.orm import Session
from typing import Optional

from app.db.models import SongCache


class SongCacheService:
    @staticmethod
    def get_by_song_uuid(db: Session, song_uuid: str) -> Optional[SongCache]:
        return (
            db.query(SongCache)
            .filter(SongCache.song_uuid == song_uuid)
            .order_by(SongCache.updated_at.desc())
            .first()
        )

    @staticmethod
    def get_by_isrc(db: Session, isrc: str) -> Optional[SongCache]:
        return db.query(SongCache).filter(SongCache.isrc == isrc).order_by(SongCache.updated_at.desc()).first()

    @staticmethod
    def get_by_spotify_id(db: Session, spotify_id: str) -> Optional[SongCache]:
        return (
            db.query(SongCache)
            .filter(SongCache.spotify_id == spotify_id)
            .order_by(SongCache.updated_at.desc())
            .first()
        )

    @staticmethod
    def upsert_song_payload(
        db: Session,
        *,
        resolved_by: str,
        payload: dict,
        requested_song_uuid: Optional[str] = None,
        requested_isrc: Optional[str] = None,
        requested_spotify_id: Optional[str] = None,
    ) -> SongCache:
        song_object = payload.get("object", {}) if isinstance(payload, dict) else {}
        payload_song_uuid = song_object.get("uuid")
        payload_isrc = (song_object.get("isrc") or {}).get("value") if isinstance(song_object.get("isrc"), dict) else None

        song_uuid = payload_song_uuid or requested_song_uuid
        isrc = payload_isrc or requested_isrc
        spotify_id = requested_spotify_id

        existing = None
        if song_uuid:
            existing = SongCacheService.get_by_song_uuid(db, song_uuid)
        if not existing and isrc:
            existing = SongCacheService.get_by_isrc(db, isrc)
        if not existing and spotify_id:
            existing = SongCacheService.get_by_spotify_id(db, spotify_id)
        if not existing and any([requested_song_uuid, requested_isrc, requested_spotify_id]):
            filters = []
            if requested_song_uuid:
                filters.append(SongCache.song_uuid == requested_song_uuid)
            if requested_isrc:
                filters.append(SongCache.isrc == requested_isrc)
            if requested_spotify_id:
                filters.append(SongCache.spotify_id == requested_spotify_id)
            if filters:
                existing = (
                    db.query(SongCache)
                    .filter(or_(*filters))
                    .order_by(SongCache.updated_at.desc())
                    .first()
                )

        if existing:
            existing.song_uuid = song_uuid or existing.song_uuid
            existing.isrc = isrc or existing.isrc
            existing.spotify_id = spotify_id or existing.spotify_id
            existing.payload = payload
            existing.resolved_by = resolved_by
            db.commit()
            db.refresh(existing)
            return existing

        created = SongCache(
            song_uuid=song_uuid,
            isrc=isrc,
            spotify_id=spotify_id,
            payload=payload,
            resolved_by=resolved_by,
        )
        db.add(created)
        db.commit()
        db.refresh(created)
        return created
