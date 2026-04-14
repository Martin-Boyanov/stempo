import os
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv

BACKEND_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ENV_FILE = BACKEND_ROOT / ".env"
load_dotenv(BACKEND_ENV_FILE, override=False)


def _first_env(*keys: str) -> str | None:
    for key in keys:
        value = os.getenv(key)
        if value:
            return value
    return None


class Settings:
    def __init__(self) -> None:
        self.spotify_api_base_url: str = os.getenv("SPOTIFY_API_BASE_URL", "https://api.spotify.com")
        self.soundcharts_base_url: str = os.getenv("SOUNDCHARTS_BASE_URL", "https://customer.api.soundcharts.com")
        self.soundcharts_app_id: str | None = _first_env("SOUNDCHARTS_APP_ID", "SOUNDCHARTS_CLIENT_ID", "CLIENT_ID")
        self.soundcharts_api_key: str | None = _first_env(
            "SOUNDCHARTS_API_KEY",
            "SOUNDCHARTS_CLIENT_SECRET",
            "CLIENT_SECRET",
        )
        self.mysql_url: str | None = os.getenv("MYSQL_URL")
        self.mysql_host: str = os.getenv("MYSQL_HOST", "127.0.0.1")
        self.mysql_port: int = int(os.getenv("MYSQL_PORT", "3306"))
        self.mysql_user: str | None = os.getenv("MYSQL_USER")
        self.mysql_password: str | None = os.getenv("MYSQL_PASSWORD")
        self.mysql_db: str | None = os.getenv("MYSQL_DB")

    @property
    def database_url(self) -> str:
        if self.mysql_url:
            return self.mysql_url

        required = {
            "MYSQL_USER": self.mysql_user,
            "MYSQL_PASSWORD": self.mysql_password,
            "MYSQL_DB": self.mysql_db,
        }
        missing = [key for key, value in required.items() if not value]
        if missing:
            joined = ", ".join(missing)
            raise RuntimeError(f"Missing MySQL env vars: {joined}")

        return (
            f"mysql+pymysql://{self.mysql_user}:{self.mysql_password}"
            f"@{self.mysql_host}:{self.mysql_port}/{self.mysql_db}?charset=utf8mb4"
        )

    def validate_soundcharts(self) -> None:
        missing = []
        if not self.soundcharts_app_id:
            missing.append("SOUNDCHARTS_APP_ID/SOUNDCHARTS_CLIENT_ID/CLIENT_ID")
        if not self.soundcharts_api_key:
            missing.append("SOUNDCHARTS_API_KEY/SOUNDCHARTS_CLIENT_SECRET/CLIENT_SECRET")
        if missing:
            joined = ", ".join(missing)
            raise RuntimeError(f"Missing Soundcharts env vars: {joined}")


@lru_cache
def get_settings() -> Settings:
    return Settings()
