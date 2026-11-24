import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitapligim/app/app.dart';
import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/core/tercihler.dart';
import 'package:kitapligim/core/token_store.dart';
import 'package:kitapligim/features/auth/auth_repository.dart';
import 'package:kitapligim/features/auth/kullanici.dart';
import 'package:kitapligim/features/books/kitap.dart';
import 'package:kitapligim/features/books/kitap_filtresi.dart';
import 'package:kitapligim/features/books/kitap_repository.dart';
import 'package:kitapligim/features/categories/kategori_repository.dart';
import 'package:kitapligim/features/profile/profil_screen.dart';
import 'package:kitapligim/features/shelves/raf_repository.dart';

import 'sahte_kategori_repository.dart';
import 'sahte_kitap_repository.dart';
import 'sahte_raf_repository.dart';

class _Auth implements AuthRepository {
  _Auth(this.rol);

  final String rol;

  @override
  Future<GirisSonucu> giris(String email, String sifre, {bool beniHatirla = false}) async => throw UnimplementedError();

  @override
  Future<void> kayit(String ad, String email, String sifre) async {}

  @override
  Future<void> cikis(String yenileme) async {}

  @override
  Future<Kullanici> ben() async => Kullanici(id: 7, email: 'okur@ornek.com', ad: 'Okur', rol: rol);
}

/// İlk liste isteğini [kilit] tamamlanana kadar bekletir (yükleniyor görünümü için).
class _YavasKitapRepository extends SahteKitapRepository {
  _YavasKitapRepository(super.baslangic);

  final kilit = Completer<void>();

  @override
  Future<KitapSayfasi> sayfa(KitapFiltresi filtre, {int offset = 0, int limit = KitapRepository.sayfaBoyutu}) async {
    await kilit.future;
    return super.sayfa(filtre, offset: offset, limit: limit);
  }
}

List<Kitap> kitaplar(int adet) => [
      for (var i = adet; i >= 1; i--)
        Kitap(id: i, baslik: 'Kitap $i', yazar: 'Yazar $i', durum: i.isEven ? KitapDurumu.okundu : KitapDurumu.okunacak),
    ];

Future<SahteKitapRepository> ac(
  WidgetTester tester, {
  SahteKitapRepository? depo,
  List<Kitap> liste = const [],
  String rol = 'user',
  Size boyut = const Size(800, 1600),
  BellekTercihDeposu? tercihler,
  bool bekle = true,
}) async {
  tester.view.physicalSize = boyut;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final token = BellekTokenStore();
  await token.yaz('sahte-token');
  final kitapDeposu = depo ?? SahteKitapRepository(liste);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Auth(rol)),
        tokenStoreProvider.overrideWithValue(token),
        kitapRepositoryProvider.overrideWithValue(kitapDeposu),
        kategoriRepositoryProvider.overrideWithValue(SahteKategoriRepository()),
        rafRepositoryProvider.overrideWithValue(SahteRafRepository()),
        tercihDeposuProvider.overrideWithValue(tercihler ?? BellekTercihDeposu()),
        surumProvider.overrideWith((ref) async => '0.6.0 (6)'),
      ],
      child: const KitapligimApp(),
    ),
  );
  if (bekle) await tester.pumpAndSettle();
  return kitapDeposu;
}

String metin(WidgetTester tester, String anahtar) => tester.widget<Text>(find.byKey(Key(anahtar))).data!;

void main() {
  testWidgets('özet kartı toplam, okunan ve okunan sayısını gösterir', (tester) async {
    await ac(tester, liste: kitaplar(4));
    expect(find.byKey(const Key('ozet_karti')), findsOneWidget);
    expect(metin(tester, 'ozet_toplam'), '4');
    expect(metin(tester, 'ozet_okundu'), '2');
    expect(find.text("Kitaplığının %50'ini okudun"), findsOneWidget);
    expect(metin(tester, 'kitaplarim_basligi'), 'Kitaplarım · 4');
  });

  testWidgets('kitap yokken özet kartı görünmez, boş durum açıklaması görünür', (tester) async {
    await ac(tester);
    expect(find.byKey(const Key('ozet_karti')), findsNothing);
    expect(find.text('Kitaplığın boş'), findsOneWidget);
  });

  testWidgets('sıralama seçimi sunucuya gider ve liste o sırayla gelir', (tester) async {
    final depo = await ac(tester, liste: const [
      Kitap(id: 1, baslik: 'Zeytin', yazar: 'A'),
      Kitap(id: 2, baslik: 'Armut', yazar: 'B'),
    ]);
    await tester.tap(find.byKey(const Key('siralama')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('siralama_baslik')));
    await tester.pumpAndSettle();
    expect(depo.sonFiltre?.siralama, KitapSiralama.baslik);
    expect(depo.sonFiltre?.toQuery()['sort'], 'baslik');
    final armut = tester.getTopLeft(find.byKey(const Key('kitap_2'))).dy;
    final zeytin = tester.getTopLeft(find.byKey(const Key('kitap_1'))).dy;
    expect(armut, lessThan(zeytin));
    // "Temizle" süzmeyi kaldırır ama sıralamayı değil.
    expect(find.byKey(const Key('filtre_temizle')), findsNothing);
  });

  testWidgets('aşağı kaydırınca sonraki sayfa yüklenir', (tester) async {
    final depo = await ac(tester, liste: kitaplar(45));
    expect(depo.istenenOffsetler, [0]);
    expect(find.byKey(const Key('kitap_45')), findsOneWidget); // ilk sayfa: 45..26
    await tester.dragUntilVisible(
      find.byKey(const Key('kitap_26')),
      find.byKey(const Key('kitap_listesi')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(depo.istenenOffsetler, contains(20));
    await tester.dragUntilVisible(
      find.byKey(const Key('kitap_1')),
      find.byKey(const Key('kitap_listesi')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(depo.istenenOffsetler, [0, 20, 40]);
    expect(find.byKey(const Key('kitap_1')), findsOneWidget);
  });

  testWidgets('liste yüklenirken iskelet görünür, sonra kitaplar gelir', (tester) async {
    final depo = _YavasKitapRepository(kitaplar(2));
    await ac(tester, depo: depo, bekle: false);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('iskelet_liste')), findsOneWidget);
    depo.kilit.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('iskelet_liste')), findsNothing);
    expect(find.byKey(const Key('kitap_1')), findsOneWidget);
  });

  testWidgets('liste hatasında anlaşılır mesaj ve Tekrar dene çalışır', (tester) async {
    final depo = SahteKitapRepository(kitaplar(1))
      ..kaliciListeHatasi = 'Sunucuya ulaşılamadı. İnternet ya da Wi-Fi bağlantını kontrol et.';
    await ac(tester, depo: depo);
    expect(find.byKey(const Key('kitap_liste_hata')), findsOneWidget);
    expect(find.text('Kitaplar yüklenemedi'), findsOneWidget);
    expect(find.text('Sunucuya ulaşılamadı. İnternet ya da Wi-Fi bağlantını kontrol et.'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    depo.kaliciListeHatasi = null; // bağlantı geri geldi
    await tester.tap(find.byKey(const Key('tekrar_dene')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kitap_1')), findsOneWidget);
  });

  testWidgets('silinen kitap "Geri al" ile geri gelir', (tester) async {
    final depo = await ac(tester, liste: const [Kitap(id: 5, baslik: 'Cosmos', yazar: 'Carl Sagan', puan: 5)]);
    await tester.tap(find.byKey(const Key('kitap_5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kitap_sil')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('silme_onay')));
    await tester.pumpAndSettle();
    expect(depo.kitaplar, isEmpty);
    expect(find.text('"Cosmos" silindi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('silmeyi_geri_al')));
    await tester.pumpAndSettle();
    expect(depo.kitaplar.single.baslik, 'Cosmos');
    expect(depo.kitaplar.single.puan, 5);
    expect(find.text('Cosmos'), findsOneWidget);
  });

  testWidgets('ISBN\'siz kitapta baş harfli kapak çizilir', (tester) async {
    await ac(tester, liste: const [Kitap(id: 1, baslik: 'Kürk Mantolu Madonna', yazar: 'Sabahattin Ali')]);
    expect(find.descendant(of: find.byKey(const Key('kitap_1')), matching: find.text('KM')), findsOneWidget);
  });

  testWidgets('normal kullanıcıda gezinme: Kitaplar, Raflar, Profil (Yönetim yok)', (tester) async {
    await ac(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('nav_kitaplar')), findsOneWidget);
    expect(find.byKey(const Key('nav_raflar')), findsOneWidget);
    expect(find.byKey(const Key('nav_profil')), findsOneWidget);
    expect(find.byKey(const Key('nav_yonetim')), findsNothing);
  });

  testWidgets('tablette yan gezinme; kitaba dokununca ayrıntı yanda açılır', (tester) async {
    await ac(tester, liste: kitaplar(3), rol: 'admin', boyut: const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('detay_bos')), findsOneWidget);
    await tester.tap(find.byKey(const Key('kitap_2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detay_paneli')), findsOneWidget);
    expect(find.byKey(const Key('kitap_listesi')), findsOneWidget); // liste hâlâ görünür
    expect(find.descendant(of: find.byKey(const Key('detay_paneli')), matching: find.text('Kitap 2')), findsOneWidget);
    // Yanda açık kitabı silince panel kapanır.
    await tester.tap(find.byKey(const Key('kitap_sil')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('silme_onay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detay_paneli')), findsNothing);
    expect(find.byKey(const Key('kitap_2')), findsNothing);
  });

  testWidgets('tablette yan gezinmeden yönetim ve raflar açılır', (tester) async {
    await ac(tester, rol: 'admin', boyut: const Size(1280, 800));
    await tester.tap(find.byKey(const Key('nav_yonetim')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kategori_yonetim_baslik')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav_raflar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('raflar_baslik')), findsOneWidget);
  });

  testWidgets('profil: ad, rol, sürüm görünür; tema seçimi kaydedilir', (tester) async {
    final tercihler = BellekTercihDeposu();
    await ac(tester, tercihler: tercihler, rol: 'admin');
    await tester.tap(find.byKey(const Key('nav_profil')));
    await tester.pumpAndSettle();
    expect(metin(tester, 'profil_ad'), 'Okur');
    expect(find.descendant(of: find.byKey(const Key('profil_rol')), matching: find.text('Yönetici')), findsOneWidget);
    expect(metin(tester, 'profil_surum'), '0.6.0 (6)');
    await tester.tap(find.text('Koyu'));
    await tester.pumpAndSettle();
    expect(tercihler.degerler['tema'], 'dark');
    expect(Theme.of(tester.element(find.byKey(const Key('profil_ad')))).brightness, Brightness.dark);
  });

  testWidgets('küçük ekranda yeni ana sayfa ve profil taşmaz', (tester) async {
    await ac(tester, liste: kitaplar(3), boyut: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('nav_profil')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
