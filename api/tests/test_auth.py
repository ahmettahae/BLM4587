def test_kayit_basarili_sifre_dondurulmez(kayit_ol):
    kullanici, _ = kayit_ol(display_name="  Ayşe  ")
    assert kullanici["role"] == "user"
    assert kullanici["display_name"] == "Ayşe"
    assert "password" not in kullanici and "password_hash" not in kullanici


def test_ayni_eposta_ikinci_kez_kayit_olamaz(client, kayit_ol):
    kullanici, _ = kayit_ol()
    yanit = client.post(
        "/auth/register",
        json={"email": kullanici["email"].upper(), "password": "baska-sifre-123", "display_name": "Başka"},
    )
    assert yanit.status_code == 409


def test_gecersiz_kayit_verisi_reddedilir(client, yeni_eposta):
    assert client.post("/auth/register", json={"email": "eposta-degil", "password": "gizli-sifre-123", "display_name": "A"}).status_code == 422
    assert client.post("/auth/register", json={"email": yeni_eposta(), "password": "kisa", "display_name": "A"}).status_code == 422
    assert client.post("/auth/register", json={"email": yeni_eposta(), "password": "gizli-sifre-123", "display_name": "   "}).status_code == 422


def test_kayitta_rol_kendi_kendine_yonetici_yapilamaz(client, yeni_eposta):
    yanit = client.post(
        "/auth/register",
        json={"email": yeni_eposta(), "password": "gizli-sifre-123", "display_name": "Hileci", "role": "admin"},
    )
    assert yanit.status_code == 201
    assert yanit.json()["role"] == "user"


def test_giris_basarili_token_ve_kullanici_doner(kayit_ol, giris_yap):
    kullanici, sifre = kayit_ol()
    yanit = giris_yap(kullanici["email"].upper(), sifre)  # e-posta büyük/küçük harfe duyarsız
    assert yanit.status_code == 200
    veri = yanit.json()
    assert veri["token_type"] == "bearer" and veri["access_token"]
    assert veri["user"]["email"] == kullanici["email"]


def test_yanlis_sifre_ve_bilinmeyen_kullanici_401(kayit_ol, giris_yap, yeni_eposta):
    kullanici, _ = kayit_ol()
    assert giris_yap(kullanici["email"], "yanlis-sifre").status_code == 401
    assert giris_yap(yeni_eposta(), "gizli-sifre-123").status_code == 401


def test_me_token_ile_calisir(client, kayit_ol, giris_yap):
    kullanici, sifre = kayit_ol()
    token = giris_yap(kullanici["email"], sifre).json()["access_token"]
    yanit = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert yanit.status_code == 200
    assert yanit.json()["id"] == kullanici["id"]


def test_me_tokensiz_ya_da_bozuk_tokenla_401(client):
    assert client.get("/me").status_code == 401
    assert client.get("/me", headers={"Authorization": "Bearer bozuk.token.degeri"}).status_code == 401


def test_yonetici_ucu_rol_kontrolu(client, kayit_ol, giris_yap, yonetici_yap):
    kullanici, sifre = kayit_ol()
    token = giris_yap(kullanici["email"], sifre).json()["access_token"]
    baslik = {"Authorization": f"Bearer {token}"}

    assert client.get("/admin/ping").status_code == 401
    assert client.get("/admin/ping", headers=baslik).status_code == 403

    yonetici_yap(kullanici["email"])
    assert client.get("/admin/ping", headers=baslik).status_code == 200
