from fastapi.testclient import TestClient

from app.main import app
from app.models import Base

client = TestClient(app)


def test_health_veritabani_baglantisi_calisir():
    # PostgreSQL açık ve .env dolu olmalı (README'deki kurulum adımları).
    yanit = client.get("/health")
    assert yanit.status_code == 200
    assert yanit.json() == {"durum": "ok"}


def test_beklenen_tablolar_tanimli():
    assert set(Base.metadata.tables) == {"users", "categories", "shelves", "books", "loans", "refresh_tokens"}


def test_kitap_durumu_ve_puan_kisitlari_var():
    kisitlar = {c.name for c in Base.metadata.tables["books"].constraints}
    assert {"ck_books_status", "ck_books_rating"} <= kisitlar
