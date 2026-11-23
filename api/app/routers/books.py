from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.metin import tr_esle
from app.models import Book, Category, Shelf, User
from app.schemas import BookIn, BookOut, KitapDurumu

router = APIRouter(prefix="/books", tags=["kitaplar"])


def _kendi_kitabi(book_id: int, user: User, db: Session) -> Book:
    """Kitabı yalnızca sahibine verir. Başkasının kitabı da 'bulunamadı' döner (varlığı sızdırılmaz)."""
    book = db.get(Book, book_id)
    if book is None or book.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kitap bulunamadı")
    return book


def _iliskileri_dogrula(veri: BookIn, user: User, db: Session) -> None:
    """Kategori var olmalı; raf kullanıcının kendi rafı olmalı."""
    if veri.category_id is not None and db.get(Category, veri.category_id) is None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Kategori bulunamadı")
    if veri.shelf_id is not None:
        raf = db.get(Shelf, veri.shelf_id)
        if raf is None or raf.user_id != user.id:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Raf bulunamadı")


def _aramaya_uyar_mi(book: Book, aranan: str) -> bool:
    """Başlık, yazar ya da ISBN içinde Türkçe kurala göre büyük/küçük harf duyarsız arar."""
    return any(aranan in tr_esle(alan or "") for alan in (book.title, book.author, book.isbn))


@router.get("", response_model=list[BookOut])
def listele(
    search: str | None = Query(default=None, max_length=200, description="Başlık, yazar ya da ISBN içinde arar"),
    category: int | None = Query(default=None, description="Kategori numarası"),
    shelf: int | None = Query(default=None, description="Raf numarası (yalnız kendi rafların)"),
    status_: KitapDurumu | None = Query(default=None, alias="status", description="Okuma durumu"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Book]:
    """Giriş yapan kullanıcının kitapları, en son eklenen başta. Verilen filtrelerin hepsine uyanlar döner."""
    sorgu = select(Book).where(Book.user_id == user.id)
    if category is not None:
        sorgu = sorgu.where(Book.category_id == category)
    if shelf is not None:
        sorgu = sorgu.where(Book.shelf_id == shelf)
    if status_ is not None:
        sorgu = sorgu.where(Book.status == status_)
    kitaplar = list(db.scalars(sorgu.order_by(Book.created_at.desc(), Book.id.desc())))
    aranan = tr_esle(search.strip()) if search else ""
    if aranan:
        kitaplar = [k for k in kitaplar if _aramaya_uyar_mi(k, aranan)]
    return kitaplar


@router.post("", response_model=BookOut, status_code=status.HTTP_201_CREATED)
def ekle(veri: BookIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Book:
    _iliskileri_dogrula(veri, user, db)
    book = Book(user_id=user.id, **veri.model_dump())
    db.add(book)
    db.commit()
    db.refresh(book)
    return book


@router.get("/{book_id}", response_model=BookOut)
def getir(book_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Book:
    return _kendi_kitabi(book_id, user, db)


@router.put("/{book_id}", response_model=BookOut)
def guncelle(book_id: int, veri: BookIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Book:
    """Kitabın tüm alanlarını gönderilen veriyle değiştirir (kapak M7'de ayrı uçla yönetilecek)."""
    book = _kendi_kitabi(book_id, user, db)
    _iliskileri_dogrula(veri, user, db)
    for alan, deger in veri.model_dump().items():
        setattr(book, alan, deger)
    db.commit()
    db.refresh(book)
    return book


@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def sil(book_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Response:
    db.delete(_kendi_kitabi(book_id, user, db))
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
