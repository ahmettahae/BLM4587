import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitapligim/app/app.dart';
import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/core/token_store.dart';
import 'package:kitapligim/features/auth/auth_repository.dart';
import 'package:kitapligim/features/auth/kullanici.dart';
import 'package:kitapligim/features/books/kitap.dart';
import 'package:kitapligim/features/books/kitap_repository.dart';
import 'package:kitapligim/features/categories/kategori_repository.dart';
import 'package:kitapligim/features/shelves/raf.dart';
import 'package:kitapligim/features/shelves/raf_repository.dart';

import 'sahte_kategori_repository.dart';
import 'sahte_kitap_repository.dart';
import 'sahte_raf_repository.dart';

class _OturumluAuth implements AuthRepository {
  @override
  Future<GirisSonucu> giris(String email, String sifre, {bool beniHatirla = false}) async => throw UnimplementedError();

  @override
  Future<void> kayit(String ad, String email, String sifre) async {}

  @override
  Future<void> cikis(String yenileme) async {}

  @override
  Future<Kullanici> ben() async => const Kullanici(id: 7, email: 'okur@ornek.com', ad: 'Okur', rol: 'user');
}

const _salon = Raf(id: 1, ad: 'Salon', kitapSayisi: 2);
const _yatak = Raf(id: 2, ad: 'Yatak odası');

class RafOrtami {
  RafOrtami(this.kitaplar, this.raflar);

  final SahteKitapRepository kitaplar;
  final SahteRafRepository raflar;
}

Future<RafOrtami> rafAc(
  WidgetTester tester, {
  List<Raf> raflar = const [_salon, _yatak],
  List<Kitap> kitaplar = const [],
  bool uzunEkran = true,
}) async {
  if (uzunEkran) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  final depo = BellekTokenStore();
  await depo.yaz('sahte-token');
  final ortam = RafOrtami(SahteKitapRepository(kitaplar), SahteRafRepository(raflar));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_OturumluAuth()),
        tokenStoreProvider.overrideWithValue(depo),
        kitapRepositoryProvider.overrideWithValue(ortam.kitaplar),
        kategoriRepositoryProvider.overrideWithValue(SahteKategoriRepository()),
        rafRepositoryProvider.overrideWithValue(ortam.raflar),
      ],
      child: const KitapligimApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ortam;
}

/// Raflar sekmesini gezinme çubuğundan açar.
Future<void> raflarAc(WidgetTester tester) async {
  final sekme = find.byKey(const Key('nav_raflar'));
  await tester.tap(sekme);
  await tester.pumpAndSettle();
}

/// Kitap listesine döner (gezinme çubuğu varsa Kitaplar sekmesi, yoksa geri düğmesi).
Future<void> kitaplaraDon(WidgetTester tester) async {
  final sekme = find.byKey(const Key('nav_kitaplar'));
  await tester.tap(sekme.evaluate().isNotEmpty ? sekme : find.byType(BackButton));
  await tester.pumpAndSettle();
}

Future<void> adYazKaydet(WidgetTester tester, String ad) async {
  await tester.enterText(find.byKey(const Key('raf_ad_alani')), ad);
  await tester.tap(find.byKey(const Key('raf_kaydet')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Raflarım kartı raf ekranını açar; raflar kitap sayısıyla listelenir', (tester) async {
    await rafAc(tester);
    await raflarAc(tester);
    expect(find.byKey(const Key('raflar_baslik')), findsOneWidget);
    expect(find.text('Salon'), findsOneWidget);
    expect(find.text('2 kitap'), findsOneWidget);
    expect(find.text('0 kitap'), findsOneWidget);
  });

  testWidgets('raf yokken boş durum mesajı gösterilir', (tester) async {
    await rafAc(tester, raflar: const []);
    await raflarAc(tester);
    expect(find.byKey(const Key('raf_liste_bos')), findsOneWidget);
  });

  testWidgets('raf eklenir ve listede görünür', (tester) async {
    final ortam = await rafAc(tester);
    await raflarAc(tester);
    await tester.tap(find.byKey(const Key('raf_ekle_buton')));
    await tester.pumpAndSettle();
    await adYazKaydet(tester, '  Mutfak  ');
    expect(find.text('Mutfak'), findsOneWidget);
    expect(ortam.raflar.raflar.last.ad, 'Mutfak');
  });

  testWidgets('boş ad kaydedilmez, doğrulama mesajı görünür', (tester) async {
    final ortam = await rafAc(tester);
    await raflarAc(tester);
    await tester.tap(find.byKey(const Key('raf_ekle_buton')));
    await tester.pumpAndSettle();
    await adYazKaydet(tester, '   ');
    expect(find.text('Ad gerekli'), findsOneWidget);
    expect(ortam.raflar.raflar, hasLength(2));
  });

  testWidgets('aynı ad sunucu hatasını pencerede gösterir', (tester) async {
    await rafAc(tester);
    await raflarAc(tester);
    await tester.tap(find.byKey(const Key('raf_ekle_buton')));
    await tester.pumpAndSettle();
    await adYazKaydet(tester, 'salon');
    expect(find.byKey(const Key('raf_hata')), findsOneWidget);
    expect(find.text('Bu adda bir raf zaten var'), findsOneWidget);
  });

  testWidgets('raf yeniden adlandırılır', (tester) async {
    final ortam = await rafAc(tester);
    await raflarAc(tester);
    await tester.tap(find.byKey(const Key('raf_duzenle_2')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Yatak odası'), findsOneWidget);
    await adYazKaydet(tester, 'Çalışma odası');
    expect(find.text('Çalışma odası'), findsOneWidget);
    expect(ortam.raflar.raflar.last.ad, 'Çalışma odası');
  });

  testWidgets('raf onaydan sonra silinir; vazgeçince kalır', (tester) async {
    final ortam = await rafAc(tester);
    await raflarAc(tester);
    await tester.tap(find.byKey(const Key('raf_sil_1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 kitap silinmez'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('raf_1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('raf_sil_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('raf_silme_onay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('raf_1')), findsNothing);
    expect(ortam.raflar.raflar.map((r) => r.id), [2]);
  });

  testWidgets('kitap formunda raf seçilir; detayda raf adı görünür', (tester) async {
    final ortam = await rafAc(tester);
    await tester.tap(find.byKey(const Key('kitap_ekle_buton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kitap_baslik')), 'Cosmos');
    await tester.enterText(find.byKey(const Key('kitap_yazar')), 'Carl Sagan');
    await tester.tap(find.byKey(const Key('raf_secici')));
    await tester.pumpAndSettle();
    expect(find.text('Raf yok'), findsWidgets);
    await tester.tap(find.text('Yatak odası').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('kitap_kaydet')));
    await tester.tap(find.byKey(const Key('kitap_kaydet')));
    await tester.pumpAndSettle();
    expect(ortam.kitaplar.kitaplar.first.rafId, 2);

    await tester.tap(find.byKey(Key('kitap_${ortam.kitaplar.kitaplar.first.id}')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(const Key('kitap_raf_etiketi')), matching: find.text('Yatak odası')),
      findsOneWidget,
    );
  });

  testWidgets('kitap ekleme, düzenleme ve silme raf kitap sayılarını tazeler', (tester) async {
    final ortam = await rafAc(tester, kitaplar: const [Kitap(id: 5, baslik: 'Kitap', yazar: 'Yazar', rafId: 1)]);
    final ilk = ortam.raflar.listelemeSayisi;

    await tester.tap(find.byKey(const Key('kitap_ekle_buton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kitap_baslik')), 'Cosmos');
    await tester.enterText(find.byKey(const Key('kitap_yazar')), 'Carl Sagan');
    await tester.ensureVisible(find.byKey(const Key('kitap_kaydet')));
    await tester.tap(find.byKey(const Key('kitap_kaydet')));
    await tester.pumpAndSettle();
    expect(ortam.raflar.listelemeSayisi, greaterThan(ilk));

    final eklemeSonrasi = ortam.raflar.listelemeSayisi;
    await tester.tap(find.byKey(const Key('kitap_5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kitap_sil')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('silme_onay')));
    await tester.pumpAndSettle();
    expect(ortam.raflar.listelemeSayisi, greaterThan(eklemeSonrasi));
  });

  testWidgets('düzenlemede mevcut raf seçili gelir ve korunur', (tester) async {
    final ortam = await rafAc(tester, kitaplar: const [Kitap(id: 5, baslik: 'Kitap', yazar: 'Yazar', rafId: 1)]);
    await tester.tap(find.byKey(const Key('kitap_5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kitap_duzenle')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('raf_secici')), matching: find.text('Salon')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('kitap_kaydet')));
    await tester.tap(find.byKey(const Key('kitap_kaydet')));
    await tester.pumpAndSettle();
    expect(ortam.kitaplar.kitaplar.single.rafId, 1);
  });

  testWidgets('rafsız kitabın detayında raf etiketi yok', (tester) async {
    await rafAc(tester, kitaplar: const [Kitap(id: 5, baslik: 'Kitap', yazar: 'Yazar')]);
    await tester.tap(find.byKey(const Key('kitap_5')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kitap_raf_etiketi')), findsNothing);
  });

  testWidgets('küçük ekranda raf ekranı ve penceresi taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await rafAc(tester, uzunEkran: false);
    await raflarAc(tester);
    await tester.tap(find.byKey(const Key('raf_ekle_buton')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
