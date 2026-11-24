import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitapligim/app/app.dart';
import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/core/token_store.dart';
import 'package:kitapligim/features/auth/auth_controller.dart';
import 'package:kitapligim/features/auth/auth_repository.dart';
import 'package:kitapligim/features/auth/kullanici.dart';
import 'package:kitapligim/features/books/kitap.dart';
import 'package:kitapligim/features/books/kitap_filtresi.dart';
import 'package:kitapligim/features/books/kitap_repository.dart';
import 'package:kitapligim/features/books/kitaplar_controller.dart';
import 'package:kitapligim/features/categories/kategori_repository.dart';
import 'package:kitapligim/features/shelves/raf_repository.dart';

import 'profesyonel_test.dart' show ac, kitaplar;
import 'sahte_kategori_repository.dart';
import 'sahte_kitap_repository.dart';
import 'sahte_raf_repository.dart';

class _Auth implements AuthRepository {
  @override
  Future<GirisSonucu> giris(String email, String sifre, {bool beniHatirla = false}) async => throw UnimplementedError();

  @override
  Future<void> kayit(String ad, String email, String sifre) async {}

  @override
  Future<void> cikis(String yenileme) async {}

  @override
  Future<Kullanici> ben() async => const Kullanici(id: 7, email: 'okur@ornek.com', ad: 'Okur', rol: 'user');
}

/// Güvenli depo bozulmuş gibi (ör. yedekten geri yükleme sonrası) okumada hata fırlatır.
class _BozukDepo extends BellekTokenStore {
  @override
  Future<String?> oku() async => throw StateError('depo okunamadı');
}

/// İkinci sayfayı [kilit] tamamlanana kadar bekletir.
class _IkinciSayfasiYavas extends SahteKitapRepository {
  _IkinciSayfasiYavas(super.baslangic);

  final kilit = Completer<void>();

  @override
  Future<KitapSayfasi> sayfa(KitapFiltresi filtre, {int offset = 0, int limit = KitapRepository.sayfaBoyutu}) async {
    if (offset > 0) await kilit.future;
    return super.sayfa(filtre, offset: offset, limit: limit);
  }
}

void main() {
  testWidgets('güvenli depo okunamazsa açılış ekranında kalmaz, giriş ekranı açılır', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_Auth()),
          tokenStoreProvider.overrideWithValue(_BozukDepo()),
          kitapRepositoryProvider.overrideWithValue(SahteKitapRepository()),
          kategoriRepositoryProvider.overrideWithValue(SahteKategoriRepository()),
          rafRepositoryProvider.overrideWithValue(SahteRafRepository()),
        ],
        child: const KitapligimApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('yukleme_ekrani')), findsNothing);
    expect(find.byKey(const Key('giris_email')), findsOneWidget);
  });

  testWidgets('sonraki sayfa yüklenemezse istek yağmuru olmaz; "Tekrar dene" ile yüklenir', (tester) async {
    final depo = await ac(tester, liste: kitaplar(30));
    depo.kaliciListeHatasi = 'Sunucuya ulaşılamadı.';
    final liste = find.byKey(const Key('kitap_listesi'));
    await tester.dragUntilVisible(find.byKey(const Key('daha_hata')), liste, const Offset(0, -300));
    await tester.pumpAndSettle();
    final denemeler = depo.istenenOffsetler.where((o) => o == 20).length;
    // Kaydırmaya devam etmek kendiliğinden yeni istek atmaz.
    await tester.drag(liste, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.drag(liste, const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(depo.istenenOffsetler.where((o) => o == 20).length, denemeler);
    depo.kaliciListeHatasi = null;
    await tester.ensureVisible(find.byKey(const Key('daha_tekrar_dene')));
    await tester.tap(find.byKey(const Key('daha_tekrar_dene')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daha_hata')), findsNothing);
    await tester.dragUntilVisible(find.byKey(const Key('kitap_1')), liste, const Offset(0, -300));
    expect(find.byKey(const Key('kitap_1')), findsOneWidget);
  });

  test('sonraki sayfa yüklenirken silinen kitap listeye geri dönmez', () async {
    final token = BellekTokenStore();
    await token.yaz('t');
    final depo = _IkinciSayfasiYavas(kitaplar(30));
    final kap = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Auth()),
        tokenStoreProvider.overrideWithValue(token),
        kitapRepositoryProvider.overrideWithValue(depo),
        rafRepositoryProvider.overrideWithValue(SahteRafRepository()),
      ],
    );
    addTearDown(kap.dispose);
    kap.listen(kitaplarProvider, (_, _) {});
    while (kap.read(authControllerProvider).durum != OturumDurumu.girisVar) {
      await Future<void>.delayed(Duration.zero);
    }
    await kap.read(kitaplarProvider.future);
    final yukleme = kap.read(kitaplarProvider.notifier).dahaFazlaYukle();
    await kap.read(kitaplarProvider.notifier).sil(25); // ilk sayfadaki bir kitap
    depo.kilit.complete();
    await yukleme;
    final son = kap.read(kitaplarProvider).value!;
    expect(son.kitaplar.map((k) => k.id), isNot(contains(25)));
    expect(son.kitaplar.map((k) => k.id).toSet().length, son.kitaplar.length); // tekrar yok
    expect(son.toplam, 29);
  });

  test('KitapListesi: daha hatası varken kendiliğinden yükleme yapılmaz', () {
    const liste = KitapListesi([Kitap(id: 1, baslik: 'a', yazar: 'b')], toplam: 5, dahaHatasi: true);
    expect(liste.dahaVar, isTrue);
    expect(liste.otomatikYuklenebilir, isFalse);
  });
}
