# Kitaplığım

BLM4587 iOS ile Mobil Uygulama Geliştirme I (Flutter) dönem projesi. Kişisel kitap koleksiyonunu kataloglayan mobil uygulama.

- `api/`: FastAPI Web API (Python), PostgreSQL, SQLAlchemy ve Alembic
- `mobile/`: Flutter mobil uygulaması (Android hedefli)

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
3. `.env.example` dosyasını `.env` olarak kopyala; `DATABASE_URL` içindeki şifreyi kendi PostgreSQL şifrenle, `JWT_SECRET` değerini de rastgele uzun bir değerle değiştir (üretmek için dosyadaki komutu çalıştır). `.env` depoya girmez.
4. Tabloları oluştur (migration):
   ```
   alembic upgrade head
   ```
5. API'yi başlat (`--host 0.0.0.0` emülatörün ve telefonun bilgisayara ulaşabilmesi için):
   ```
   uvicorn app.main:app --reload --host 0.0.0.0
   ```
   Swagger belgesi: http://127.0.0.1:8000/docs, sağlık kontrolü: http://127.0.0.1:8000/health
6. İlk yöneticiyi oluştur: önce uygulamadan ya da Swagger'dan `POST /auth/register` ile kayıt ol, sonra:
   ```
   python -m app.cli yonetici-yap kisi@ornek.com
   ```
   (Kayıt olan herkes `user` rolü alır; yönetici yalnızca bu komutla atanır.)

### Kimlik uçları
`POST /auth/register`, `POST /auth/login` (form: `username`=e-posta, `password`; JWT döner), `GET /me`, `GET /admin/ping` (yalnız yönetici). Swagger'da "Authorize" düğmesiyle giriş yapılabilir.

### Kitap uçları (giriş gerekir)
`GET /books` (kendi kitapların, en yeni başta), `POST /books`, `GET /books/{id}`, `PUT /books/{id}` (tüm alanları yeniden yazar), `DELETE /books/{id}`. Her kullanıcı yalnız kendi kitaplarını görür; başkasının kitabı `404` döner.

Alanlar: `title` ve `author` zorunlu; `isbn` (10 ya da 13 hane, tire ve boşluklar atılır), `publisher`, `year` (gelecek yıldan büyük olamaz), `pages` (1-50000), `note` (en fazla 2000 karakter), `status` (`okunacak`, `okunuyor`, `okundu`), `rating` (1-5), `category_id`, `shelf_id` (kendi rafın olmalı).

Testler (PostgreSQL açık ve `.env` dolu olmalı): `pytest`

### Yeni migration oluşturma
Modeller (`api/app/models.py`) değişince: `alembic revision --autogenerate -m "açıklama"` ardından `alembic upgrade head`.

## Veritabanı tabloları
`users`, `categories` (yönetici yönetir), `shelves`, `books`, `loans`. Bire-çok ilişkiler: kullanıcı→kitap, kullanıcı→raf, kategori→kitap, raf→kitap, kitap→ödünç.

## Mobil uygulama kurulumu
Gerekenler: Flutter 3.47 (Dart 3.x ile bu sürümle geliştirildi), Android SDK ve bir emülatör ya da USB hata ayıklaması açık Android telefon. Projeyi Türkçe karakter içermeyen bir klasörde tut (ör. `C:\dev\projeler\kitapligim`).

```
cd mobile
flutter pub get
flutter run
```

**API adresi:** Varsayılan `http://10.0.2.2:8000` (Android emülatöründe bilgisayarın localhost'u). Gerçek telefonda bilgisayarın yerel ağ adresini ver; telefon ve bilgisayar aynı Wi-Fi'de olmalı ve güvenlik duvarı 8000 numaralı bağlantı noktasına izin vermeli:
```
flutter run --dart-define=API_URL=http://192.168.1.20:8000
```
Testler: `flutter test`, kod denetimi: `flutter analyze`.

> Geliştirme sürümü şifresiz `http` kullanır (`usesCleartextTraffic`). Yayın sürümünde https'e geçilip bu ayar kaldırılmalı.
