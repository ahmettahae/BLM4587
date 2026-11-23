def _raf(client, baslik, ad):
    return client.post("/shelves", json={"name": ad}, headers=baslik)


def test_raf_ekle_listele_sirali(client, oturum):
    baslik = oturum()
    for ad in ["Şiir", "Roman", "Çocuk"]:
        assert _raf(client, baslik, ad).status_code == 201
    liste = client.get("/shelves", headers=baslik).json()
    assert [r["name"] for r in liste] == ["Çocuk", "Roman", "Şiir"]
    assert all(r["book_count"] == 0 for r in liste)


def test_ayni_ad_409(client, oturum):
    baslik = oturum()
    assert _raf(client, baslik, "Roman").status_code == 201
    yanit = _raf(client, baslik, "roman")
    assert yanit.status_code == 409
    assert yanit.json()["detail"] == "Bu adda bir raf zaten var"


def test_iki_kullanici_ayni_adi_kullanabilir(client, oturum):
    assert _raf(client, oturum(), "Roman").status_code == 201
    assert _raf(client, oturum(), "Roman").status_code == 201


def test_baska_kullanici_rafi_404(client, oturum):
    a, b = oturum(), oturum()
    raf = _raf(client, a, "Gizli").json()
    assert client.get("/shelves", headers=b).json() == []
    assert client.put(f"/shelves/{raf['id']}", json={"name": "X"}, headers=b).status_code == 404
    assert client.delete(f"/shelves/{raf['id']}", headers=b).status_code == 404
    assert client.get("/shelves", headers=a).json()[0]["name"] == "Gizli"


def test_kendi_adini_harf_degistirerek_guncelle(client, oturum):
    baslik = oturum()
    raf = _raf(client, baslik, "roman").json()
    yanit = client.put(f"/shelves/{raf['id']}", json={"name": "Roman"}, headers=baslik)
    assert yanit.status_code == 200, yanit.text
    assert yanit.json()["name"] == "Roman"


def test_guncellemede_baska_rafin_adi_409(client, oturum):
    baslik = oturum()
    _raf(client, baslik, "Roman")
    raf = _raf(client, baslik, "Şiir").json()
    assert client.put(f"/shelves/{raf['id']}", json={"name": "ROMAN"}, headers=baslik).status_code == 409


def test_book_count(client, oturum):
    baslik = oturum()
    raf = _raf(client, baslik, "Salon").json()
    for t in ["A", "B"]:
        client.post("/books", json={"title": t, "author": "X", "shelf_id": raf["id"]}, headers=baslik)
    client.post("/books", json={"title": "C", "author": "X"}, headers=baslik)
    assert client.get("/shelves", headers=baslik).json()[0]["book_count"] == 2


def test_raf_silinince_kitap_rafsiz_kalir(client, oturum):
    baslik = oturum()
    raf = _raf(client, baslik, "Salon").json()
    kitap = client.post("/books", json={"title": "A", "author": "X", "shelf_id": raf["id"]}, headers=baslik).json()
    assert client.delete(f"/shelves/{raf['id']}", headers=baslik).status_code == 204
    kalan = client.get(f"/books/{kitap['id']}", headers=baslik)
    assert kalan.status_code == 200
    assert kalan.json()["shelf_id"] is None


def test_bos_ad_422(client, oturum):
    assert _raf(client, oturum(), "   ").status_code == 422


def test_giris_yoksa_401(client):
    assert client.get("/shelves").status_code == 401


def test_ayni_ad_turkce_harflerle_409(client, oturum):
    baslik = oturum()
    assert _raf(client, baslik, "İzmir").status_code == 201
    assert _raf(client, baslik, "izmir").status_code == 409
    assert _raf(client, baslik, "IŞIK").status_code == 201
    assert _raf(client, baslik, "ışık").status_code == 409
