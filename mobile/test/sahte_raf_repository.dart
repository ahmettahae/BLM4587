import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/features/shelves/raf.dart';
import 'package:kitapligim/features/shelves/raf_repository.dart';

/// Ağa çıkmayan, bellekte çalışan raf katmanı. Sunucu gibi aynı adı ikinci kez kabul etmez.
class SahteRafRepository implements RafRepository {
  SahteRafRepository([List<Raf>? baslangic]) : _raflar = [...?baslangic];

  final List<Raf> _raflar;
  int _sonId = 70;

  List<Raf> get raflar => List.unmodifiable(_raflar);

  void _adCakisiyorMu(String ad, {int? haric}) {
    final cakisiyor = _raflar.any((r) => r.id != haric && r.ad.toLowerCase() == ad.toLowerCase());
    if (cakisiyor) throw ApiHata('Bu adda bir raf zaten var', durum: 409);
  }

  /// Kaç kez liste istendiği (kitap sayılarının sunucudan tazelendiğini görmek için).
  int listelemeSayisi = 0;

  @override
  Future<List<Raf>> listele() async {
    listelemeSayisi++;
    return List.of(_raflar);
  }

  @override
  Future<Raf> ekle(RafGirdisi girdi) async {
    _adCakisiyorMu(girdi.ad);
    final raf = Raf(id: ++_sonId, ad: girdi.ad);
    _raflar.add(raf);
    return raf;
  }

  @override
  Future<Raf> guncelle(int id, RafGirdisi girdi) async {
    final i = _raflar.indexWhere((r) => r.id == id);
    if (i < 0) throw ApiHata('Raf bulunamadı', durum: 404);
    _adCakisiyorMu(girdi.ad, haric: id);
    return _raflar[i] = Raf(id: id, ad: girdi.ad, kitapSayisi: _raflar[i].kitapSayisi);
  }

  @override
  Future<void> sil(int id) async {
    _raflar.removeWhere((r) => r.id == id);
  }
}
