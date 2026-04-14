# stempo backend (FastAPI + Soundcharts + MySQL)

Backend service for song resolution and tempo data lookup through Soundcharts, with a MySQL cache layer.

## Endpoints

- `GET /health`
- `GET /soundcharts/song?song_uuid=...&isrc=...&spotify_id=...`
- `GET /soundcharts/song/{song_uuid}?isrc=...&spotify_id=...`

Fallback order is preserved:
`song_uuid -> isrc -> spotify_id`

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
- Set MySQL vars (`MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DB`)

4. Run migrations:

```bash
cd backend
alembic -c alembic.ini upgrade head
```

5. Start API:

```bash
uvicorn app.main:app --host 127.0.0.1 --port 8010 --reload
```

Swagger:
`http://127.0.0.1:8010/docs`
