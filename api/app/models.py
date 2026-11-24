from datetime import date, datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, Text, UniqueConstraint, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    __table_args__ = (CheckConstraint("role IN ('user', 'admin')", name="ck_users_role"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(100))
    role: Mapped[str] = mapped_column(String(10), default="user", server_default="user")
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    books: Mapped[list["Book"]] = relationship(back_populates="owner", cascade="all, delete-orphan")
    shelves: Mapped[list["Shelf"]] = relationship(back_populates="owner", cascade="all, delete-orphan")
    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(cascade="all, delete-orphan")


class Category(Base):
    """Yöneticinin yönettiği kitap kategorileri (Roman, Bilim vb.)."""

    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100), unique=True)
    description: Mapped[str | None] = mapped_column(Text)

    books: Mapped[list["Book"]] = relationship(back_populates="category")


class Shelf(Base):
    """Kullanıcının kendi kitap rafları."""

    __tablename__ = "shelves"
    __table_args__ = (UniqueConstraint("user_id", "name", name="uq_shelves_user_name"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(100))

    owner: Mapped[User] = relationship(back_populates="shelves")
    books: Mapped[list["Book"]] = relationship(back_populates="shelf")


class Book(Base):
    __tablename__ = "books"
    __table_args__ = (
        CheckConstraint("status IN ('okunacak', 'okunuyor', 'okundu')", name="ck_books_status"),
        CheckConstraint("rating IS NULL OR rating BETWEEN 1 AND 5", name="ck_books_rating"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    category_id: Mapped[int | None] = mapped_column(ForeignKey("categories.id", ondelete="SET NULL"))
    shelf_id: Mapped[int | None] = mapped_column(ForeignKey("shelves.id", ondelete="SET NULL"))
    title: Mapped[str] = mapped_column(String(255))
    author: Mapped[str] = mapped_column(String(255))
    isbn: Mapped[str | None] = mapped_column(String(20))
    publisher: Mapped[str | None] = mapped_column(String(255))
    year: Mapped[int | None]
    pages: Mapped[int | None]
    note: Mapped[str | None] = mapped_column(Text)
    cover_path: Mapped[str | None] = mapped_column(String(500))
    status: Mapped[str] = mapped_column(String(20), default="okunacak", server_default="okunacak")
    rating: Mapped[int | None]
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    owner: Mapped[User] = relationship(back_populates="books")
    category: Mapped[Category | None] = relationship(back_populates="books")
    shelf: Mapped[Shelf | None] = relationship(back_populates="books")
    loans: Mapped[list["Loan"]] = relationship(back_populates="book", cascade="all, delete-orphan")


class RefreshToken(Base):
    """Uzun ömürlü oturum yenileme anahtarı. Anahtarın kendisi değil SHA-256 özeti saklanır."""

    __tablename__ = "refresh_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    remember_me: Mapped[bool] = mapped_column(default=False, server_default="false")
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # True: yenilemeyle döndürüldü (tekrar gelirse çalınma şüphesi); False: çıkışla iptal edildi.
    rotated: Mapped[bool] = mapped_column(default=False, server_default="false")
    # Döndürülmüş token'ın 30 sn'lik tek seferlik tekrar hakkı kullanıldı mı (ya da çalınmayla kapandı mı).
    tolerans_kullanildi: Mapped[bool] = mapped_column(default=False, server_default="false")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Loan(Base):
    """Bir kitabın birine ödünç verilmesi. returned_at boşsa kitap hâlâ ödünçtedir."""

    __tablename__ = "loans"

    id: Mapped[int] = mapped_column(primary_key=True)
    book_id: Mapped[int] = mapped_column(ForeignKey("books.id", ondelete="CASCADE"))
    borrower: Mapped[str] = mapped_column(String(150))
    lent_at: Mapped[date] = mapped_column(server_default=func.current_date())
    due_at: Mapped[date | None]
    returned_at: Mapped[date | None]

    book: Mapped[Book] = relationship(back_populates="loans")
