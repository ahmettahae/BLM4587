from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings

engine = create_engine(settings.database_url)
SessionLocal = sessionmaker(bind=engine, autoflush=False)


def get_db() -> Iterator[Session]:
    """Her istek için bir veritabanı oturumu açar, istek bitince kapatır."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
