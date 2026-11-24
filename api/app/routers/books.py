from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.metin import tr_esle, tr_sirala
from app.models import Book, Category, Shelf, User
from app.schemas import BookIn, BookOut, KitapDurumu, KitapOzeti

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


Siralama = Literal["yeni", "eski", "baslik", "yazar", "puan"]


def _sirala(kitaplar: list[Book], sort: Siralama) -> list[Book]:
    """Liste veritabanından en yeni başta gelir; diğer sıralamalar Türkçe alfabeye göre burada yapılır."""
    if sort == "eski":
        return list(reversed(kitaplar))
    if sort == "baslik":
        return sorted(kitaplar, key=lambda k: tr_sirala(k.title))
    if sort == "yazar":
        return sorted(kitaplar, key=lambda k: (tr_sirala(k.author), tr_sirala(k.title)))
    if sort == "puan":  # yüksek puan başta, puansızlar sonda
        return sorted(kitaplar, key=lambda k: (k.rating is None, -(k.rating or 0), tr_sirala(k.title)))
    return kitaplar


@router.get(
    "",
    response_model=list[BookOut],
    summary="Kitaplarımı listele",
    response_description="Kitaplar. Filtreye uyan toplam sayı `X-Total-Count` başlığındadır.",
)
def listele(
    response: Response,
    search: str | None = Query(default=None, max_length=200, description="Başlık, yazar ya da ISBN içinde arar"),
    category: int | None = Query(default=None, description="Kategori numarası"),
    shelf: int | None = Query(default=None, description="Raf numarası (yalnız kendi rafların)"),
    status_: KitapDurumu | None = Query(default=None, alias="status", description="Okuma durumu"),
    sort: Siralama = Query(default="yeni", description="yeni, eski, baslik, yazar ya da puan"),
    limit: int = Query(default=50, ge=1, le=200, description="Sayfa boyutu"),
    offset: int = Query(default=0, ge=0, description="Atlanacak kitap sayısı"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Book]:
    """Giriş yapan kullanıcının kitapları. Verilen filtrelerin hepsine uyanlar, istenen sırada ve sayfada döner.

    Kişisel kütüphane küçük olduğu için Türkçe arama ve sıralama uygulamada yapılır, sonra sayfa kesilir.
    """
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
    response.headers["X-Total-Count"] = str(len(kitaplar))
    return _sirala(kitaplar, sort)[offset : offset + limit]


@router.get("/summary", response_model=KitapOzeti, summary="Okuma özeti")
def ozet(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> KitapOzeti:
    """Kullanıcının kitap sayısı, okuma durumlarına göre."""
    satirlar = db.execute(
        select(Book.status, func.count()).where(Book.user_id == user.id).group_by(Book.status)
    ).all()
    sayilar = {durum: sayi for durum, sayi in satirlar}
    return KitapOzeti(
        toplam=sum(sayilar.values()),
        okunacak=sayilar.get("okunacak", 0),
        okunuyor=sayilar.get("okunuyor", 0),
        okundu=sayilar.get("okundu", 0),
    )


@router.post("", response_model=BookOut, status_code=status.HTTP_201_CREATED, summary="Kitap ekle")
def ekle(veri: BookIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Book:
    _iliskileri_dogrula(veri, user, db)
    book = Book(user_id=user.id, **veri.model_dump())
    db.add(book)
    db.commit()
    db.refresh(book)
    return book


@router.get("/{book_id}", response_model=BookOut, summary="Kitabı getir")
def getir(book_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Book:
    return _kendi_kitabi(book_id, user, db)


@router.put("/{book_id}", response_model=BookOut, summary="Kitabı güncelle")
def guncelle(book_id: int, veri: BookIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Book:
    """Kitabın tüm alanlarını gönderilen veriyle değiştirir (kapak M7'de ayrı uçla yönetilecek)."""
    book = _kendi_kitabi(book_id, user, db)
    _iliskileri_dogrula(veri, user, db)
    for alan, deger in veri.model_dump().items():
        setattr(book, alan, deger)
    db.commit()
    db.refresh(book)
    return book


@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Kitabı sil")
def sil(book_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Response:
    db.delete(_kendi_kitabi(book_id, user, db))
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
