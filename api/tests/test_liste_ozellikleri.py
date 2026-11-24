"""Kitap listesinde sayfalama, sıralama ve okuma özeti."""


def _ekle(client, oturum, **alanlar):
    govde = {"title": "Kitap", "author": "Yazar", **alanlar}
    yanit = client.post("/books", json=govde, headers=oturum)
    assert yanit.status_code == 201, yanit.text
    return yanit.json()


def _basliklar(yanit):
    return [k["title"] for k in yanit.json()]


def test_sayfalama_limit_offset_ve_toplam_basligi(client, oturum):
    o = oturum()
    for i in range(5):
        _ekle(client, o, title=f"K{i}")
    ilk = client.get("/books?limit=2", headers=o)
    assert ilk.status_code == 200
    assert _basliklar(ilk) == ["K4", "K3"]
    assert ilk.headers["X-Total-Count"] == "5"
    assert _basliklar(client.get("/books?limit=2&offset=2", headers=o)) == ["K2", "K1"]
    assert _basliklar(client.get("/books?limit=2&offset=4", headers=o)) == ["K0"]
    assert client.get("/books?limit=2&offset=10", headers=o).json() == []


def test_toplam_filtre_ve_aramadan_sonra_sayilir(client, oturum):
    o = oturum()
    _ekle(client, o, title="İstanbul Hatırası")
    _ekle(client, o, title="Başka")
    _ekle(client, o, title="istanbul rehberi")
    yanit = client.get("/books?search=istanbul&limit=1", headers=o)
    assert len(yanit.json()) == 1
    assert yanit.headers["X-Total-Count"] == "2"


def test_gecersiz_sayfalama_degerleri_422(client, oturum):
    o = oturum()
    assert client.get("/books?limit=0", headers=o).status_code == 422
    assert client.get("/books?limit=201", headers=o).status_code == 422
    assert client.get("/books?offset=-1", headers=o).status_code == 422


def test_varsayilan_limit_50(client, oturum):
    o = oturum()
    for i in range(52):
        _ekle(client, o, title=f"K{i}")
    yanit = client.get("/books", headers=o)
    assert len(yanit.json()) == 50
    assert yanit.headers["X-Total-Count"] == "52"


def test_basliga_gore_turkce_siralama(client, oturum):
    o = oturum()
    for baslik in ["Şeker Portakalı", "Çalıkuşu", "Zeytindağı", "İnce Memed", "ırmak", "Cosmos"]:
        _ekle(client, o, title=baslik)
    assert _basliklar(client.get("/books?sort=baslik", headers=o)) == [
        "Cosmos", "Çalıkuşu", "ırmak", "İnce Memed", "Şeker Portakalı", "Zeytindağı",
    ]


def test_yazara_eskiye_ve_puana_gore_siralama(client, oturum):
    o = oturum()
    _ekle(client, o, title="A", author="Orhan", rating=3)
    _ekle(client, o, title="B", author="Ahmet")
    _ekle(client, o, title="C", author="Ümit", rating=5)
    assert _basliklar(client.get("/books?sort=yazar", headers=o)) == ["B", "A", "C"]
    assert _basliklar(client.get("/books?sort=eski", headers=o)) == ["A", "B", "C"]
    assert _basliklar(client.get("/books?sort=yeni", headers=o)) == ["C", "B", "A"]
    # Puanı olmayanlar sonda.
    assert _basliklar(client.get("/books?sort=puan", headers=o)) == ["C", "A", "B"]
    assert client.get("/books?sort=rastgele", headers=o).status_code == 422


def test_ozet_durumlara_gore_sayar_ve_yalniz_kendi_kitaplarini(client, oturum):
    o = oturum()
    baska = oturum()
    _ekle(client, o, status="okundu")
    _ekle(client, o, status="okundu")
    _ekle(client, o, status="okunuyor")
    _ekle(client, o)
    _ekle(client, baska, status="okundu")
    yanit = client.get("/books/summary", headers=o)
    assert yanit.status_code == 200
    assert yanit.json() == {"toplam": 4, "okunacak": 1, "okunuyor": 1, "okundu": 2}


def test_ozet_bos_kutuphanede_sifir(client, oturum):
    assert client.get("/books/summary", headers=oturum()).json() == {
        "toplam": 0, "okunacak": 0, "okunuyor": 0, "okundu": 0,
    }


def test_ozet_giris_ister(client):
    assert client.get("/books/summary").status_code == 401
