import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../shelves/raflar_controller.dart';
import 'kitap.dart';
import 'kitap_filtresi.dart';
import 'kitap_repository.dart';

/// Ana sayfadaki liste: yüklenen kitaplar, filtreye uyan toplam ve sonraki sayfa yükleniyor mu.
class KitapListesi {
  const KitapListesi(this.kitaplar, {this.toplam = 0, this.dahaYukleniyor = false, this.dahaHatasi = false});

  final List<Kitap> kitaplar;
  final int toplam;
  final bool dahaYukleniyor;

  /// Sonraki sayfa yüklenemedi; kullanıcı "Tekrar dene"ye basana kadar kendiliğinden denenmez.
  final bool dahaHatasi;

  bool get dahaVar => kitaplar.length < toplam;

  /// Kaydırınca kendiliğinden sonraki sayfa istenebilir mi?
  bool get otomatikYuklenebilir => dahaVar && !dahaYukleniyor && !dahaHatasi;

  KitapListesi copyWith({List<Kitap>? kitaplar, int? toplam, bool? dahaYukleniyor, bool? dahaHatasi}) => KitapListesi(
        kitaplar ?? this.kitaplar,
        toplam: toplam ?? this.toplam,
        dahaYukleniyor: dahaYukleniyor ?? this.dahaYukleniyor,
        dahaHatasi: dahaHatasi ?? this.dahaHatasi,
      );
}

/// Giriş yapan kullanıcının kitap listesi, ana sayfadaki filtreye göre süzülmüş ve sayfalı.
/// Kullanıcı ya da filtre değişince liste baştan yüklenir; kaydırdıkça [dahaFazlaYukle] çağrılır.
class KitaplarController extends AsyncNotifier<KitapListesi> {
  /// Her yeniden yüklemede artar; geç gelen eski cevap yeni listenin üzerine yazmasın.
  int _nesil = 0;

  @override
  Future<KitapListesi> build() async {
    final kullaniciId = ref.watch(authControllerProvider.select((s) => s.kullanici?.id));
    final filtre = ref.watch(kitapFiltresiProvider);
    _nesil++;
    if (kullaniciId == null) return const KitapListesi([]);
    final sayfa = await ref.read(kitapRepositoryProvider).sayfa(filtre);
    return KitapListesi(sayfa.kitaplar, toplam: sayfa.toplam);
  }

  Future<void> yenile() async {
    final nesil = ++_nesil;
    final filtre = ref.read(kitapFiltresiProvider);
    final sonuc = await AsyncValue.guard(() async {
      final sayfa = await ref.read(kitapRepositoryProvider).sayfa(filtre);
      return KitapListesi(sayfa.kitaplar, toplam: sayfa.toplam);
    });
    if (nesil == _nesil) state = sonuc;
    ref.invalidate(kitapOzetiProvider);
  }

  /// Listenin sonuna yaklaşınca bir sonraki sayfayı ekler.
  /// Önceki deneme başarısız olduysa yalnız [tekrar] ile ("Tekrar dene") yeniden denenir.
  Future<void> dahaFazlaYukle({bool tekrar = false}) async {
    final mevcut = state.value;
    if (mevcut == null || !mevcut.dahaVar || mevcut.dahaYukleniyor) return;
    if (mevcut.dahaHatasi && !tekrar) return;
    final nesil = _nesil;
    state = AsyncData(mevcut.copyWith(dahaYukleniyor: true, dahaHatasi: false));
    try {
      final sayfa = await ref
          .read(kitapRepositoryProvider)
          .sayfa(ref.read(kitapFiltresiProvider), offset: mevcut.kitaplar.length);
      if (nesil != _nesil) return;
      // Beklerken eklenen/silinen kitaplar kaybolmasın: o anki listeye ekle.
      final simdi = state.value ?? mevcut;
      final silinenler = _silinenler;
      final bilinen = {for (final k in simdi.kitaplar) k.id};
      state = AsyncData(KitapListesi(
        [
          ...simdi.kitaplar,
          ...sayfa.kitaplar.where((k) => !bilinen.contains(k.id) && !silinenler.contains(k.id)),
        ],
        toplam: sayfa.toplam,
      ));
    } catch (_) {
      if (nesil == _nesil) {
        final simdi = state.value ?? mevcut;
        state = AsyncData(simdi.copyWith(dahaYukleniyor: false, dahaHatasi: true));
      }
    }
  }

  /// Bu listede silinen kitaplar (yoldaki bir sayfa onları geri getirmesin).
  final Set<int> _silinenler = {};

  KitapListesi get _mevcut => state.value ?? const KitapListesi([]);

  /// Raflardaki kitap sayıları ve özet sunucuda değişti; eski sayı gösterilmesin.
  void _sayilariTazele() {
    ref.invalidate(raflarProvider);
    ref.invalidate(kitapOzetiProvider);
  }

  /// Hata olursa [ApiHata] fırlatır; form ekranı mesajı gösterir.
  /// Süzme ya da özel sıralama varken yeni kitabın listedeki yerini sunucu söyler.
  Future<Kitap> ekle(KitapGirdisi girdi) async {
    final kitap = await ref.read(kitapRepositoryProvider).ekle(girdi);
    _sayilariTazele();
    if (ref.read(kitapFiltresiProvider).yeniBastaMi) {
      final m = _mevcut;
      state = AsyncData(m.copyWith(kitaplar: [kitap, ...m.kitaplar], toplam: m.toplam + 1));
    } else {
      await yenile();
    }
    return kitap;
  }

  Future<Kitap> guncelle(int id, KitapGirdisi girdi) async {
    final kitap = await ref.read(kitapRepositoryProvider).guncelle(id, girdi);
    _sayilariTazele();
    if (ref.read(kitapFiltresiProvider).yeniBastaMi) {
      final m = _mevcut;
      state = AsyncData(m.copyWith(kitaplar: [for (final k in m.kitaplar) k.id == id ? kitap : k]));
    } else {
      await yenile();
    }
    return kitap;
  }

  Future<void> sil(int id) async {
    await ref.read(kitapRepositoryProvider).sil(id);
    _silinenler.add(id);
    _sayilariTazele();
    final m = _mevcut;
    final kalan = [for (final k in m.kitaplar) if (k.id != id) k];
    state = AsyncData(m.copyWith(kitaplar: kalan, toplam: m.toplam - (m.kitaplar.length - kalan.length)));
  }

  /// Silinen kitabı aynı bilgilerle yeniden ekler ("Geri al").
  Future<Kitap> geriAl(Kitap silinen) => ekle(KitapGirdisi.kitaptan(silinen));
}

final kitaplarProvider = AsyncNotifierProvider<KitaplarController, KitapListesi>(KitaplarController.new);

/// Tek kitap: önce yüklü listedeki kopyaya bakar, yoksa API'den getirir.
final kitapProvider = FutureProvider.family<Kitap, int>((ref, id) async {
  final liste = ref.watch(kitaplarProvider).value?.kitaplar;
  final bulunan = liste?.where((k) => k.id == id).firstOrNull;
  if (bulunan != null) return bulunan;
  return ref.read(kitapRepositoryProvider).getir(id);
});

/// Okuma özeti (toplam, okunuyor, okundu…). Kitap eklenip silinince tazelenir.
final kitapOzetiProvider = FutureProvider<KitapOzeti>((ref) async {
  final kullaniciId = ref.watch(authControllerProvider.select((s) => s.kullanici?.id));
  if (kullaniciId == null) return const KitapOzeti();
  return ref.read(kitapRepositoryProvider).ozet();
});
