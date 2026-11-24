import logging
import os
import sys

from fastapi import Depends, FastAPI
from sqlalchemy import text
from sqlalchemy.orm import Session

from app import hatalar
from app.db import get_db
from app.routers import admin, auth, books, categories, shelves

ACIKLAMA = """
Kişisel kitap koleksiyonu için Web API (BLM4587 dönem projesi).

**Nasıl denenir:** sağ üstteki **Authorize** düğmesine e-posta (`username`) ve şifreyi yaz.
Uçlar giriş yapan kullanıcının kendi verisini döner; kategori yazma uçları yalnız yöneticiye açıktır.

**Hata biçimi:** her hata `{"detail": "...", "kod": 404, "hatalar": [{"alan": "...", "mesaj": "..."}]}` döner.
"""

ETIKETLER = [
    {"name": "kimlik", "description": "Kayıt, giriş, oturum yenileme ve çıkış"},
    {"name": "kitaplar", "description": "Kitap ekleme, listeleme (arama, filtre, sıralama, sayfalama), güncelleme, silme"},
    {"name": "kategoriler", "description": "Herkes okur, yalnız yönetici yazar"},
    {"name": "raflar", "description": "Kullanıcının kendi rafları"},
    {"name": "yönetici", "description": "Yalnız yönetici rolüne açık uçlar"},
    {"name": "sistem", "description": "Sağlık kontrolü"},
]

app = FastAPI(title="Kitaplığım API", version="0.6.0", description=ACIKLAMA, openapi_tags=ETIKETLER)
hatalar.kur(app)
logging.getLogger("kitapligim").setLevel(logging.INFO)
# Testlerde ve KITAPLIGIM_LOG_KAPALI=1 iken dosyaya log yazılmaz.
if "pytest" not in sys.modules and not os.environ.get("KITAPLIGIM_LOG_KAPALI"):
    hatalar.dosya_logunu_ac()

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(books.router)
app.include_router(categories.router)
app.include_router(shelves.router)


@app.get("/health", tags=["sistem"], summary="Sağlık kontrolü")
def health(db: Session = Depends(get_db)) -> dict[str, str]:
    """API'nin ve veritabanı bağlantısının çalıştığını gösterir."""
    db.execute(text("SELECT 1"))
    return {"durum": "ok"}
