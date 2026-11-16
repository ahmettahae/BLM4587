import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/features/categories/kategori.dart';
import 'package:kitapligim/features/categories/kategori_repository.dart';

/// Ağa çıkmayan, bellekte çalışan kategori katmanı. Sunucu gibi aynı adı ikinci kez kabul etmez.
class SahteKategoriRepository implements KategoriRepository {
  SahteKategoriRepository([List<Kategori>? baslangic]) : _kategoriler = [...?baslangic];

  final List<Kategori> _kategoriler;
  int _sonId = 50;

  List<Kategori> get kategoriler => List.unmodifiable(_kategoriler);

  void _adCakisiyorMu(String ad, {int? haric}) {
    final cakisiyor = _kategoriler.any((k) => k.id != haric && k.ad.toLowerCase() == ad.toLowerCase());
    if (cakisiyor) throw ApiHata('Bu adda bir kategori zaten var', durum: 409);
  }

  @override
  Future<List<Kategori>> listele() async => List.of(_kategoriler);

  @override
  Future<Kategori> ekle(KategoriGirdisi girdi) async {
    _adCakisiyorMu(girdi.ad);
    final kategori = Kategori(id: ++_sonId, ad: girdi.ad, aciklama: girdi.aciklama);
    _kategoriler.add(kategori);
    return kategori;
  }

  @override
  Future<Kategori> guncelle(int id, KategoriGirdisi girdi) async {
    final i = _kategoriler.indexWhere((k) => k.id == id);
    if (i < 0) throw ApiHata('Kategori bulunamadı', durum: 404);
    _adCakisiyorMu(girdi.ad, haric: id);
    return _kategoriler[i] = Kategori(
      id: id,
      ad: girdi.ad,
      aciklama: girdi.aciklama,
      kitapSayisi: _kategoriler[i].kitapSayisi,
    );
  }

  @override
  Future<void> sil(int id) async {
    _kategoriler.removeWhere((k) => k.id == id);
  }
}
