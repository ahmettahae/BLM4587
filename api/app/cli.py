"""Komut satırı yardımcıları. Kullanım (api klasöründe):

    python -m app.cli yonetici-yap kisi@ornek.com
"""
import sys

from sqlalchemy import select

from app.db import SessionLocal
from app.models import User


def yonetici_yap(email: str) -> int:
    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.email == email.lower()))
        if user is None:
            print(f"Kullanıcı bulunamadı: {email}")
            return 1
        user.role = "admin"
        db.commit()
        print(f"{user.email} artık yönetici.")
        return 0


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "yonetici-yap":
        sys.exit(yonetici_yap(sys.argv[2]))
    print("Kullanım: python -m app.cli yonetici-yap <e-posta>")
    sys.exit(2)
