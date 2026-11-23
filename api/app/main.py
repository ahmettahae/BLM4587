from fastapi import Depends, FastAPI
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db import get_db
from app.routers import admin, auth, books, categories, shelves

app = FastAPI(title="Kitaplığım API", version="0.5.0")
app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(books.router)
app.include_router(categories.router)
app.include_router(shelves.router)


@app.get("/health", tags=["sistem"])
def health(db: Session = Depends(get_db)) -> dict[str, str]:
    """API'nin ve veritabanı bağlantısının çalıştığını gösterir."""
    db.execute(text("SELECT 1"))
    return {"durum": "ok"}
