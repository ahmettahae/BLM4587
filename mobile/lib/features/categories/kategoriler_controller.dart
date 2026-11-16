import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../books/kitaplar_controller.dart';
import 'kategori.dart';
import 'kategori_repository.dart';

/// Kategori listesi: her giriş yapan kullanıcı okur (kitap formu), yönetici düzenler.
/// Liste sunucudan sıralı ve kitap sayılarıyla gelir; yazma işlemlerinden sonra yeniden yüklenir.
class KategorilerController extends AsyncNotifier<List<Kategori>> {
  @override
  Future<List<Kategori>> build() async {
    final kullaniciId = ref.watch(authControllerProvider.select((s) => s.kullanici?.id));
    if (kullaniciId == null) return const [];
    return ref.read(kategoriRepositoryProvider).listele();
  }

  Future<void> yenile() async {
    state = await AsyncValue.guard(() => ref.read(kategoriRepositoryProvider).listele());
  }

  /// Hata olursa [ApiHata] fırlatır; form penceresi mesajı gösterir.
  Future<void> ekle(KategoriGirdisi girdi) async {
    await ref.read(kategoriRepositoryProvider).ekle(girdi);
    await yenile();
  }

  Future<void> guncelle(int id, KategoriGirdisi girdi) async {
    await ref.read(kategoriRepositoryProvider).guncelle(id, girdi);
    await yenile();
  }

  Future<void> sil(int id) async {
    await ref.read(kategoriRepositoryProvider).sil(id);
    await yenile();
    // Silinen kategorideki kitapların kategorisi sunucuda boşaldı; kitap listesi de yenilensin.
    ref.invalidate(kitaplarProvider);
  }
}

final kategorilerProvider = AsyncNotifierProvider<KategorilerController, List<Kategori>>(KategorilerController.new);
