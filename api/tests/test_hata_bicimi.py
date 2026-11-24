"""Bütün hatalar aynı JSON biçiminde döner: {"detail": <Türkçe mesaj>, "kod": <durum>, "hatalar": [...]}."""
import logging

from fastapi.testclient import TestClient

from app.main import app


def test_dogrulama_hatasi_turkce_ve_alan_alan(client, oturum):
    yanit = client.post("/books", json={"title": "", "author": "x" * 300, "rating": 9}, headers=oturum())
    assert yanit.status_code == 422
    govde = yanit.json()
    assert govde["kod"] == 422
    assert govde["detail"] == "Girdiğin bilgileri kontrol et"
    alanlar = {h["alan"]: h["mesaj"] for h in govde["hatalar"]}
    assert alanlar["author"] == "En fazla 255 karakter olabilir"
    assert alanlar["rating"] == "En fazla 5 olabilir"
    assert "title" in alanlar


def test_eksik_alan_zorunlu_mesaji(client, oturum):
    govde = client.post("/books", json={"title": "Kitap"}, headers=oturum()).json()
    assert {"alan": "author", "mesaj": "Bu alan zorunlu"} in govde["hatalar"]


def test_kendi_dogrulama_mesajimiz_onek_olmadan(client, oturum):
    govde = client.post("/books", json={"title": "K", "author": "Y", "isbn": "123"}, headers=oturum()).json()
    assert {"alan": "isbn", "mesaj": "ISBN 10 ya da 13 haneli olmalı"} in govde["hatalar"]


def test_http_hatalari_da_ayni_bicimde(client, oturum):
    yanit = client.get("/books/999999999", headers=oturum())
    assert yanit.status_code == 404
    assert yanit.json() == {"detail": "Kitap bulunamadı", "kod": 404, "hatalar": []}
    yetkisiz = client.get("/me")
    assert yetkisiz.status_code == 401
    assert yetkisiz.json()["kod"] == 401
    assert yetkisiz.headers["WWW-Authenticate"] == "Bearer"


def test_beklenmeyen_hata_500_ve_ic_ayrinti_sizmaz(monkeypatch):
    from app.routers import books

    def patla(*_args, **_kwargs):
        raise RuntimeError("gizli iç ayrıntı")

    monkeypatch.setattr(books, "_sirala", patla)
    from app.deps import get_current_user

    app.dependency_overrides[get_current_user] = lambda: type("U", (), {"id": -1})()
    try:
        yanit = TestClient(app, raise_server_exceptions=False).get("/books")
    finally:
        app.dependency_overrides.clear()
    assert yanit.status_code == 500
    assert yanit.json() == {"detail": "Sunucuda beklenmeyen bir hata oluştu", "kod": 500, "hatalar": []}
    assert "gizli" not in yanit.text


def test_her_istek_loglanir_token_loglanmaz(client, oturum, caplog):
    baslik = oturum()
    with caplog.at_level(logging.INFO, logger="kitapligim.istek"):
        client.get("/books?search=kozmos", headers=baslik)
    satir = next(r.getMessage() for r in caplog.records if r.getMessage().startswith("GET /books"))
    assert " 200 " in satir and satir.endswith("ms")
    assert "kozmos" not in satir  # sorgu metni de loglanmaz
    token = baslik["Authorization"].split()[1]
    assert token not in caplog.text


def test_bilinmeyen_adres_ve_yontem_turkce(client):
    yok = client.get("/boyle-bir-adres-yok")
    assert yok.status_code == 404
    assert yok.json() == {"detail": "Adres bulunamadı", "kod": 404, "hatalar": []}
    yontem = client.delete("/auth/login")
    assert yontem.status_code == 405
    assert yontem.json()["detail"] == "Bu yöntem bu adreste kullanılamaz"
