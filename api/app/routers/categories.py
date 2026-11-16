from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user, require_admin
from app.models import Book, Category, User
from app.schemas import CategoryIn, CategoryOut

router = APIRouter(prefix="/categories", tags=["kategoriler"])

_TR_ALFABE = "abcçdefgğhıijklmnoöprsştuüvyz"
_TR_SIRA = {harf: i for i, harf in enumerate(_TR_ALFABE)}


def _tr_sirala(ad: str) -> list[int]:
    """Türkçe alfabe sırası (Ç, Ğ, İ, Ö, Ş, Ü kendi yerinde). Veritabanı sıralaması bunu bilmediği için Python'da yapılır."""
    kucuk = ad.replace("İ", "i").replace("I", "ı").lower()
    return [_TR_SIRA.get(h, 100 + ord(h)) for h in kucuk]


def _cikti(db: Session, kategori: Category) -> CategoryOut:
    adet = db.scalar(select(func.count()).select_from(Book).where(Book.category_id == kategori.id)) or 0
    return CategoryOut(id=kategori.id, name=kategori.name, description=kategori.description, book_count=adet)


def _ayni_ad_var_mi(db: Session, ad: str, haric_id: int | None = None) -> bool:
    """Büyük/küçük harfe bakmadan aynı adlı başka kategori var mı?"""
    hedef = ad.casefold()
    return any(c.id != haric_id and c.name.casefold() == hedef for c in db.scalars(select(Category)))


def _bul(db: Session, kategori_id: int) -> Category:
    kategori = db.get(Category, kategori_id)
    if kategori is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kategori bulunamadı")
    return kategori


@router.get("", response_model=list[CategoryOut])
def listele(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[CategoryOut]:
    """Tüm kategoriler (giriş yapan herkes görür), Türkçe alfabe sırasıyla; kitap sayısıyla birlikte."""
    adetler = dict(db.execute(select(Book.category_id, func.count()).group_by(Book.category_id)).all())
    kategoriler = sorted(db.scalars(select(Category)), key=lambda c: _tr_sirala(c.name))
    return [
        CategoryOut(id=c.id, name=c.name, description=c.description, book_count=adetler.get(c.id, 0))
        for c in kategoriler
    ]


@router.post("", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
def ekle(veri: CategoryIn, admin: User = Depends(require_admin), db: Session = Depends(get_db)) -> CategoryOut:
    if _ayni_ad_var_mi(db, veri.name):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bu adda bir kategori zaten var")
    kategori = Category(name=veri.name, description=veri.description)
    db.add(kategori)
    try:
        db.commit()
    except IntegrityError:  # aynı anda gelen iki istek için
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bu adda bir kategori zaten var")
    db.refresh(kategori)
    return _cikti(db, kategori)


@router.put("/{kategori_id}", response_model=CategoryOut)
def guncelle(
    kategori_id: int, veri: CategoryIn, admin: User = Depends(require_admin), db: Session = Depends(get_db)
) -> CategoryOut:
    kategori = _bul(db, kategori_id)
    if _ayni_ad_var_mi(db, veri.name, haric_id=kategori.id):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bu adda bir kategori zaten var")
    kategori.name = veri.name
    kategori.description = veri.description
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bu adda bir kategori zaten var")
    db.refresh(kategori)
    return _cikti(db, kategori)


@router.delete("/{kategori_id}", status_code=status.HTTP_204_NO_CONTENT)
def sil(kategori_id: int, admin: User = Depends(require_admin), db: Session = Depends(get_db)) -> Response:
    """Kategoriyi siler; bu kategorideki kitaplar silinmez, kategorisiz kalır."""
    kategori = _bul(db, kategori_id)
    db.delete(kategori)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
