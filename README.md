# Kitaplığım

BLM4587 iOS ile Mobil Uygulama Geliştirme I (Flutter) dönem projesi. Kişisel kitap koleksiyonunu kataloglayan mobil uygulama.

- `api/`: FastAPI Web API (Python), PostgreSQL, SQLAlchemy ve Alembic
- `mobile/`: Flutter mobil uygulaması (ikinci haftada eklenecek)

Grup üyeleri: Ahmet Taha Erol (`ahmettahae`), Semih Berkan Okutan (`semihberkanokutan`).

## Web API kurulumu

Gerekenler: Python 3.12 ve PostgreSQL 18 (bu sürümlerle geliştirildi ve denendi).

1. PostgreSQL'de boş bir veritabanı oluştur:
   ```
   createdb -U postgres -E UTF8 kitapligim
   ```
   (Windows'ta Türkçe yerel ayar `initdb`'yi bozarsa kümeyi `--locale=C` ile oluştur.)
2. Sanal ortamı kur ve paketleri yükle:
   ```
   cd api
   py -3 -m venv .venv
   .venv\Scripts\activate
   pip install -r requirements.txt
   ```
3. `.env.example` dosyasını `.env` olarak kopyala ve `DATABASE_URL` içindeki şifreyi kendi PostgreSQL şifrenle değiştir. `.env` depoya girmez.
4. Tabloları oluştur (migration):
   ```
   alembic upgrade head
   ```
5. API'yi başlat:
   ```
   uvicorn app.main:app --reload
   ```
   Swagger belgesi: http://127.0.0.1:8000/docs, sağlık kontrolü: http://127.0.0.1:8000/health

Testler (PostgreSQL açık ve `.env` dolu olmalı): `pytest`

### Yeni migration oluşturma
Modeller (`api/app/models.py`) değişince: `alembic revision --autogenerate -m "açıklama"` ardından `alembic upgrade head`.

## Veritabanı tabloları
`users`, `categories` (yönetici yönetir), `shelves`, `books`, `loans`. Bire-çok ilişkiler: kullanıcı→kitap, kullanıcı→raf, kategori→kitap, raf→kitap, kitap→ödünç.

## Mobil uygulama kurulumu
Hafta 2'de eklenecek (Flutter sürümü, `flutter pub get`, `flutter run`, API adresi ayarı).
