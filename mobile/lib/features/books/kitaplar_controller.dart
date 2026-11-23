import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../shelves/raflar_controller.dart';
import 'kitap.dart';
import 'kitap_filtresi.dart';
import 'kitap_repository.dart';

/// Giriş yapan kullanıcının kitap listesi, ana sayfadaki filtreye göre süzülmüş.
/// Kullanıcı ya da filtre değişince liste yeniden yüklenir.
class KitaplarController extends AsyncNotifier<List<Kitap>> {
  @override
  Future<List<Kitap>> build() async {
    final kullaniciId = ref.watch(authControllerProvider.select((s) => s.kullanici?.id));
    final filtre = ref.watch(kitapFiltresiProvider);
    if (kullaniciId == null) return const [];
    return ref.read(kitapRepositoryProvider).listele(filtre);
  }

  Future<void> yenile() async {
    final filtre = ref.read(kitapFiltresiProvider);
    state = await AsyncValue.guard(() => ref.read(kitapRepositoryProvider).listele(filtre));
  }

  List<Kitap> get _mevcut => state.value ?? const <Kitap>[];

  /// Raflardaki kitap sayıları sunucuda değişti; Raflarım ve silme uyarısı eski sayıyı göstermesin.
  void _raflariTazele() => ref.invalidate(raflarProvider);

  /// Hata olursa [ApiHata] fırlatır; form ekranı mesajı gösterir.
  /// Filtre doluyken yeni ya da değişen kitabın filtreye uyup uymadığını sunucu söyler.
  Future<Kitap> ekle(KitapGirdisi girdi) async {
    final kitap = await ref.read(kitapRepositoryProvider).ekle(girdi);
    _raflariTazele();
    if (ref.read(kitapFiltresiProvider).bosMu) {
      state = AsyncData([kitap, ..._mevcut]);
    } else {
      await yenile();
    }
    return kitap;
  }

  Future<Kitap> guncelle(int id, KitapGirdisi girdi) async {
    final kitap = await ref.read(kitapRepositoryProvider).guncelle(id, girdi);
    _raflariTazele();
    if (ref.read(kitapFiltresiProvider).bosMu) {
      state = AsyncData([for (final k in _mevcut) k.id == id ? kitap : k]);
    } else {
      await yenile();
    }
    return kitap;
  }

  Future<void> sil(int id) async {
    await ref.read(kitapRepositoryProvider).sil(id);
    _raflariTazele();
    state = AsyncData([for (final k in _mevcut) if (k.id != id) k]);
  }
}

final kitaplarProvider = AsyncNotifierProvider<KitaplarController, List<Kitap>>(KitaplarController.new);

/// Tek kitap: önce yüklü listedeki kopyaya bakar, yoksa API'den getirir.
final kitapProvider = FutureProvider.family<Kitap, int>((ref, id) async {
  final liste = ref.watch(kitaplarProvider).value;
  final bulunan = liste?.where((k) => k.id == id).firstOrNull;
  if (bulunan != null) return bulunan;
  return ref.read(kitapRepositoryProvider).getir(id);
});
