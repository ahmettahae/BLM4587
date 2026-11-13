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

import 'sahte_kitap_repository.dart';

/// Kayıtlı anahtarla açılışta oturumu hemen geri yükleyen sahte kimlik katmanı.
class OturumluAuthRepository implements AuthRepository {
  @override
  Future<GirisSonucu> giris(String email, String sifre) async => throw UnimplementedError();

  @override
  Future<void> kayit(String ad, String email, String sifre) async {}

  @override
  Future<Kullanici> ben() async => const Kullanici(id: 7, email: 'okur@ornek.com', ad: 'Okur', rol: 'user');
}

const _tutunamayanlar = Kitap(
  id: 1,
  baslik: 'Tutunamayanlar',
  yazar: 'Oğuz Atay',
  isbn: '9789754700905',
  yil: 1972,
  sayfa: 724,
  kategoriId: 3,
);

/// Uygulamayı giriş yapılmış hâlde açar. Form tek ekrana sığsın diye ekran uzun tutulur
/// (ListView ekran dışındaki alanları oluşturmaz); küçük ekran testi [uzunEkran]=false verir.
Future<SahteKitapRepository> acik(WidgetTester tester, {List<Kitap> kitaplar = const [], bool uzunEkran = true}) async {
  if (uzunEkran) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  final depo = BellekTokenStore();
  await depo.yaz('sahte-token');
  final kitapDeposu = SahteKitapRepository(kitaplar);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(OturumluAuthRepository()),
        tokenStoreProvider.overrideWithValue(depo),
        kitapRepositoryProvider.overrideWithValue(kitapDeposu),
      ],
      child: const KitapligimApp(),
    ),
  );
  await tester.pumpAndSettle();
  return kitapDeposu;
}

Future<void> kaydet(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('kitap_kaydet')));
  await tester.tap(find.byKey(const Key('kitap_kaydet')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kitap yokken boş liste mesajı gösterilir', (tester) async {
    await acik(tester);
    expect(find.text('Merhaba Okur'), findsOneWidget);
    expect(find.byKey(const Key('kitap_liste_bos')), findsOneWidget);
  });

  testWidgets('kitap ekleme: boş ve hatalı form gönderilmez, doğrusu listeye eklenir', (tester) async {
    final kitaplar = await acik(tester);
    await tester.tap(find.byKey(const Key('kitap_ekle_buton')));
    await tester.pumpAndSettle();

    await kaydet(tester);
    expect(find.text('Başlık gerekli'), findsOneWidget);
    expect(find.text('Yazar gerekli'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('kitap_baslik')), '  Kürk Mantolu Madonna ');
    await tester.enterText(find.byKey(const Key('kitap_yazar')), 'Sabahattin Ali');
    await tester.enterText(find.byKey(const Key('kitap_isbn')), '12345');
    await kaydet(tester);
    expect(find.text('ISBN 10 ya da 13 haneli olmalı'), findsOneWidget);
    expect(kitaplar.kitaplar, isEmpty);

    await tester.enterText(find.byKey(const Key('kitap_isbn')), '978-975-08-0631-1');
    await tester.enterText(find.byKey(const Key('kitap_yil')), '1943');
    await tester.tap(find.text('Okunuyor'));
    await tester.ensureVisible(find.byKey(const Key('puan_4')));
    await tester.tap(find.byKey(const Key('puan_4')));
    await kaydet(tester);

    final eklenen = kitaplar.kitaplar.single;
    expect(eklenen.baslik, 'Kürk Mantolu Madonna');
    expect(eklenen.isbn, '9789750806311');
    expect(eklenen.yil, 1943);
    expect(eklenen.durum, KitapDurumu.okunuyor);
    expect(eklenen.puan, 4);
    expect(find.byKey(Key('kitap_${eklenen.id}')), findsOneWidget);
    expect(find.text('Kitap eklendi'), findsOneWidget);
  });

  testWidgets('sunucu hatası formda gösterilir, ekran kapanmaz', (tester) async {
    final kitaplar = await acik(tester);
    kitaplar.sonrakiHata = 'Kategori bulunamadı';
    await tester.tap(find.byKey(const Key('kitap_ekle_buton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kitap_baslik')), 'A');
    await tester.enterText(find.byKey(const Key('kitap_yazar')), 'B');
    await kaydet(tester);
    expect(find.byKey(const Key('kitap_hata')), findsOneWidget);
    expect(find.text('Kategori bulunamadı'), findsOneWidget);
    expect(find.byKey(const Key('kitap_kaydet')), findsOneWidget);
  });

  testWidgets('detay ve düzenleme: değişiklik kaydedilir, kategori korunur', (tester) async {
    final kitaplar = await acik(tester, kitaplar: [_tutunamayanlar]);
    await tester.tap(find.byKey(const Key('kitap_1')));
    await tester.pumpAndSettle();
    expect(find.text('Oğuz Atay'), findsOneWidget);
    expect(find.text('9789754700905'), findsOneWidget);

    await tester.tap(find.byKey(const Key('kitap_duzenle')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Tutunamayanlar'), findsOneWidget);
    await tester.tap(find.text('Okundu'));
    await tester.enterText(find.byKey(const Key('kitap_sayfa')), '');
    await kaydet(tester);

    final guncel = kitaplar.kitaplar.single;
    expect(guncel.durum, KitapDurumu.okundu);
    expect(guncel.sayfa, isNull);
    expect(guncel.kategoriId, 3);
    // Detay ekranına dönüldü ve güncel bilgi görünüyor.
    expect(find.byKey(const Key('kitap_duzenle')), findsOneWidget);
    expect(find.text('Okundu'), findsOneWidget);
  });

  testWidgets('silme onay ister; vazgeçince silinmez, onaylayınca listeden kalkar', (tester) async {
    final kitaplar = await acik(tester, kitaplar: [_tutunamayanlar]);
    await tester.tap(find.byKey(const Key('kitap_1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kitap_sil')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(kitaplar.kitaplar, hasLength(1));

    await tester.tap(find.byKey(const Key('kitap_sil')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('silme_onay')));
    await tester.pumpAndSettle();
    expect(kitaplar.kitaplar, isEmpty);
    expect(find.byKey(const Key('kitap_liste_bos')), findsOneWidget);
  });

  testWidgets('küçük ekranda form ve liste taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await acik(tester, kitaplar: [_tutunamayanlar], uzunEkran: false);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('kitap_ekle_buton')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
