from fastapi import Depends, FastAPI
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db import get_db

app = FastAPI(title="Kitaplığım API", version="0.1.0")


@app.get("/health", tags=["sistem"])
def health(db: Session = Depends(get_db)) -> dict[str, str]:
    """API'nin ve veritabanı bağlantısının çalıştığını gösterir."""
    db.execute(text("SELECT 1"))
    return {"durum": "ok"}
