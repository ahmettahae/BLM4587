import uuid

from sqlalchemy import delete

from app.db import SessionLocal
from app.models import Category

ORNEK = {"title": "Tutunamayanlar", "author": "Oğuz Atay", "isbn": "978-975-470-090-5", "year": 1972, "pages": 724}


def test_kitap_ekle_listele_getir(client, oturum):
    baslik = oturum()
    yanit = client.post("/books", json={**ORNEK, "title": "  Tutunamayanlar  ", "publisher": "   "}, headers=baslik)
    assert yanit.status_code == 201, yanit.text
    kitap = yanit.json()
    assert kitap["title"] == "Tutunamayanlar"
    assert kitap["author"] == "Oğuz Atay"  # Türkçe karakter bozulmadan döner
    assert kitap["isbn"] == "9789754700905"  # tireler atılır
    assert kitap["publisher"] is None  # boş metin None olur
    assert kitap["status"] == "okunacak" and kitap["rating"] is None

    liste = client.get("/books", headers=baslik).json()
    assert [k["id"] for k in liste] == [kitap["id"]]
    assert client.get(f"/books/{kitap['id']}", headers=baslik).json()["title"] == "Tutunamayanlar"


def test_liste_en_yeni_basta(client, oturum):
    baslik = oturum()
    ilk = client.post("/books", json={"title": "Bir", "author": "A"}, headers=baslik).json()
    ikinci = client.post("/books", json={"title": "İki", "author": "B"}, headers=baslik).json()
    assert [k["id"] for k in client.get("/books", headers=baslik).json()] == [ikinci["id"], ilk["id"]]


def test_kitap_guncelle_ve_sil(client, oturum):
    baslik = oturum()
    kitap = client.post("/books", json=ORNEK, headers=baslik).json()

    yanit = client.put(
        f"/books/{kitap['id']}",
        json={"title": "Tutunamayanlar", "author": "Oğuz Atay", "status": "okundu", "rating": 5},
        headers=baslik,
    )
    assert yanit.status_code == 200, yanit.text
    guncel = yanit.json()
    assert guncel["status"] == "okundu" and guncel["rating"] == 5
    assert guncel["isbn"] is None and guncel["year"] is None  # PUT tüm alanları yeniden yazar

    assert client.delete(f"/books/{kitap['id']}", headers=baslik).status_code == 204
    assert client.get(f"/books/{kitap['id']}", headers=baslik).status_code == 404
    assert client.delete(f"/books/{kitap['id']}", headers=baslik).status_code == 404


def test_baskasinin_kitabina_erisilemez(client, oturum):
    sahip, yabanci = oturum(), oturum()
    kitap = client.post("/books", json=ORNEK, headers=sahip).json()

    assert client.get("/books", headers=yabanci).json() == []
    assert client.get(f"/books/{kitap['id']}", headers=yabanci).status_code == 404
    assert client.put(f"/books/{kitap['id']}", json=ORNEK, headers=yabanci).status_code == 404
    assert client.delete(f"/books/{kitap['id']}", headers=yabanci).status_code == 404
    assert client.get(f"/books/{kitap['id']}", headers=sahip).status_code == 200


def test_oturumsuz_erisim_401(client):
    assert client.get("/books").status_code == 401
    assert client.post("/books", json=ORNEK).status_code == 401


def test_gecersiz_kitap_verisi_reddedilir(client, oturum):
    baslik = oturum()
    gecersizler = [
        {"title": "   ", "author": "A"},
        {"title": "A"},  # yazar eksik
        {"title": "A", "author": "B", "isbn": "12345"},
        {"title": "A", "author": "B", "isbn": "97897547009X5"},
        {"title": "A", "author": "B", "year": 3000},
        {"title": "A", "author": "B", "pages": 0},
        {"title": "A", "author": "B", "rating": 6},
        {"title": "A", "author": "B", "status": "bitti"},
        {"title": "A" * 256, "author": "B"},
    ]
    for veri in gecersizler:
        assert client.post("/books", json=veri, headers=baslik).status_code == 422, veri
    assert client.get("/books", headers=baslik).json() == []


def test_isbn10_x_ile_kabul_edilir(client, oturum):
    yanit = client.post("/books", json={"title": "A", "author": "B", "isbn": "0-8044-2957-x"}, headers=oturum())
    assert yanit.status_code == 201
    assert yanit.json()["isbn"] == "080442957X"


def test_kategori_ve_raf_dogrulanir(client, oturum):
    baslik = oturum()
    assert client.post("/books", json={**ORNEK, "category_id": 999999}, headers=baslik).json()["detail"] == "Kategori bulunamadı"
    assert client.post("/books", json={**ORNEK, "shelf_id": 999999}, headers=baslik).json()["detail"] == "Raf bulunamadı"

    ad = f"test-kategori-{uuid.uuid4().hex[:8]}"
    with SessionLocal() as db:
        kategori = Category(name=ad)
        db.add(kategori)
        db.commit()
        kategori_id = kategori.id
    try:
        yanit = client.post("/books", json={**ORNEK, "category_id": kategori_id}, headers=baslik)
        assert yanit.status_code == 201 and yanit.json()["category_id"] == kategori_id
    finally:
        with SessionLocal() as db:
            db.execute(delete(Category).where(Category.id == kategori_id))
            db.commit()
