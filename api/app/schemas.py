from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class RegisterIn(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={"examples": [{"email": "ayse@ornek.com", "password": "uzun-bir-sifre", "display_name": "Ayşe"}]}
    )

    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=100)

    @field_validator("display_name")
    @classmethod
    def ad_bos_olmasin(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Görünen ad boş olamaz")
        return v


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    display_name: str
    role: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int = Field(description="Erişim token'ının ömrü (saniye)")
    refresh_token: str = Field(description="Erişim token'ı dolunca /auth/refresh ile yenisini almak için")
    user: UserOut


class KitapOzeti(BaseModel):
    toplam: int
    okunacak: int
    okunuyor: int
    okundu: int


class RefreshIn(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [{"refresh_token": "girişte dönen refresh_token değeri"}]})

    refresh_token: str = Field(min_length=1, max_length=200)


# ---------- Kitaplar (Hafta 3) ----------

KitapDurumu = Literal["okunacak", "okunuyor", "okundu"]


def _bos_ise_none(v: str | None) -> str | None:
    """Kenar boşluklarını atar; boş kalan isteğe bağlı metni None yapar."""
    if v is None:
        return None
    v = v.strip()
    return v or None


def isbn_normalize(v: str | None) -> str | None:
    """Tire ve boşlukları atar; 10 (son hane X olabilir) ya da 13 haneli değilse hata verir."""
    v = _bos_ise_none(v)
    if v is None:
        return None
    v = v.replace("-", "").replace(" ", "").upper()
    if len(v) == 13 and v.isdigit():
        return v
    if len(v) == 10 and v[:9].isdigit() and (v[9].isdigit() or v[9] == "X"):
        return v
    raise ValueError("ISBN 10 ya da 13 haneli olmalı")


class BookIn(BaseModel):
    """Kitap ekleme ve güncelleme (PUT tüm alanları yeniden yazar)."""

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "title": "Kürk Mantolu Madonna",
                    "author": "Sabahattin Ali",
                    "publisher": "YKY",
                    "year": 1943,
                    "pages": 160,
                    "status": "okundu",
                    "rating": 5,
                    "note": "Raif Efendi'nin defteri.",
                    "category_id": None,
                    "shelf_id": None,
                }
            ]
        }
    )

    title: str = Field(max_length=255)
    author: str = Field(max_length=255)
    isbn: str | None = Field(default=None, max_length=20)
    publisher: str | None = Field(default=None, max_length=255)
    year: int | None = Field(default=None, ge=1)
    pages: int | None = Field(default=None, ge=1, le=50000)
    note: str | None = Field(default=None, max_length=2000)
    status: KitapDurumu = "okunacak"
    rating: int | None = Field(default=None, ge=1, le=5)
    category_id: int | None = None
    shelf_id: int | None = None

    @field_validator("title", "author")
    @classmethod
    def zorunlu_metin(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Boş olamaz")
        return v

    @field_validator("publisher", "note")
    @classmethod
    def istege_bagli_metin(cls, v: str | None) -> str | None:
        return _bos_ise_none(v)

    @field_validator("isbn")
    @classmethod
    def isbn_dogrula(cls, v: str | None) -> str | None:
        return isbn_normalize(v)

    @field_validator("year")
    @classmethod
    def yil_gelecekte_olmasin(cls, v: int | None) -> int | None:
        if v is not None and v > date.today().year + 1:
            raise ValueError("Basım yılı gelecekte olamaz")
        return v


class BookOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    author: str
    isbn: str | None
    publisher: str | None
    year: int | None
    pages: int | None
    note: str | None
    status: str
    rating: int | None
    category_id: int | None
    shelf_id: int | None
    cover_path: str | None
    created_at: datetime


# ---------- Kategoriler (Hafta 4) ----------


class CategoryIn(BaseModel):
    """Kategori ekleme ve güncelleme; yalnızca yönetici gönderebilir."""

    model_config = ConfigDict(json_schema_extra={"examples": [{"name": "Roman", "description": "Uzun anlatı türü"}]})

    name: str = Field(max_length=100)
    description: str | None = Field(default=None, max_length=1000)

    @field_validator("name")
    @classmethod
    def ad_bos_olmasin(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Ad boş olamaz")
        return v

    @field_validator("description")
    @classmethod
    def aciklama_bos_ise_none(cls, v: str | None) -> str | None:
        return _bos_ise_none(v)


class CategoryOut(BaseModel):
    id: int
    name: str
    description: str | None
    book_count: int = 0


# ---------- Raflar (Hafta 5) ----------


class ShelfIn(BaseModel):
    """Raf ekleme ve yeniden adlandırma; raf yalnızca sahibine aittir."""

    model_config = ConfigDict(json_schema_extra={"examples": [{"name": "Salon"}]})

    name: str = Field(max_length=100)

    @field_validator("name")
    @classmethod
    def ad_bos_olmasin(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Ad boş olamaz")
        return v


class ShelfOut(BaseModel):
    id: int
    name: str
    book_count: int = 0
