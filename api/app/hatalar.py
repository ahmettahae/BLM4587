"""Tek hata biçimi ve istek loglama.

Her hata şu biçimde döner (mobil uygulama `detail`'i gösterir, `hatalar`'ı alanların altına yazar):

    {"detail": "Türkçe mesaj", "kod": 422, "hatalar": [{"alan": "title", "mesaj": "Bu alan zorunlu"}]}
"""
import logging
import time
from logging.handlers import RotatingFileHandler
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

istek_log = logging.getLogger("kitapligim.istek")
hata_log = logging.getLogger("kitapligim.hata")

LOG_KLASORU = Path(__file__).resolve().parent.parent / "logs"


# Starlette'ın kendi ürettiği İngilizce mesajlar (bilinmeyen adres, yanlış yöntem).
_STARLETTE_MESAJLARI = {
    "Not Found": "Adres bulunamadı",
    "Method Not Allowed": "Bu yöntem bu adreste kullanılamaz",
}


def _govde(kod: int, mesaj: str, hatalar: list[dict] | None = None) -> dict:
    return {"detail": mesaj, "kod": kod, "hatalar": hatalar or []}


def _alan_adi(konum: tuple) -> str:
    # ("body", "author") -> "author"; ("query", "limit") -> "limit"
    parcalar = [str(p) for p in konum if p not in ("body", "query", "path", "header")]
    return ".".join(parcalar) or "istek"


def turkce_mesaj(hata: dict) -> str:
    """Pydantic doğrulama hatasını kısa Türkçe cümleye çevirir."""
    tur = hata.get("type", "")
    ctx = hata.get("ctx") or {}
    if tur == "missing":
        return "Bu alan zorunlu"
    if tur == "string_too_long":
        return f"En fazla {ctx.get('max_length')} karakter olabilir"
    if tur == "string_too_short":
        return "Bu alan boş olamaz" if ctx.get("min_length") == 1 else f"En az {ctx.get('min_length')} karakter olmalı"
    if tur == "less_than_equal":
        return f"En fazla {ctx.get('le')} olabilir"
    if tur == "greater_than_equal":
        return f"En az {ctx.get('ge')} olmalı"
    if tur in ("int_parsing", "int_type", "int_from_float"):
        return "Tam sayı olmalı"
    if tur in ("literal_error", "enum"):
        return f"Geçersiz değer; izin verilenler: {ctx.get('expected', '')}".rstrip(": ")
    if tur in ("bool_parsing", "bool_type"):
        return "true ya da false olmalı"
    if tur == "value_error":
        # Kendi doğrulayıcılarımızın mesajları zaten Türkçe; Pydantic'in önekini at.
        return str(hata.get("msg", "")).removeprefix("Value error, ")
    return str(hata.get("msg", "Geçersiz değer"))


def kur(app: FastAPI) -> None:
    """Hata işleyicilerini ve istek loglamasını uygulamaya bağlar."""

    @app.exception_handler(StarletteHTTPException)
    async def http_hatasi(_istek: Request, hata: StarletteHTTPException) -> JSONResponse:
        mesaj = hata.detail if isinstance(hata.detail, str) else "İstek işlenemedi"
        mesaj = _STARLETTE_MESAJLARI.get(mesaj, mesaj)
        return JSONResponse(_govde(hata.status_code, mesaj), status_code=hata.status_code, headers=hata.headers)

    @app.exception_handler(RequestValidationError)
    async def dogrulama_hatasi(_istek: Request, hata: RequestValidationError) -> JSONResponse:
        hatalar = [{"alan": _alan_adi(h.get("loc", ())), "mesaj": turkce_mesaj(h)} for h in hata.errors()]
        return JSONResponse(_govde(422, "Girdiğin bilgileri kontrol et", hatalar), status_code=422)

    @app.exception_handler(Exception)
    async def beklenmeyen_hata(istek: Request, hata: Exception) -> JSONResponse:
        hata_log.exception("Beklenmeyen hata: %s %s", istek.method, istek.url.path)
        return JSONResponse(_govde(500, "Sunucuda beklenmeyen bir hata oluştu"), status_code=500)

    @app.middleware("http")
    async def istek_kaydi(istek: Request, sonraki):
        baslangic = time.perf_counter()
        durum = 500
        try:
            cevap = await sonraki(istek)
            durum = cevap.status_code
            return cevap
        finally:
            sure = (time.perf_counter() - baslangic) * 1000
            # Yalnız yöntem, yol, durum ve süre; başlıklar (token) ve gövde (şifre) loglanmaz.
            istek_log.info("%s %s %d %.1fms", istek.method, istek.url.path, durum, sure)


def dosya_logunu_ac() -> None:
    """logs/api.log'a döner dosyalı log (1 MB x 5). Testlerde açılmaz."""
    LOG_KLASORU.mkdir(exist_ok=True)
    isleyici = RotatingFileHandler(LOG_KLASORU / "api.log", maxBytes=1_000_000, backupCount=5, encoding="utf-8")
    isleyici.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s"))
    kok = logging.getLogger("kitapligim")
    kok.setLevel(logging.INFO)
    if not any(isinstance(h, RotatingFileHandler) for h in kok.handlers):
        kok.addHandler(isleyici)
