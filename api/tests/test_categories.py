def test_giris_yapmadan_kategoriye_erisilemez(client):
    assert client.get("/categories").status_code == 401
    assert client.post("/categories", json={"name": "X"}).status_code == 401


def test_normal_kullanici_listeleyebilir_ama_yazamaz(client, oturum, kategori_adi):
    kullanici = oturum()
    assert client.get("/categories", headers=kullanici).status_code == 200
    assert client.post("/categories", json={"name": kategori_adi("Roman")}, headers=kullanici).status_code == 403
    assert client.put("/categories/1", json={"name": kategori_adi("Roman")}, headers=kullanici).status_code == 403
    assert client.delete("/categories/1", headers=kullanici).status_code == 403


def test_yonetici_kategori_ekler_ve_herkes_gorur(client, oturum, yonetici_oturumu, kategori_adi):
    yonetici = yonetici_oturumu()
    yanit = client.post(
        "/categories", json={"name": f"  {kategori_adi('Roman')}  ", "description": "  Kurgu  "}, headers=yonetici
    )
    assert yanit.status_code == 201, yanit.text
    kategori = yanit.json()
    assert kategori["name"] == kategori_adi("Roman")  # kenar boşlukları atılır
    assert kategori["description"] == "Kurgu"
    assert kategori["book_count"] == 0

    adlar = [k["name"] for k in client.get("/categories", headers=oturum()).json()]
    assert kategori_adi("Roman") in adlar


def test_gecersiz_ad_reddedilir(client, yonetici_oturumu):
    yonetici = yonetici_oturumu()
    assert client.post("/categories", json={"name": "   "}, headers=yonetici).status_code == 422
    assert client.post("/categories", json={"name": "x" * 101}, headers=yonetici).status_code == 422
    assert client.post("/categories", json={}, headers=yonetici).status_code == 422


def test_ayni_ad_buyuk_kucuk_harfe_bakmadan_reddedilir(client, yonetici_oturumu, kategori_adi):
    yonetici = yonetici_oturumu()
    assert client.post("/categories", json={"name": kategori_adi("Bilim")}, headers=yonetici).status_code == 201
    ayni = client.post("/categories", json={"name": kategori_adi("bilim").upper()}, headers=yonetici)
    assert ayni.status_code == 409


def test_liste_turkce_alfabe_sirasinda(client, yonetici_oturumu, kategori_adi):
    yonetici = yonetici_oturumu()
    for ad in ["Şiir", "Roman", "Çocuk", "Bilim", "Ömür"]:
        assert client.post("/categories", json={"name": kategori_adi(ad)}, headers=yonetici).status_code == 201
    liste = [k["name"].removeprefix(kategori_adi("")) for k in client.get("/categories", headers=yonetici).json()]
    sirali = [ad for ad in liste if ad in {"Şiir", "Roman", "Çocuk", "Bilim", "Ömür"}]
    assert sirali == ["Bilim", "Çocuk", "Ömür", "Roman", "Şiir"]


def test_kategori_guncelle(client, yonetici_oturumu, kategori_adi):
    yonetici = yonetici_oturumu()
    a = client.post("/categories", json={"name": kategori_adi("A")}, headers=yonetici).json()
    b = client.post("/categories", json={"name": kategori_adi("B")}, headers=yonetici).json()

    ok = client.put(f"/categories/{a['id']}", json={"name": kategori_adi("A2"), "description": "yeni"}, headers=yonetici)
    assert ok.status_code == 200
    assert ok.json()["name"] == kategori_adi("A2") and ok.json()["description"] == "yeni"

    # kendi adını tekrar göndermek çakışma sayılmaz
    assert client.put(f"/categories/{a['id']}", json={"name": kategori_adi("A2")}, headers=yonetici).status_code == 200
    # başkasının adı çakışır
    assert client.put(f"/categories/{b['id']}", json={"name": kategori_adi("A2")}, headers=yonetici).status_code == 409
    assert client.put("/categories/999999", json={"name": kategori_adi("Z")}, headers=yonetici).status_code == 404


def test_kategori_silinince_kitaplar_kategorisiz_kalir(client, oturum, yonetici_oturumu, kategori_adi):
    yonetici, okur = yonetici_oturumu(), oturum()
    kategori = client.post("/categories", json={"name": kategori_adi("Tarih")}, headers=yonetici).json()

    kitap = client.post(
        "/books", json={"title": "Nutuk", "author": "M. K. Atatürk", "category_id": kategori["id"]}, headers=okur
    )
    assert kitap.status_code == 201, kitap.text
    assert kitap.json()["category_id"] == kategori["id"]

    liste = {k["id"]: k for k in client.get("/categories", headers=okur).json()}
    assert liste[kategori["id"]]["book_count"] == 1

    assert client.delete(f"/categories/{kategori['id']}", headers=yonetici).status_code == 204
    assert client.delete(f"/categories/{kategori['id']}", headers=yonetici).status_code == 404
    assert client.get(f"/books/{kitap.json()['id']}", headers=okur).json()["category_id"] is None


def test_olmayan_kategoriyle_kitap_eklenemez(client, oturum):
    yanit = client.post("/books", json={"title": "X", "author": "Y", "category_id": 999999}, headers=oturum())
    assert yanit.status_code == 422
