import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import delete, update

from app.db import SessionLocal
from app.main import app
from app.models import User

TEST_ALAN = "@test.kitapligim.example"


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture(autouse=True)
def test_kullanicilarini_temizle():
    """Her testten sonra bu testlerin oluşturduğu kullanıcıları siler (gerçek veriye dokunmaz)."""
    yield
    with SessionLocal() as db:
        db.execute(delete(User).where(User.email.like(f"%{TEST_ALAN}")))
        db.commit()


@pytest.fixture
def yeni_eposta():
    return lambda: f"{uuid.uuid4().hex[:10]}{TEST_ALAN}"


@pytest.fixture
def kayit_ol(client, yeni_eposta):
    """Kullanıcı kaydeder ve (kullanıcı bilgisi, şifre) döner."""

    def _kayit(email=None, password="gizli-sifre-123", display_name="Test Kullanıcı"):
        email = email or yeni_eposta()
        yanit = client.post("/auth/register", json={"email": email, "password": password, "display_name": display_name})
        assert yanit.status_code == 201, yanit.text
        return yanit.json(), password

    return _kayit


@pytest.fixture
def giris_yap(client):
    def _giris(email, password):
        return client.post("/auth/login", data={"username": email, "password": password})

    return _giris


@pytest.fixture
def yonetici_yap():
    def _yap(email):
        with SessionLocal() as db:
            db.execute(update(User).where(User.email == email).values(role="admin"))
            db.commit()

    return _yap
