from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.metin import tr_esle, tr_sirala
from app.models import Book, Shelf, User
from app.schemas import ShelfIn, ShelfOut

router = APIRouter(prefix="/shelves", tags=["raflar"])

_AYNI_AD = "Bu adda bir raf zaten var"


def _kendi_rafi(raf_id: int, user: User, db: Session) -> Shelf:
    """Rafı yalnızca sahibine verir. Başkasının rafı da 'bulunamadı' döner (varlığı sızdırılmaz)."""
    raf = db.get(Shelf, raf_id)
    if raf is None or raf.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Raf bulunamadı")
    return raf


def _ayni_ad_var_mi(db: Session, user: User, ad: str, haric_id: int | None = None) -> bool:
    """Kullanıcının kendi rafları içinde, büyük/küçük harfe bakmadan aynı ad var mı?"""
    hedef = tr_esle(ad)
    raflar = db.scalars(select(Shelf).where(Shelf.user_id == user.id))
    return any(r.id != haric_id and tr_esle(r.name) == hedef for r in raflar)


def _cikti(db: Session, raf: Shelf) -> ShelfOut:
    adet = db.scalar(select(func.count()).select_from(Book).where(Book.shelf_id == raf.id)) or 0
    return ShelfOut(id=raf.id, name=raf.name, book_count=adet)


def _kaydet(db: Session) -> None:
    try:
        db.commit()
    except IntegrityError:  # aynı anda gelen iki istek için
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=_AYNI_AD)


@router.get("", response_model=list[ShelfOut])
def listele(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[ShelfOut]:
    """Kullanıcının rafları, Türkçe alfabe sırasıyla; her rafın kitap sayısıyla birlikte."""
    adetler = dict(
        db.execute(
            select(Book.shelf_id, func.count()).where(Book.user_id == user.id).group_by(Book.shelf_id)
        ).all()
    )
    raflar = sorted(db.scalars(select(Shelf).where(Shelf.user_id == user.id)), key=lambda r: tr_sirala(r.name))
    return [ShelfOut(id=r.id, name=r.name, book_count=adetler.get(r.id, 0)) for r in raflar]


@router.post("", response_model=ShelfOut, status_code=status.HTTP_201_CREATED)
def ekle(veri: ShelfIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> ShelfOut:
    if _ayni_ad_var_mi(db, user, veri.name):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=_AYNI_AD)
    raf = Shelf(user_id=user.id, name=veri.name)
    db.add(raf)
    _kaydet(db)
    db.refresh(raf)
    return _cikti(db, raf)


@router.put("/{raf_id}", response_model=ShelfOut)
def guncelle(
    raf_id: int, veri: ShelfIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> ShelfOut:
    raf = _kendi_rafi(raf_id, user, db)
    if _ayni_ad_var_mi(db, user, veri.name, haric_id=raf.id):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=_AYNI_AD)
    raf.name = veri.name
    _kaydet(db)
    db.refresh(raf)
    return _cikti(db, raf)


@router.delete("/{raf_id}", status_code=status.HTTP_204_NO_CONTENT)
def sil(raf_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Response:
    """Rafı siler; raftaki kitaplar silinmez, rafsız kalır."""
    db.delete(_kendi_rafi(raf_id, user, db))
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
