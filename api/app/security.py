from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

from app.config import settings

_hasher = PasswordHasher()
ALGORITHM = "HS256"


def hash_password(password: str) -> str:
    """Şifreyi argon2 ile özetler; düz şifre veritabanına yazılmaz."""
    return _hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except (VerificationError, InvalidHashError):
        return False


def create_access_token(user_id: int) -> str:
    """Kullanıcı numarasını ve bitiş zamanını içeren imzalı JWT üretir."""
    bitis = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes)
    return jwt.encode({"sub": str(user_id), "exp": bitis}, settings.jwt_secret, algorithm=ALGORITHM)


def decode_access_token(token: str) -> int | None:
    """Geçerli token'daki kullanıcı numarasını döner; imza ya da süre geçersizse None."""
    try:
        yuk = jwt.decode(token, settings.jwt_secret, algorithms=[ALGORITHM])
        return int(yuk["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None
