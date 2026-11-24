from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Değerler ortam değişkenlerinden ya da api/.env dosyasından okunur.
    database_url: str
    # JWT imzalama anahtarı: uzun, rastgele ve gizli olmalı; depoya girmez.
    jwt_secret: str
    # Erişim token'ı kısa ömürlüdür; süresi dolunca uygulama yenileme token'ıyla yenisini alır.
    jwt_expire_minutes: int = 30
    # Yenileme token'ı ömrü: "beni hatırla" işaretliyse gün, değilse saat cinsinden.
    refresh_remember_days: int = 30
    refresh_session_hours: int = 12

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
