import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitapligim/app/app.dart';
import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/core/token_store.dart';
import 'package:kitapligim/features/auth/auth_repository.dart';
import 'package:kitapligim/features/auth/kullanici.dart';
import 'package:kitapligim/features/books/kitap_repository.dart';
import 'package:kitapligim/features/categories/kategori_repository.dart';

import 'sahte_kategori_repository.dart';
import 'sahte_kitap_repository.dart';

/// Ağa çıkmayan sahte kimlik katmanı: yalnızca kayıtlı iki kullanıcıyı tanır.
class SahteAuthRepository implements AuthRepository {
  int girisSayisi = 0;

  @override
  Future<GirisSonucu> giris(String email, String sifre) async {
    girisSayisi++;
    if (sifre != 'dogru-sifre-1') throw ApiHata('E-posta ya da şifre hatalı', durum: 401);
    final yonetici = email.startsWith('admin');
    return GirisSonucu(
      'sahte-token',
      Kullanici(id: 1, email: email, ad: 'Test Kişi', rol: yonetici ? 'admin' : 'user'),
    );
  }

  @override
  Future<void> kayit(String ad, String email, String sifre) async {}

  @override
  Future<Kullanici> ben() async => throw ApiHata('oturum yok', durum: 401);
}

Future<SahteAuthRepository> uygulamayiAc(WidgetTester tester) async {
  final sahte = SahteAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(sahte),
        tokenStoreProvider.overrideWithValue(BellekTokenStore()),
        kitapRepositoryProvider.overrideWithValue(SahteKitapRepository()),
        kategoriRepositoryProvider.overrideWithValue(SahteKategoriRepository()),
      ],
      child: const KitapligimApp(),
    ),
  );
  await tester.pumpAndSettle();
  return sahte;
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
    expect(find.byKey(const Key('yonetici_karti')), findsNothing);

    await tester.tap(find.byKey(const Key('cikis_buton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('giris_email')), findsOneWidget);
  });

  testWidgets('yönetici girişinde yönetim bölümü görünür', (tester) async {
    await uygulamayiAc(tester);
    await tester.enterText(find.byKey(const Key('giris_email')), 'admin@ornek.com');
    await tester.enterText(find.byKey(const Key('giris_sifre')), 'dogru-sifre-1');
    await tester.tap(find.byKey(const Key('giris_buton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('yonetici_karti')), findsOneWidget);
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
