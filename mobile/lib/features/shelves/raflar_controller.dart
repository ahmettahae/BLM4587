import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../books/kitap_filtresi.dart';
import '../books/kitaplar_controller.dart';
import 'raf.dart';
import 'raf_repository.dart';

/// Giriş yapan kullanıcının rafları. Liste sunucudan sıralı ve kitap sayılarıyla gelir;
/// yazma işlemlerinden sonra yeniden yüklenir.
class RaflarController extends AsyncNotifier<List<Raf>> {
  @override
  Future<List<Raf>> build() async {
    final kullaniciId = ref.watch(authControllerProvider.select((s) => s.kullanici?.id));
    if (kullaniciId == null) return const [];
    return ref.read(rafRepositoryProvider).listele();
  }

  Future<void> yenile() async {
    state = await AsyncValue.guard(() => ref.read(rafRepositoryProvider).listele());
  }

  /// Hata olursa [ApiHata] fırlatır; pencere mesajı gösterir.
  Future<void> ekle(RafGirdisi girdi) async {
    await ref.read(rafRepositoryProvider).ekle(girdi);
    await yenile();
  }

  Future<void> guncelle(int id, RafGirdisi girdi) async {
    await ref.read(rafRepositoryProvider).guncelle(id, girdi);
    await yenile();
  }

  Future<void> sil(int id) async {
    await ref.read(rafRepositoryProvider).sil(id);
    await yenile();
    // Ana sayfa silinen rafa göre filtreliyse filtre kalksın; yoksa liste boş görünür.
    final filtre = ref.read(kitapFiltresiProvider.notifier);
    if (ref.read(kitapFiltresiProvider).rafId == id) filtre.rafSec(null);
    // Silinen raftaki kitapların rafı sunucuda boşaldı; kitap listesi de yenilensin.
    ref.invalidate(kitaplarProvider);
  }
}

final raflarProvider = AsyncNotifierProvider<RaflarController, List<Raf>>(RaflarController.new);
