import os

from fastapi import FastAPI

from app.api.routes.health import router as health_router
from app.api.routes.songs import router as songs_router

app = FastAPI(title="stempo backend")
app.include_router(health_router)
app.include_router(songs_router)


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8010"))
    host = os.getenv("HOST", "0.0.0.0")
    reload_enabled = os.getenv("RELOAD", "0") == "1"
    uvicorn.run(app, host=host, port=port, reload=reload_enabled)
