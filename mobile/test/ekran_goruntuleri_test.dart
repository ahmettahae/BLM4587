// README için ekran görüntüleri üretir (normal test çalıştırmasında atlanır).
//   EKRAN_GORUNTUSU=1 flutter test --update-goldens test/ekran_goruntuleri_test.dart
// Çıktı: depo kökünde docs/ekranlar/*.png
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitapligim/app/app.dart';
import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/core/tercihler.dart';
import 'package:kitapligim/core/token_store.dart';
import 'package:kitapligim/features/auth/auth_repository.dart';
import 'package:kitapligim/features/auth/kullanici.dart';
import 'package:kitapligim/features/books/kitap.dart';
import 'package:kitapligim/features/books/kitap_repository.dart';
import 'package:kitapligim/features/categories/kategori.dart';
import 'package:kitapligim/features/categories/kategori_repository.dart';
import 'package:kitapligim/features/profile/profil_screen.dart';
import 'package:kitapligim/features/shelves/raf.dart';
import 'package:kitapligim/features/shelves/raf_repository.dart';

import 'sahte_kategori_repository.dart';
import 'sahte_kitap_repository.dart';
import 'sahte_raf_repository.dart';

final _calistir = Platform.environment.containsKey('EKRAN_GORUNTUSU');

class _Auth implements AuthRepository {
  _Auth({required this.oturumlu});

  final bool oturumlu;

  @override
  Future<GirisSonucu> giris(String email, String sifre, {bool beniHatirla = false}) async => throw UnimplementedError();

  @override
  Future<void> kayit(String ad, String email, String sifre) async {}

  @override
  Future<void> cikis(String yenileme) async {}

  @override
  Future<Kullanici> ben() async => const Kullanici(id: 1, email: 'yonetici@ornek.com', ad: 'Ahmet', rol: 'admin');
}

const _kitaplar = [
  Kitap(id: 8, baslik: 'Devlet', yazar: 'Platon', kategoriId: 4, yil: 1987, sayfa: 368),
  Kitap(id: 7, baslik: 'Nutuk', yazar: 'Mustafa Kemal Atatürk', kategoriId: 3, rafId: 1, sayfa: 600),
  Kitap(id: 6, baslik: 'Sapiens', yazar: 'Yuval Noah Harari', durum: KitapDurumu.okundu, puan: 4, kategoriId: 3, rafId: 3),
  Kitap(id: 5, baslik: 'Cosmos', yazar: 'Carl Sagan', durum: KitapDurumu.okunuyor, kategoriId: 2, rafId: 3),
  Kitap(id: 4, baslik: 'Kuyucaklı Yusuf', yazar: 'Sabahattin Ali', kategoriId: 1, rafId: 2),
  Kitap(
    id: 3,
    baslik: 'Saatleri Ayarlama Enstitüsü',
    yazar: 'Ahmet Hamdi Tanpınar',
    durum: KitapDurumu.okunuyor,
    kategoriId: 1,
    rafId: 1,
  ),
  Kitap(
    id: 2,
    baslik: 'Kürk Mantolu Madonna',
    yazar: 'Sabahattin Ali',
    durum: KitapDurumu.okundu,
    puan: 5,
    kategoriId: 1,
    rafId: 2,
    yayinevi: 'YKY',
    yil: 1943,
    sayfa: 160,
    not: 'Raif Efendi\'nin defteri; yeniden okunacak.',
  ),
  Kitap(id: 1, baslik: 'İnce Memed', yazar: 'Yaşar Kemal', durum: KitapDurumu.okundu, puan: 5, kategoriId: 1, rafId: 1),
];

Future<void> _fontlariYukle() async {
  final kok = Platform.environment['FLUTTER_ROOT'] ?? r'C:\dev\flutter';
  final klasor = '$kok/bin/cache/artifacts/material_fonts';
  Future<ByteData> oku(String ad) async => ByteData.sublistView(await File('$klasor/$ad').readAsBytes());
  final roboto = FontLoader('Roboto')
    ..addFont(oku('roboto-regular.ttf'))
    ..addFont(oku('roboto-medium.ttf'))
    ..addFont(oku('roboto-bold.ttf'));
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(oku('materialicons-regular.otf'))).load();
}

Future<void> _ac(WidgetTester tester, {required Size boyut, bool oturumlu = true, ThemeMode tema = ThemeMode.light}) async {
  tester.view.physicalSize = boyut * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final token = BellekTokenStore();
  if (oturumlu) await token.yaz('t');
  await token.epostaHatirla('okur@ornek.com');
  await token.beniHatirlaKaydet(true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Auth(oturumlu: oturumlu)),
        tokenStoreProvider.overrideWithValue(token),
        kitapRepositoryProvider.overrideWithValue(SahteKitapRepository(_kitaplar)),
        kategoriRepositoryProvider.overrideWithValue(SahteKategoriRepository(const [
          Kategori(id: 1, ad: 'Roman', kitapSayisi: 4),
          Kategori(id: 2, ad: 'Bilim', kitapSayisi: 1),
          Kategori(id: 3, ad: 'Tarih', kitapSayisi: 2),
          Kategori(id: 4, ad: 'Felsefe', kitapSayisi: 1),
        ])),
        rafRepositoryProvider.overrideWithValue(SahteRafRepository(const [
          Raf(id: 1, ad: 'Salon', kitapSayisi: 3),
          Raf(id: 2, ad: 'Yatak odası', kitapSayisi: 2),
          Raf(id: 3, ad: 'Çalışma masası', kitapSayisi: 2),
        ])),
        tercihDeposuProvider.overrideWithValue(BellekTercihDeposu()..degerler['tema'] = tema.name),
        surumProvider.overrideWith((ref) async => '0.6.0 (6)'),
      ],
      child: const KitapligimApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _kaydet(String ad) =>
    expectLater(find.byType(KitapligimApp), matchesGoldenFile('../../docs/ekranlar/$ad.png'));

void main() {
  setUpAll(() async {
    if (_calistir) await _fontlariYukle();
  });
  // Telefondaki gibi dokunmatik mod: masaüstü odak halkaları çizilmesin.
  setUp(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch);

  const telefon = Size(412, 892);
  const tablet = Size(1280, 800);

  testWidgets('giriş', (tester) async {
    await _ac(tester, boyut: telefon, oturumlu: false);
    await _kaydet('1-giris');
  }, skip: !_calistir);

  testWidgets('kitaplar', (tester) async {
    await _ac(tester, boyut: telefon);
    await _kaydet('2-kitaplar');
  }, skip: !_calistir);

  testWidgets('ayrıntı', (tester) async {
    await _ac(tester, boyut: telefon);
    await tester.scrollUntilVisible(find.byKey(const Key('kitap_2')), 300, scrollable: find.descendant(of: find.byKey(const Key('kitap_listesi')), matching: find.byType(Scrollable)).first);
    await tester.tap(find.byKey(const Key('kitap_2')));
    await tester.pumpAndSettle();
    await _kaydet('3-ayrinti');
  }, skip: !_calistir);

  testWidgets('raflar', (tester) async {
    await _ac(tester, boyut: telefon);
    await tester.tap(find.byKey(const Key('nav_raflar')));
    await tester.pumpAndSettle();
    await _kaydet('4-raflar');
  }, skip: !_calistir);

  testWidgets('profil koyu', (tester) async {
    await _ac(tester, boyut: telefon, tema: ThemeMode.dark);
    await tester.tap(find.byKey(const Key('nav_profil')));
    await tester.pumpAndSettle();
    await _kaydet('5-profil-koyu');
  }, skip: !_calistir);

  testWidgets('tablet', (tester) async {
    await _ac(tester, boyut: tablet);
    await tester.scrollUntilVisible(find.byKey(const Key('kitap_2')), 300, scrollable: find.descendant(of: find.byKey(const Key('kitap_listesi')), matching: find.byType(Scrollable)).first);
    await tester.tap(find.byKey(const Key('kitap_2')));
    await tester.pumpAndSettle();
    await _kaydet('6-tablet');
  }, skip: !_calistir);
}
