import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/features/books/kitap.dart';
import 'package:kitapligim/features/books/kitap_repository.dart';

/// Ağa çıkmayan, bellekte çalışan kitap katmanı. API gibi en yeni kitabı başa koyar.
class SahteKitapRepository implements KitapRepository {
  SahteKitapRepository([List<Kitap>? baslangic]) : _kitaplar = [...?baslangic];

  final List<Kitap> _kitaplar;
  int _sonId = 100;

  /// Doluysa bir sonraki yazma isteği bu mesajla başarısız olur.
  String? sonrakiHata;

  List<Kitap> get kitaplar => List.unmodifiable(_kitaplar);

  void _hataVarsaFirlat() {
    final hata = sonrakiHata;
    if (hata != null) {
      sonrakiHata = null;
      throw ApiHata(hata, durum: 422);
    }
  }

  Kitap _olustur(int id, KitapGirdisi g) => Kitap(
        id: id,
        baslik: g.baslik,
        yazar: g.yazar,
        isbn: g.isbn,
        yayinevi: g.yayinevi,
        yil: g.yil,
        sayfa: g.sayfa,
        not: g.not,
        durum: g.durum,
        puan: g.puan,
        kategoriId: g.kategoriId,
        rafId: g.rafId,
      );

  @override
  Future<List<Kitap>> listele() async => List.of(_kitaplar);

  @override
  Future<Kitap> getir(int id) async =>
      _kitaplar.where((k) => k.id == id).firstOrNull ?? (throw ApiHata('Kitap bulunamadı', durum: 404));

  @override
  Future<Kitap> ekle(KitapGirdisi girdi) async {
    _hataVarsaFirlat();
    final kitap = _olustur(++_sonId, girdi);
    _kitaplar.insert(0, kitap);
    return kitap;
  }

  @override
  Future<Kitap> guncelle(int id, KitapGirdisi girdi) async {
    _hataVarsaFirlat();
    final i = _kitaplar.indexWhere((k) => k.id == id);
    if (i < 0) throw ApiHata('Kitap bulunamadı', durum: 404);
    return _kitaplar[i] = _olustur(id, girdi);
  }

  @override
  Future<void> sil(int id) async {
    _hataVarsaFirlat();
    _kitaplar.removeWhere((k) => k.id == id);
  }
}
