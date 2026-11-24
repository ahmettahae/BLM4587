from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Form, HTTPException, Request, Response, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import delete, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import giris_siniri
from app.config import settings
from app.db import get_db
from app.deps import get_current_user
from app.models import RefreshToken, User
from app.schemas import RefreshIn, RegisterIn, TokenOut, UserOut
from app.security import create_access_token, hash_password, refresh_ozeti, verify_password, yeni_refresh_token

router = APIRouter(tags=["kimlik"])

_GECERSIZ_OTURUM = "Oturumun süresi dolmuş ya da geçersiz; tekrar giriş yap"
# Yenileme cevabı telefona ulaşmazsa uygulama aynı token'la tekrar dener; bu süre içindeki
# tekrar çalınma sayılmaz, yeni bir çift verilir.
TOLERANS_SANIYE = 30
# Çıkışla iptal edilen token'lar bu süre sonra budanır. Döndürülmüş token'lar ise çalınma
# tespiti için ömürleri bitene kadar saklanır.
IPTAL_SAKLAMA = timedelta(days=1)
# Kullanıcı yoksa da şifre doğrulaması çalışsın: cevap süresi kayıtlı e-postayı ele vermesin.
_SAHTE_HASH = hash_password("kitapligim-olmayan-kullanici")


def _simdi() -> datetime:
    return datetime.now(timezone.utc)


def _istemci_ip(istek: Request) -> str:
    return istek.client.host if istek.client else "bilinmiyor"


def _dondur(db: Session, kayit_id: int) -> bool:
    """Token'ı atomik olarak 'döndürüldü' diye iptal eder. Başka bir istek önce davrandıysa False.

    Koşullu UPDATE sayesinde aynı token'la eş zamanlı gelen iki istekten yalnız biri kazanır.
    """
    sonuc = db.execute(
        update(RefreshToken)
        .where(RefreshToken.id == kayit_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=_simdi(), rotated=True)
        .returning(RefreshToken.id)
    )
    return sonuc.first() is not None


def _toleransi_kullan(db: Session, kayit_id: int) -> bool:
    """Döndürülmüş token için tek seferlik tolerans hakkını atomik olarak kullanır."""
    sonuc = db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.id == kayit_id,
            RefreshToken.rotated.is_(True),
            RefreshToken.tolerans_kullanildi.is_(False),
            RefreshToken.revoked_at >= _simdi() - timedelta(seconds=TOLERANS_SANIYE),
        )
        .values(tolerans_kullanildi=True)
        .returning(RefreshToken.id)
    )
    return sonuc.first() is not None


def _eskileri_buda(db: Session, user_id: int) -> None:
    """Süresi dolmuş token'ları ve 1 günden uzun süredir çıkışla iptal olanları siler.

    Döndürülmüş token'lar ömürleri bitene kadar kalır; günler sonra tekrar kullanılırsa da
    çalınma tespit edilir.
    """
    simdi = _simdi()
    db.execute(
        delete(RefreshToken).where(
            RefreshToken.user_id == user_id,
            or_(
                RefreshToken.expires_at <= simdi,
                (RefreshToken.revoked_at < simdi - IPTAL_SAKLAMA) & RefreshToken.rotated.is_(False),
            ),
        )
    )


def _token_cifti(db: Session, user: User, remember_me: bool) -> TokenOut:
    """Yeni erişim + yenileme token'ı üretir; yenileme token'ının yalnız özetini kaydeder.

    Aynı işlemde kullanıcının eski token'larını da budar (giriş ve yenilemede).
    """
    _eskileri_buda(db, user.id)
    omur = (
        timedelta(days=settings.refresh_remember_days)
        if remember_me
        else timedelta(hours=settings.refresh_session_hours)
    )
    refresh = yeni_refresh_token()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=refresh_ozeti(refresh),
            remember_me=remember_me,
            expires_at=_simdi() + omur,
        )
    )
    db.commit()
    return TokenOut(
        access_token=create_access_token(user.id),
        expires_in=settings.jwt_expire_minutes * 60,
        refresh_token=refresh,
        user=UserOut.model_validate(user),
    )


@router.post("/auth/register", response_model=UserOut, status_code=status.HTTP_201_CREATED, summary="Kayıt ol")
def register(veri: RegisterIn, db: Session = Depends(get_db)) -> User:
    """Yeni kullanıcı oluşturur. Rol her zaman 'user' olur; yönetici elle atanır."""
    email = veri.email.lower()
    if db.scalar(select(User).where(User.email == email)):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bu e-posta zaten kayıtlı")
    user = User(email=email, password_hash=hash_password(veri.password), display_name=veri.display_name)
    db.add(user)
    try:
        db.commit()
    except IntegrityError:  # aynı anda gelen iki kayıt isteği için
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bu e-posta zaten kayıtlı")
    db.refresh(user)
    return user


@router.post(
    "/auth/login",
    response_model=TokenOut,
    summary="Giriş yap",
    responses={401: {"description": "E-posta ya da şifre hatalı"}, 429: {"description": "Çok fazla hatalı deneme"}},
)
def login(
    istek: Request,
    form: OAuth2PasswordRequestForm = Depends(),
    remember_me: bool = Form(False, description="İşaretliyse oturum 30 gün, değilse 12 saat yenilenebilir"),
    db: Session = Depends(get_db),
) -> TokenOut:
    """E-posta (`username` alanı) ve şifreyle giriş yapar; erişim ve yenileme token'ı döner.

    Aynı e-postaya aynı IP'den 15 dakikada 5, bir IP'den toplam 20 hatalı deneme yapılırsa
    giriş 15 dakika kilitlenir (429).
    """
    ip = _istemci_ip(istek)
    kalan = giris_siniri.kalan_kilit_saniyesi(form.username, ip)
    if kalan:
        dakika = max(1, (kalan + 59) // 60)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Çok fazla hatalı deneme. {dakika} dakika sonra tekrar dene.",
            headers={"Retry-After": str(kalan)},
        )
    user = db.scalar(select(User).where(User.email == form.username.lower()))
    sifre_dogru = verify_password(form.password, user.password_hash if user else _SAHTE_HASH)
    if user is None or not sifre_dogru:
        giris_siniri.hata_kaydet(form.username, ip)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-posta ya da şifre hatalı",
            headers={"WWW-Authenticate": "Bearer"},
        )
    giris_siniri.sifirla(form.username, ip)
    return _token_cifti(db, user, remember_me)


@router.post(
    "/auth/refresh",
    response_model=TokenOut,
    summary="Oturumu yenile",
    responses={401: {"description": "Yenileme token'ı geçersiz, iptal edilmiş ya da süresi dolmuş"}},
)
def refresh(veri: RefreshIn, db: Session = Depends(get_db)) -> TokenOut:
    """Yenileme token'ını yeni bir erişim + yenileme token'ı çiftiyle değiştirir (eskisi iptal olur).

    - Döndürülmüş bir token 30 saniye içinde bir kez daha gelirse (cevap kaybolmuş olabilir) yeni çift verilir.
    - Başka her tekrar çalınma sayılır: kullanıcının tüm yenileme token'ları iptal edilir ve son
      döndürülenlerin tolerans hakkı da kapanır.
    - Çıkışla iptal edilmiş token yalnız 401 alır.
    """
    kayit = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == refresh_ozeti(veri.refresh_token)))
    if kayit is None or kayit.expires_at <= _simdi():
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=_GECERSIZ_OTURUM)
    if kayit.revoked_at is None:
        if _dondur(db, kayit.id):
            user = db.get(User, kayit.user_id)
            return _token_cifti(db, user, kayit.remember_me)
        # Eş zamanlı başka bir istek az önce döndürdü: güncel hâli oku, tolerans kuralı uygulanır.
        db.rollback()
        db.refresh(kayit)
    if not kayit.rotated:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=_GECERSIZ_OTURUM)
    if _toleransi_kullan(db, kayit.id):
        user = db.get(User, kayit.user_id)
        return _token_cifti(db, user, kayit.remember_me)
    db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == kayit.user_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=_simdi())
    )
    db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == kayit.user_id, RefreshToken.rotated.is_(True))
        .values(tolerans_kullanildi=True)
    )
    db.commit()
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=_GECERSIZ_OTURUM)


@router.post("/auth/logout", status_code=status.HTTP_204_NO_CONTENT, summary="Çıkış yap")
def logout(veri: RefreshIn, db: Session = Depends(get_db)) -> Response:
    """Yenileme token'ını iptal eder. Bilinmeyen token da 204 döner (bilgi sızdırmaz)."""
    kayit = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == refresh_ozeti(veri.refresh_token)))
    if kayit is not None and kayit.revoked_at is None:
        kayit.revoked_at = _simdi()
        db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=UserOut, summary="Ben kimim")
def me(user: User = Depends(get_current_user)) -> User:
    """Giriş yapmış kullanıcının bilgilerini döner."""
    return user
