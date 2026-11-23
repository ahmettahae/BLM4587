import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitapligim/features/books/kitap.dart';
import 'package:kitapligim/features/shelves/raf.dart';

import 'raf_akisi_test.dart' show rafAc, raflarAc;

const _kitaplar = [
  Kitap(id: 1, baslik: 'Tutunamayanlar', yazar: 'Oğuz Atay', durum: KitapDurumu.okundu, rafId: 1),
  Kitap(id: 2, baslik: 'Saatleri Ayarlama Enstitüsü', yazar: 'Ahmet Hamdi Tanpınar', rafId: 2),
  Kitap(id: 3, baslik: 'Kürk Mantolu Madonna', yazar: 'Sabahattin Ali', durum: KitapDurumu.okundu),
];
const _raflar = [Raf(id: 1, ad: 'Salon', kitapSayisi: 1), Raf(id: 2, ad: 'Yatak odası', kitapSayisi: 1)];

Future<void> ara(WidgetTester tester, String metin) async {
  await tester.enterText(find.byKey(const Key('arama_alani')), metin);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

Future<void> sec(WidgetTester tester, String cip, String secenek) async {
  await tester.tap(find.byKey(Key(cip)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(secenek)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('arama kutusu isteği sunucuya gönderir ve listeyi süzer', (tester) async {
    final ortam = await rafAc(tester, raflar: _raflar, kitaplar: _kitaplar);
    await ara(tester, 'atay');
    expect(ortam.kitaplar.sonFiltre?.arama, 'atay');
    expect(find.byKey(const Key('kitap_1')), findsOneWidget);
    expect(find.byKey(const Key('kitap_2')), findsNothing);
    expect(find.byKey(const Key('kitap_3')), findsNothing);
  });

  testWidgets('durum filtresi yalnız o durumdaki kitapları gösterir', (tester) async {
    final ortam = await rafAc(tester, raflar: _raflar, kitaplar: _kitaplar);
    await sec(tester, 'filtre_durum', 'filtre_durum_okundu');
    expect(ortam.kitaplar.sonFiltre?.durum, KitapDurumu.okundu);
    expect(find.byKey(const Key('kitap_2')), findsNothing);
    expect(find.byKey(const Key('kitap_1')), findsOneWidget);
    expect(find.byKey(const Key('kitap_3')), findsOneWidget);
    expect(find.text('Durum: Okundu'), findsOneWidget);
  });

  testWidgets('raf filtresi ve temizle düğmesi', (tester) async {
    await rafAc(tester, raflar: _raflar, kitaplar: _kitaplar);
    expect(find.byKey(const Key('filtre_temizle')), findsNothing);
    await sec(tester, 'filtre_raf', 'filtre_raf_2');
    expect(find.byKey(const Key('kitap_2')), findsOneWidget);
    expect(find.byKey(const Key('kitap_1')), findsNothing);
    expect(find.text('Raf: Yatak odası'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filtre_temizle')));
    await tester.pumpAndSettle();
    for (final id in [1, 2, 3]) {
      expect(find.byKey(Key('kitap_$id')), findsOneWidget);
    }
  });

  testWidgets('temizle arama kutusunu da boşaltır', (tester) async {
    await rafAc(tester, raflar: _raflar, kitaplar: _kitaplar);
    await ara(tester, 'atay');
    await tester.tap(find.byKey(const Key('filtre_temizle')));
    await tester.pumpAndSettle();
    final alan = tester.widget<TextField>(find.byKey(const Key('arama_alani')));
    expect(alan.controller!.text, isEmpty);
    expect(find.byKey(const Key('kitap_3')), findsOneWidget);
  });

  testWidgets('filtreye uyan kitap yoksa ayrı mesaj gösterilir', (tester) async {
    await rafAc(tester, raflar: _raflar, kitaplar: _kitaplar);
    await ara(tester, 'olmayan kitap');
    expect(find.byKey(const Key('kitap_liste_filtre_bos')), findsOneWidget);
    expect(find.byKey(const Key('kitap_liste_bos')), findsNothing);
  });

  testWidgets('Raflarım ekranında rafa dokununca ana sayfa o rafla filtrelenir', (tester) async {
    await rafAc(tester, raflar: _raflar, kitaplar: _kitaplar);
    await raflarAc(tester);
    await tester.tap(find.text('Salon'));
    await tester.pumpAndSettle();
    expect(find.text('Raf: Salon'), findsOneWidget);
    expect(find.byKey(const Key('kitap_1')), findsOneWidget);
    expect(find.byKey(const Key('kitap_2')), findsNothing);
  });

  testWidgets('filtrelenen raf silinince filtre temizlenir', (tester) async {
    await rafAc(tester, raflar: _raflar, kitaplar: _kitaplar);
    await sec(tester, 'filtre_raf', 'filtre_raf_1');
    await raflarAc(tester);
    await tester.tap(find.byKey(const Key('raf_sil_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('raf_silme_onay')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('Raf: '), findsNothing);
    expect(find.byKey(const Key('kitap_2')), findsOneWidget);
    expect(find.byKey(const Key('kitap_liste_filtre_bos')), findsNothing);
  });
}
