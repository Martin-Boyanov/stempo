# stempo backend (FastAPI + Soundcharts + MySQL)

Backend service for song resolution and tempo data lookup through Soundcharts, with a MySQL cache layer.

## Endpoints

- `GET /health`
- `GET /soundcharts/song/bpm?song_uuid=...&isrc=...&spotify_id=...`
- `POST /soundcharts/song/bpm/batch` with body `{"spotify_ids": ["id1", "id2", ...]}`
- `GET /soundcharts/song/{song_uuid}/bpm?isrc=...&spotify_id=...`
- `GET /soundcharts/song?song_uuid=...&isrc=...&spotify_id=...`
- `GET /soundcharts/song/{song_uuid}?isrc=...&spotify_id=...`

Fallback order is preserved:
`song_uuid -> isrc -> spotify_id`

## Authentication

All `/soundcharts/song*` endpoints now require a Spotify access token:

`Authorization: Bearer <spotify_access_token>`

The backend validates the token server-side by calling Spotify `GET /v1/me`.

## Setup

1. Install dependencies:

```bash
pip install -r backend\requirements.txt
```

2. Create backend env file:

```bash
copy backend\.env.example backend\.env
```

3. Edit `backend\.env`:
- Set `SOUNDCHARTS_CLIENT_ID` and `SOUNDCHARTS_CLIENT_SECRET`
- Optional: `SPOTIFY_API_BASE_URL` (default: `https://api.spotify.com`)
- Set MySQL vars (`MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DB`)

4. Run migrations:

```bash
cd backend
alembic -c alembic.ini upgrade head
```

5. Start API:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8010 --reload
```

Swagger:
`http://127.0.0.1:8010/docs`

For Flutter Android:
- Emulator: `BACKEND_BASE_URL=http://10.0.2.2:8010`
- Physical device: `BACKEND_BASE_URL=http://<your-computer-lan-ip>:8010`
