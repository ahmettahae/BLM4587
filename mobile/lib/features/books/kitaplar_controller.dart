import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'kitap.dart';
import 'kitap_repository.dart';

/// Giriş yapan kullanıcının kitap listesi. Kullanıcı değişince (çıkış/giriş) liste yeniden yüklenir.
class KitaplarController extends AsyncNotifier<List<Kitap>> {
  @override
  Future<List<Kitap>> build() async {
    final kullaniciId = ref.watch(authControllerProvider.select((s) => s.kullanici?.id));
    if (kullaniciId == null) return const [];
    return ref.read(kitapRepositoryProvider).listele();
  }

  Future<void> yenile() async {
    state = await AsyncValue.guard(() => ref.read(kitapRepositoryProvider).listele());
  }

  List<Kitap> get _mevcut => state.value ?? const <Kitap>[];

  /// Hata olursa [ApiHata] fırlatır; form ekranı mesajı gösterir.
  Future<Kitap> ekle(KitapGirdisi girdi) async {
    final kitap = await ref.read(kitapRepositoryProvider).ekle(girdi);
    state = AsyncData([kitap, ..._mevcut]);
    return kitap;
  }

  Future<Kitap> guncelle(int id, KitapGirdisi girdi) async {
    final kitap = await ref.read(kitapRepositoryProvider).guncelle(id, girdi);
    state = AsyncData([for (final k in _mevcut) k.id == id ? kitap : k]);
    return kitap;
  }

  Future<void> sil(int id) async {
    await ref.read(kitapRepositoryProvider).sil(id);
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
