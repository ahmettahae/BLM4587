import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitapligim/app/app.dart';
import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/core/oturum_olaylari.dart';
import 'package:kitapligim/features/auth/auth_controller.dart';
import 'package:kitapligim/core/token_store.dart';
import 'package:kitapligim/features/auth/auth_repository.dart';
import 'package:kitapligim/features/auth/kullanici.dart';
import 'package:kitapligim/features/books/kitap_repository.dart';
import 'package:kitapligim/features/categories/kategori_repository.dart';
import 'package:kitapligim/features/shelves/raf_repository.dart';

import 'sahte_kategori_repository.dart';
import 'sahte_kitap_repository.dart';
import 'sahte_raf_repository.dart';

/// Ağa çıkmayan sahte kimlik katmanı: yalnızca kayıtlı iki kullanıcıyı tanır.
class SahteAuthRepository implements AuthRepository {
  int girisSayisi = 0;
  bool? sonBeniHatirla;
  final List<String> iptalEdilenler = [];

  @override
  Future<GirisSonucu> giris(String email, String sifre, {bool beniHatirla = false}) async {
    girisSayisi++;
    sonBeniHatirla = beniHatirla;
    if (sifre != 'dogru-sifre-1') throw ApiHata('E-posta ya da şifre hatalı', durum: 401);
    final yonetici = email.startsWith('admin');
    return GirisSonucu(
      'sahte-token',
      Kullanici(id: 1, email: email, ad: 'Test Kişi', rol: yonetici ? 'admin' : 'user'),
      yenileme: 'sahte-yenileme',
    );
  }

  @override
  Future<void> kayit(String ad, String email, String sifre) async {}

  @override
  Future<void> cikis(String yenileme) async => iptalEdilenler.add(yenileme);

  @override
  Future<Kullanici> ben() async => throw ApiHata('oturum yok', durum: 401);
}

Future<SahteAuthRepository> uygulamayiAc(WidgetTester tester, {BellekTokenStore? depo}) async {
  final sahte = SahteAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(sahte),
        tokenStoreProvider.overrideWithValue(depo ?? BellekTokenStore()),
        kitapRepositoryProvider.overrideWithValue(SahteKitapRepository()),
        kategoriRepositoryProvider.overrideWithValue(SahteKategoriRepository()),
        rafRepositoryProvider.overrideWithValue(SahteRafRepository()),
      ],
      child: const KitapligimApp(),
    ),
  );
  await tester.pumpAndSettle();
  return sahte;
}

Future<void> girisYap(WidgetTester tester, String email, {bool beniHatirla = false}) async {
  await tester.enterText(find.byKey(const Key('giris_email')), email);
  await tester.enterText(find.byKey(const Key('giris_sifre')), 'dogru-sifre-1');
  if (beniHatirla) await tester.tap(find.byKey(const Key('beni_hatirla')));
  await tester.tap(find.byKey(const Key('giris_buton')));
  await tester.pumpAndSettle();
}

/// Çıkış düğmesi profil ekranında; gezinme çubuğundan açılır.
Future<void> cikisDugmesineBas(WidgetTester tester) async {
  final profil = find.byKey(const Key('nav_profil'));
  if (profil.evaluate().isNotEmpty) {
    await tester.tap(profil);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(const Key('cikis_buton')));
  await tester.tap(find.byKey(const Key('cikis_buton')));
  await tester.pumpAndSettle();
}

Future<void> cikisYap(WidgetTester tester) async {
  await cikisDugmesineBas(tester);
  await tester.tap(find.byKey(const Key('cikis_onay')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('oturum yokken giriş ekranı açılır', (tester) async {
    await uygulamayiAc(tester);
    expect(find.text('Giriş yap'), findsWidgets);
    expect(find.byKey(const Key('giris_email')), findsOneWidget);
  });

  testWidgets('boş form gönderilince hata gösterilir, API çağrılmaz', (tester) async {
    final sahte = await uygulamayiAc(tester);
    await tester.tap(find.byKey(const Key('giris_buton')));
    await tester.pumpAndSettle();
    expect(find.text('E-posta gerekli'), findsOneWidget);
    expect(find.text('Şifre gerekli'), findsOneWidget);
    expect(sahte.girisSayisi, 0);
  });

  testWidgets('yanlış şifrede sunucu mesajı gösterilir', (tester) async {
    await uygulamayiAc(tester);
    await tester.enterText(find.byKey(const Key('giris_email')), 'kisi@ornek.com');
    await tester.enterText(find.byKey(const Key('giris_sifre')), 'yanlis-sifre-9');
    await tester.tap(find.byKey(const Key('giris_buton')));
    await tester.pumpAndSettle();
    expect(find.text('E-posta ya da şifre hatalı'), findsOneWidget);
    expect(find.byKey(const Key('cikis_buton')), findsNothing);
  });

  testWidgets('doğru girişte ana sayfa açılır, yönetici kartı görünmez; çıkışta geri dönülür', (tester) async {
    await uygulamayiAc(tester);
    await tester.enterText(find.byKey(const Key('giris_email')), 'kisi@ornek.com');
    await tester.enterText(find.byKey(const Key('giris_sifre')), 'dogru-sifre-1');
    await tester.tap(find.byKey(const Key('giris_buton')));
    await tester.pumpAndSettle();
    expect(find.text('Merhaba Test Kişi'), findsOneWidget);
    expect(find.byKey(const Key('nav_yonetim')), findsNothing);

    await cikisYap(tester);
    expect(find.byKey(const Key('giris_email')), findsOneWidget);
  });

  testWidgets('beni hatırla işaretliyse oturum ve e-posta cihaza kaydedilir, tercih sunucuya gider', (tester) async {
    final depo = BellekTokenStore();
    final sahte = await uygulamayiAc(tester, depo: depo);
    await girisYap(tester, 'kisi@ornek.com', beniHatirla: true);
    expect(sahte.sonBeniHatirla, isTrue);
    expect(depo.kaliciDepo, {'erisim': 'sahte-token', 'yenileme': 'sahte-yenileme'});
    expect(await depo.hatirlananEposta(), 'kisi@ornek.com');
    expect(await depo.beniHatirlaTercihi(), isTrue);
  });

  testWidgets('beni hatırla işaretli değilse oturum cihaza yazılmaz, e-posta unutulur', (tester) async {
    final depo = BellekTokenStore();
    await depo.epostaHatirla('eski@ornek.com');
    final sahte = await uygulamayiAc(tester, depo: depo);
    await girisYap(tester, 'kisi@ornek.com');
    expect(sahte.sonBeniHatirla, isFalse);
    expect(depo.kaliciDepo, isEmpty);
    expect(await depo.oku(), 'sahte-token'); // bellekte oturum var
    expect(await depo.hatirlananEposta(), isNull);
  });

  testWidgets('hatırlanan e-posta ve tercih giriş formuna gelir', (tester) async {
    final depo = BellekTokenStore();
    await depo.epostaHatirla('kayitli@ornek.com');
    await depo.beniHatirlaKaydet(true);
    await uygulamayiAc(tester, depo: depo);
    expect(find.widgetWithText(TextFormField, 'kayitli@ornek.com'), findsOneWidget);
    final kutu = tester.widget<CheckboxListTile>(find.byKey(const Key('beni_hatirla')));
    expect(kutu.value, isTrue);
  });

  testWidgets('çıkış onay ister; vazgeçince oturum sürer, onaylanınca yenileme token\'ı iptal edilir', (tester) async {
    final sahte = await uygulamayiAc(tester);
    await girisYap(tester, 'kisi@ornek.com');
    await cikisDugmesineBas(tester);
    expect(find.text('Çıkış yapılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('giris_email')), findsNothing);

    await cikisDugmesineBas(tester);
    await tester.tap(find.byKey(const Key('cikis_onay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('giris_email')), findsOneWidget);
    expect(sahte.iptalEdilenler, ['sahte-yenileme']);
  });

  testWidgets('ağ katmanı oturumu bitirirse giriş ekranında açıklama görünür', (tester) async {
    await uygulamayiAc(tester);
    await girisYap(tester, 'kisi@ornek.com');
    final kap = ProviderScope.containerOf(tester.element(find.byType(KitapligimApp)));
    kap.read(oturumSonaErdiProvider.notifier).bildir();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('giris_bilgi')), findsOneWidget);
    expect(find.text(oturumSonaErdiMesaji), findsOneWidget);
  });

  testWidgets('e-postada İleri tuşu şifreye geçer', (tester) async {
    await uygulamayiAc(tester);
    await tester.tap(find.byKey(const Key('giris_email')));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    final sifre = tester.widget<EditableText>(
      find.descendant(of: find.byKey(const Key('giris_sifre')), matching: find.byType(EditableText)),
    );
    expect(sifre.focusNode.hasFocus, isTrue);
  });

  testWidgets('yönetici girişinde yönetim bölümü görünür', (tester) async {
    await uygulamayiAc(tester);
    await tester.enterText(find.byKey(const Key('giris_email')), 'admin@ornek.com');
    await tester.enterText(find.byKey(const Key('giris_sifre')), 'dogru-sifre-1');
    await tester.tap(find.byKey(const Key('giris_buton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav_yonetim')), findsOneWidget);
  });

  testWidgets('kayıt ekranında şifreler uyuşmazsa hata gösterilir', (tester) async {
    await uygulamayiAc(tester);
    await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kayit_ad')), 'Ayşe');
    await tester.enterText(find.byKey(const Key('kayit_email')), 'ayse@ornek.com');
    await tester.enterText(find.byKey(const Key('kayit_sifre')), 'dogru-sifre-1');
    await tester.enterText(find.byKey(const Key('kayit_sifre_tekrar')), 'baska-sifre-22');
    await tester.tap(find.byKey(const Key('kayit_buton')));
    await tester.pumpAndSettle();
    expect(find.text('Şifreler aynı değil'), findsOneWidget);
  });

  testWidgets('küçük ekranda taşma olmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await uygulamayiAc(tester);
    expect(tester.takeException(), isNull);
  });
}
