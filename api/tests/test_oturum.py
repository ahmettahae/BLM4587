"""Yenileme token'ı (refresh), beni hatırla, çıkış ve hatalı giriş sınırı."""
from datetime import datetime, timedelta, timezone

from app import giris_siniri
from app.db import SessionLocal
from app.models import RefreshToken


def _giris(client, email, sifre, beni_hatirla=None):
    veri = {"username": email, "password": sifre}
    if beni_hatirla is not None:
        veri["remember_me"] = "true" if beni_hatirla else "false"
    return client.post("/auth/login", data=veri)


def _kalan_gun(refresh_token: str) -> float:
    from app.security import refresh_ozeti

    with SessionLocal() as db:
        kayit = db.query(RefreshToken).filter_by(token_hash=refresh_ozeti(refresh_token)).one()
        return (kayit.expires_at - datetime.now(timezone.utc)).total_seconds() / 86400


def _iptal_zamanini_geri_al(refresh_token: str, saniye: int) -> None:
    from app.security import refresh_ozeti

    with SessionLocal() as db:
        kayit = db.query(RefreshToken).filter_by(token_hash=refresh_ozeti(refresh_token)).one()
        kayit.revoked_at = kayit.revoked_at - timedelta(seconds=saniye)
        db.commit()


def test_giris_yenileme_tokeni_de_doner(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    veri = _giris(client, kullanici["email"], sifre).json()
    assert veri["refresh_token"] and veri["refresh_token"] != veri["access_token"]
    assert veri["expires_in"] > 0


def test_beni_hatirla_uzun_omurlu_yenileme_tokeni_verir(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    uzun = _giris(client, kullanici["email"], sifre, beni_hatirla=True).json()["refresh_token"]
    kisa = _giris(client, kullanici["email"], sifre, beni_hatirla=False).json()["refresh_token"]
    assert _kalan_gun(uzun) > 29
    assert _kalan_gun(kisa) < 1


def test_yenileme_yeni_token_cifti_verir_ve_eskisini_iptal_eder(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    eski = _giris(client, kullanici["email"], sifre, beni_hatirla=True).json()["refresh_token"]
    yanit = client.post("/auth/refresh", json={"refresh_token": eski})
    assert yanit.status_code == 200, yanit.text
    yeni = yanit.json()
    assert yeni["refresh_token"] != eski
    assert yeni["user"]["email"] == kullanici["email"]
    assert client.get("/me", headers={"Authorization": f"Bearer {yeni['access_token']}"}).status_code == 200
    assert _kalan_gun(yeni["refresh_token"]) > 29  # beni hatırla tercihi korunur


def test_ayni_saniyede_uretilen_erisim_tokenlari_bile_farkli(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    ilk = _giris(client, kullanici["email"], sifre).json()
    yeni = client.post("/auth/refresh", json={"refresh_token": ilk["refresh_token"]}).json()
    assert yeni["access_token"] != ilk["access_token"]


def test_kullanilmis_yenileme_tokeni_tekrar_kullanilirsa_hepsi_iptal(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    eski = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    yeni = client.post("/auth/refresh", json={"refresh_token": eski}).json()["refresh_token"]
    _iptal_zamanini_geri_al(eski, saniye=60)  # tolerans penceresinin dışı
    # Çalınmış eski token kullanılırsa: reddedilir ve kullanıcının tüm yenileme token'ları iptal olur.
    assert client.post("/auth/refresh", json={"refresh_token": eski}).status_code == 401
    assert client.post("/auth/refresh", json={"refresh_token": yeni}).status_code == 401


def test_gecersiz_ya_da_suresi_dolmus_yenileme_tokeni_401(client, kayit_ol):
    assert client.post("/auth/refresh", json={"refresh_token": "uydurma"}).status_code == 401
    kullanici, sifre = kayit_ol()
    token = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    from app.security import refresh_ozeti

    with SessionLocal() as db:
        kayit = db.query(RefreshToken).filter_by(token_hash=refresh_ozeti(token)).one()
        kayit.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
        db.commit()
    yanit = client.post("/auth/refresh", json={"refresh_token": token})
    assert yanit.status_code == 401
    assert "dolmuş" in yanit.json()["detail"]


def test_cikis_yenileme_tokenini_iptal_eder(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    token = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    assert client.post("/auth/logout", json={"refresh_token": token}).status_code == 204
    assert client.post("/auth/refresh", json={"refresh_token": token}).status_code == 401
    # Bilinmeyen token'la çıkış da sessizce başarılı olur (bilgi sızdırmaz).
    assert client.post("/auth/logout", json={"refresh_token": "yok"}).status_code == 204


def test_bes_hatali_denemeden_sonra_giris_gecici_kilitlenir(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    for _ in range(giris_siniri.EN_FAZLA_HATA):
        assert _giris(client, kullanici["email"], "yanlis-sifre-1").status_code == 401
    kilitli = _giris(client, kullanici["email"], sifre)
    assert kilitli.status_code == 429
    assert "dakika" in kilitli.json()["detail"]
    assert int(kilitli.headers["Retry-After"]) > 0


def test_kilit_suresi_dolunca_giris_acilir_ve_basari_sayaci_sifirlar(client, kayit_ol, monkeypatch):
    kullanici, sifre = kayit_ol()
    simdi = [1000.0]
    monkeypatch.setattr(giris_siniri, "_saat", lambda: simdi[0])
    for _ in range(giris_siniri.EN_FAZLA_HATA):
        _giris(client, kullanici["email"], "yanlis-sifre-1")
    assert _giris(client, kullanici["email"], sifre).status_code == 429
    simdi[0] += giris_siniri.KILIT_SANIYE + 1
    assert _giris(client, kullanici["email"], sifre).status_code == 200
    # Başarılı giriş sayacı sıfırlar: 4 hata daha kilitlemez.
    for _ in range(giris_siniri.EN_FAZLA_HATA - 1):
        _giris(client, kullanici["email"], "yanlis-sifre-1")
    assert _giris(client, kullanici["email"], sifre).status_code == 200


def test_kilit_e_posta_buyuk_kucuk_harfine_bakmaz(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    for _ in range(giris_siniri.EN_FAZLA_HATA):
        _giris(client, kullanici["email"].upper(), "yanlis-sifre-1")
    assert _giris(client, kullanici["email"], sifre).status_code == 429


# --- I2: yenileme cevabı kaybolursa kısa tolerans ---


def test_donusturulmus_token_30_saniye_icinde_tekrar_gelirse_yeni_cift_verilir(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    eski = _giris(client, kullanici["email"], sifre, beni_hatirla=True).json()["refresh_token"]
    ilk = client.post("/auth/refresh", json={"refresh_token": eski})
    assert ilk.status_code == 200
    # Cevap telefona ulaşmadı; uygulama aynı token'la tekrar dener.
    tekrar = client.post("/auth/refresh", json={"refresh_token": eski})
    assert tekrar.status_code == 200, tekrar.text
    assert tekrar.json()["refresh_token"] not in (eski, ilk.json()["refresh_token"])
    assert _kalan_gun(tekrar.json()["refresh_token"]) > 29  # beni hatırla korunur
    # Hiçbir token toptan iptal edilmedi.
    assert client.post("/auth/refresh", json={"refresh_token": ilk.json()["refresh_token"]}).status_code == 200


def test_cikisla_iptal_edilen_token_yalniz_401_doner_digerlerini_iptal_etmez(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    telefon = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    tablet = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    assert client.post("/auth/logout", json={"refresh_token": telefon}).status_code == 204
    assert client.post("/auth/refresh", json={"refresh_token": telefon}).status_code == 401
    assert client.post("/auth/refresh", json={"refresh_token": tablet}).status_code == 200


# --- M3: döndürme atomik ---


def test_dondurme_yalniz_bir_kez_basarili_olur(client, kayit_ol):
    from app.routers.auth import _dondur
    from app.security import refresh_ozeti

    kullanici, sifre = kayit_ol()
    token = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    with SessionLocal() as db:
        kayit_id = db.query(RefreshToken).filter_by(token_hash=refresh_ozeti(token)).one().id
    with SessionLocal() as db1, SessionLocal() as db2:
        assert _dondur(db1, kayit_id) is True
        db1.commit()
        assert _dondur(db2, kayit_id) is False  # eş zamanlı ikinci istek kazanamaz


# --- M4: eski token'lar budanır ---


def test_giriste_suresi_dolmus_ve_eski_iptal_tokenlar_silinir(client, kayit_ol):
    from app.security import refresh_ozeti

    kullanici, sifre = kayit_ol()
    dolmus = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    eski_iptal = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    yeni_iptal = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    gecerli = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    simdi = datetime.now(timezone.utc)
    with SessionLocal() as db:
        def bul(t):
            return db.query(RefreshToken).filter_by(token_hash=refresh_ozeti(t)).one()

        bul(dolmus).expires_at = simdi - timedelta(minutes=1)
        bul(eski_iptal).revoked_at = simdi - timedelta(days=2)
        bul(yeni_iptal).revoked_at = simdi - timedelta(hours=1)
        db.commit()
    assert _giris(client, kullanici["email"], sifre).status_code == 200
    with SessionLocal() as db:
        kalanlar = {k.token_hash for k in db.query(RefreshToken).filter_by(user_id=kullanici["id"])}
    assert refresh_ozeti(dolmus) not in kalanlar
    assert refresh_ozeti(eski_iptal) not in kalanlar
    assert refresh_ozeti(yeni_iptal) in kalanlar  # çalınma tespiti için 1 gün tutulur
    assert refresh_ozeti(gecerli) in kalanlar


# --- I3: kilit anahtarı (e-posta, IP) + IP başına genel sınır ---


def test_baska_ipden_dogru_sifre_kilide_takilmaz(kayit_ol):
    from fastapi.testclient import TestClient

    from app.main import app

    saldirgan = TestClient(app, client=("10.0.0.1", 1))
    sahibi = TestClient(app, client=("10.0.0.2", 1))
    kullanici, sifre = kayit_ol()
    for _ in range(giris_siniri.EN_FAZLA_HATA):
        _giris(saldirgan, kullanici["email"], "yanlis-sifre-1")
    assert _giris(saldirgan, kullanici["email"], sifre).status_code == 429
    assert _giris(sahibi, kullanici["email"], sifre).status_code == 200


def test_bir_ipden_cok_hata_farkli_epostalarla_da_kilitler(kayit_ol, yeni_eposta):
    from fastapi.testclient import TestClient

    from app.main import app

    saldirgan = TestClient(app, client=("10.0.0.3", 1))
    for _ in range(giris_siniri.IP_EN_FAZLA_HATA):
        assert _giris(saldirgan, yeni_eposta(), "yanlis-sifre-1").status_code == 401
    kullanici, sifre = kayit_ol()
    assert _giris(saldirgan, kullanici["email"], sifre).status_code == 429
    # Başka IP etkilenmez.
    assert _giris(TestClient(app, client=("10.0.0.4", 1)), kullanici["email"], sifre).status_code == 200


def test_eski_sayaclar_budanir(monkeypatch):
    simdi = [5000.0]
    monkeypatch.setattr(giris_siniri, "_saat", lambda: simdi[0])
    giris_siniri.hata_kaydet("eski@ornek.com", "10.9.9.9")
    simdi[0] += giris_siniri.PENCERE_SANIYE + giris_siniri.KILIT_SANIYE + 1
    giris_siniri.hata_kaydet("yeni@ornek.com", "10.9.9.8")
    assert ("eski@ornek.com", "10.9.9.9") not in giris_siniri._hatalar
    assert "10.9.9.9" not in giris_siniri._ip_hatalar


# --- İnceleme düzeltmeleri ---


def test_tolerans_her_token_icin_yalniz_bir_kez(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    eski = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    assert client.post("/auth/refresh", json={"refresh_token": eski}).status_code == 200
    assert client.post("/auth/refresh", json={"refresh_token": eski}).status_code == 200  # cevap kayboldu
    # Üçüncü kez gelirse çalınma sayılır.
    assert client.post("/auth/refresh", json={"refresh_token": eski}).status_code == 401


def test_toplu_iptalden_sonra_yeni_dondurulmus_token_toleranstan_yararlanamaz(client, kayit_ol):
    kullanici, sifre = kayit_ol()
    t0 = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    a1 = client.post("/auth/refresh", json={"refresh_token": t0}).json()["refresh_token"]
    _iptal_zamanini_geri_al(t0, saniye=60)
    client.post("/auth/refresh", json={"refresh_token": a1})  # saldırgan a1'i döndürdü (a1 artık son 30 sn'de döndürülmüş)
    # Gerçek istemci eski t0'ı gönderir: çalınma tespit edilir.
    assert client.post("/auth/refresh", json={"refresh_token": t0}).status_code == 401
    # Saldırgan a1'le tolerans penceresinden yeni çift alamaz.
    assert client.post("/auth/refresh", json={"refresh_token": a1}).status_code == 401


def test_dondurulmus_token_gunler_sonra_gelse_de_calinma_tespit_edilir(client, kayit_ol):
    from app.security import refresh_ozeti

    kullanici, sifre = kayit_ol()
    t0 = _giris(client, kullanici["email"], sifre, beni_hatirla=True).json()["refresh_token"]
    a1 = client.post("/auth/refresh", json={"refresh_token": t0}).json()["refresh_token"]
    _iptal_zamanini_geri_al(t0, saniye=2 * 86400)
    assert _giris(client, kullanici["email"], sifre).status_code == 200  # budama çalışır
    with SessionLocal() as db:
        assert db.query(RefreshToken).filter_by(token_hash=refresh_ozeti(t0)).count() == 1
    assert client.post("/auth/refresh", json={"refresh_token": t0}).status_code == 401
    assert client.post("/auth/refresh", json={"refresh_token": a1}).status_code == 401


def test_yenilemede_de_eski_tokenlar_budanir(client, kayit_ol):
    from app.security import refresh_ozeti

    kullanici, sifre = kayit_ol()
    dolmus = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    aktif = _giris(client, kullanici["email"], sifre).json()["refresh_token"]
    with SessionLocal() as db:
        kayit = db.query(RefreshToken).filter_by(token_hash=refresh_ozeti(dolmus)).one()
        kayit.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
        db.commit()
    assert client.post("/auth/refresh", json={"refresh_token": aktif}).status_code == 200
    with SessionLocal() as db:
        assert db.query(RefreshToken).filter_by(token_hash=refresh_ozeti(dolmus)).count() == 0


def test_olmayan_kullanicida_da_sifre_dogrulamasi_calisir(client, yeni_eposta, monkeypatch):
    """Kayıtlı olmayan e-posta hızlı cevaptan ayırt edilemesin (zamanlama farkı)."""
    from app.routers import auth

    cagrilar = []
    gercek = auth.verify_password
    monkeypatch.setattr(auth, "verify_password", lambda s, h: cagrilar.append(h) or gercek(s, h))
    assert _giris(client, yeni_eposta(), "yanlis-sifre-1").status_code == 401
    assert len(cagrilar) == 1
