from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Değerler ortam değişkenlerinden ya da api/.env dosyasından okunur.
    database_url: str
    # JWT imzalama anahtarı: uzun, rastgele ve gizli olmalı; depoya girmez.
    jwt_secret: str
    jwt_expire_minutes: int = 60 * 24

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
