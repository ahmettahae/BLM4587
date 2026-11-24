"""Swagger belgesi: her uçta Türkçe başlık, giriş gövdelerinde örnek, açıklama ve etiketler."""

BEKLENEN = {
    ("post", "/auth/register"): "Kayıt ol",
    ("post", "/auth/login"): "Giriş yap",
    ("post", "/auth/refresh"): "Oturumu yenile",
    ("post", "/auth/logout"): "Çıkış yap",
    ("get", "/me"): "Ben kimim",
    ("get", "/admin/ping"): "Yönetici kontrolü",
    ("get", "/books"): "Kitaplarımı listele",
    ("post", "/books"): "Kitap ekle",
    ("get", "/books/summary"): "Okuma özeti",
    ("get", "/books/{book_id}"): "Kitabı getir",
    ("put", "/books/{book_id}"): "Kitabı güncelle",
    ("delete", "/books/{book_id}"): "Kitabı sil",
    ("get", "/categories"): "Kategorileri listele",
    ("post", "/categories"): "Kategori ekle (yönetici)",
    ("put", "/categories/{kategori_id}"): "Kategoriyi güncelle (yönetici)",
    ("delete", "/categories/{kategori_id}"): "Kategoriyi sil (yönetici)",
    ("get", "/shelves"): "Raflarımı listele",
    ("post", "/shelves"): "Raf ekle",
    ("put", "/shelves/{raf_id}"): "Rafı yeniden adlandır",
    ("delete", "/shelves/{raf_id}"): "Rafı sil",
    ("get", "/health"): "Sağlık kontrolü",
}


def test_her_ucun_turkce_basligi_var(client):
    belge = client.get("/openapi.json").json()
    bulunan = {
        (yontem, yol): islem["summary"]
        for yol, islemler in belge["paths"].items()
        for yontem, islem in islemler.items()
    }
    assert bulunan == BEKLENEN


def test_giris_govdelerinde_ornek_var(client):
    semalar = client.get("/openapi.json").json()["components"]["schemas"]
    for ad in ["RegisterIn", "BookIn", "CategoryIn", "ShelfIn", "RefreshIn"]:
        assert semalar[ad].get("examples"), f"{ad} için örnek yok"


def test_aciklama_ve_etiketler(client):
    belge = client.get("/openapi.json").json()
    assert "Authorize" in belge["info"]["description"]
    assert {e["name"] for e in belge["tags"]} >= {"kimlik", "kitaplar", "kategoriler", "raflar"}
