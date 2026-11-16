import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kitapligim/app/app.dart';
import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/core/token_store.dart';
import 'package:kitapligim/features/auth/auth_repository.dart';
import 'package:kitapligim/features/auth/kullanici.dart';
import 'package:kitapligim/features/books/kitap.dart';
import 'package:kitapligim/features/books/kitap_repository.dart';
import 'package:kitapligim/features/categories/kategori.dart';
import 'package:kitapligim/features/categories/kategori_repository.dart';
import 'package:kitapligim/features/home/home_screen.dart';

import 'sahte_kategori_repository.dart';
import 'sahte_kitap_repository.dart';

/// Açılışta oturumu verilen rolle geri yükleyen sahte kimlik katmanı.
class RolluAuthRepository implements AuthRepository {
  RolluAuthRepository(this.rol);

  final String rol;

  @override
  Future<GirisSonucu> giris(String email, String sifre) async => throw UnimplementedError();

  @override
  Future<void> kayit(String ad, String email, String sifre) async {}

  @override
  Future<Kullanici> ben() async => Kullanici(id: 7, email: 'kisi@ornek.com', ad: 'Kişi', rol: rol);
}

const _roman = Kategori(id: 1, ad: 'Roman', aciklama: 'Kurgu', kitapSayisi: 2);
const _bilim = Kategori(id: 2, ad: 'Bilim');

class Ortam {
  Ortam(this.kitaplar, this.kategoriler);

  final SahteKitapRepository kitaplar;
  final SahteKategoriRepository kategoriler;
}

Future<Ortam> ac(
  WidgetTester tester, {
  String rol = 'admin',
  List<Kategori> kategoriler = const [_roman, _bilim],
  List<Kitap> kitaplar = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final depo = BellekTokenStore();
  await depo.yaz('sahte-token');
  final ortam = Ortam(SahteKitapRepository(kitaplar), SahteKategoriRepository(kategoriler));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(RolluAuthRepository(rol)),
        tokenStoreProvider.overrideWithValue(depo),
        kitapRepositoryProvider.overrideWithValue(ortam.kitaplar),
        kategoriRepositoryProvider.overrideWithValue(ortam.kategoriler),
      ],
      child: const KitapligimApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ortam;
}

Future<void> yonetimAc(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('yonetici_karti')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('yönetici kartı kategori ekranını açar; kategoriler kitap sayısıyla listelenir', (tester) async {
    await ac(tester);
    await yonetimAc(tester);
    expect(find.byKey(const Key('kategori_yonetim_baslik')), findsOneWidget);
    expect(find.text('Roman'), findsOneWidget);
    expect(find.text('Kurgu · 2 kitap'), findsOneWidget);
    expect(find.text('0 kitap'), findsOneWidget);
  });

  testWidgets('kategori yokken boş durum mesajı gösterilir', (tester) async {
    await ac(tester, kategoriler: const []);
    await yonetimAc(tester);
    expect(find.byKey(const Key('kategori_liste_bos')), findsOneWidget);
  });

  testWidgets('ekleme: boş ad reddedilir, aynı ad sunucu mesajıyla gösterilir, geçerli ad listeye girer', (tester) async {
    final ortam = await ac(tester);
    await yonetimAc(tester);
    await tester.tap(find.byKey(const Key('kategori_ekle_buton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kategori_kaydet')));
    await tester.pumpAndSettle();
    expect(find.text('Ad gerekli'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('kategori_ad')), 'roman');
    await tester.tap(find.byKey(const Key('kategori_kaydet')));
    await tester.pumpAndSettle();
    expect(find.text('Bu adda bir kategori zaten var'), findsOneWidget);
    expect(ortam.kategoriler.kategoriler, hasLength(2));

    await tester.enterText(find.byKey(const Key('kategori_ad')), '  Tarih ');
    await tester.enterText(find.byKey(const Key('kategori_aciklama')), 'Geçmiş');
    await tester.tap(find.byKey(const Key('kategori_kaydet')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kategori_ad')), findsNothing); // pencere kapandı
    expect(ortam.kategoriler.kategoriler.last.ad, 'Tarih');
    expect(find.text('Tarih'), findsOneWidget);
    expect(find.text('Geçmiş · 0 kitap'), findsOneWidget);
  });

  testWidgets('düzenleme: mevcut değerler formda gelir, kayıt listeyi günceller', (tester) async {
    await ac(tester);
    await yonetimAc(tester);
    await tester.tap(find.byKey(const Key('kategori_duzenle_1')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Roman'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('kategori_ad')), 'Edebiyat');
    await tester.tap(find.byKey(const Key('kategori_kaydet')));
    await tester.pumpAndSettle();

    expect(find.text('Edebiyat'), findsOneWidget);
    expect(find.text('Roman'), findsNothing);
  });

  testWidgets('silme: kitap sayısı uyarılır; vazgeçince kalır, onaylayınca kalkar', (tester) async {
    final ortam = await ac(tester);
    await yonetimAc(tester);

    await tester.tap(find.byKey(const Key('kategori_sil_1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 kitap silinmez'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(ortam.kategoriler.kategoriler, hasLength(2));

    await tester.tap(find.byKey(const Key('kategori_sil_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kategori_silme_onay')));
    await tester.pumpAndSettle();
    expect(ortam.kategoriler.kategoriler.map((k) => k.ad), ['Bilim']);
    expect(find.byKey(const Key('kategori_1')), findsNothing);
    expect(find.text('Kategori silindi'), findsOneWidget);
  });

  testWidgets('normal kullanıcı yönetim kartını görmez; adresi açmaya çalışsa ana sayfada kalır', (tester) async {
    await ac(tester, rol: 'user');
    expect(find.byKey(const Key('yonetici_karti')), findsNothing);

    GoRouter.of(tester.element(find.byType(HomeScreen))).go('/yonetim/kategoriler');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kategori_yonetim_baslik')), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('kitap formunda kategori seçilir ve kitaba yazılır', (tester) async {
    final ortam = await ac(tester, rol: 'user');
    await tester.tap(find.byKey(const Key('kitap_ekle_buton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kitap_baslik')), 'Cosmos');
    await tester.enterText(find.byKey(const Key('kitap_yazar')), 'Carl Sagan');

    await tester.tap(find.byKey(const Key('kitap_kategori')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bilim').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('kitap_kaydet')));
    await tester.tap(find.byKey(const Key('kitap_kaydet')));
    await tester.pumpAndSettle();

    expect(ortam.kitaplar.kitaplar.single.kategoriId, 2);
  });

  testWidgets('listede "yazar · kategori" görünür, detayda kategori etiketi gösterilir', (tester) async {
    await ac(
      tester,
      rol: 'user',
      kitaplar: const [Kitap(id: 1, baslik: 'Tutunamayanlar', yazar: 'Oğuz Atay', kategoriId: 1)],
    );
    expect(find.text('Oğuz Atay · Roman'), findsOneWidget);
    await tester.tap(find.byKey(const Key('kitap_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kitap_kategori_etiketi')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('kitap_kategori_etiketi')), matching: find.text('Roman')), findsOneWidget);
  });

  testWidgets('küçük ekranda yönetim ekranı ve kategori penceresi taşmaz', (tester) async {
    await ac(tester);
    tester.view.physicalSize = const Size(320, 480);
    await tester.pumpAndSettle();
    await yonetimAc(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('kategori_ekle_buton')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
