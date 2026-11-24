import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitapligim/app/app.dart';
import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/core/tercihler.dart';
import 'package:kitapligim/core/token_store.dart';

Future<ProviderContainer> ac(WidgetTester tester, BellekTercihDeposu tercihler) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(BellekTokenStore()),
        tercihDeposuProvider.overrideWithValue(tercihler),
      ],
      child: const KitapligimApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(KitapligimApp)));
}

void main() {
  testWidgets('sistem metinleri Türkçe (Material yerelleştirmesi)', (tester) async {
    await ac(tester, BellekTercihDeposu());
    final metinler = MaterialLocalizations.of(tester.element(find.byType(Scaffold).first));
    expect(metinler.cancelButtonLabel, 'İptal');
    expect(metinler.pasteButtonLabel, 'Yapıştır');
  });

  testWidgets('varsayılan tema sistemi izler; açık ve koyu tema tanımlı', (tester) async {
    await ac(tester, BellekTercihDeposu());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme!.brightness, Brightness.light);
    expect(app.darkTheme!.brightness, Brightness.dark);
  });

  testWidgets('kayıtlı tema seçimi açılışta uygulanır, yeni seçim kaydedilir', (tester) async {
    final tercihler = BellekTercihDeposu()..degerler['tema'] = 'dark';
    final kap = await ac(tester, tercihler);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    await kap.read(temaProvider.notifier).sec(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.light);
    expect(tercihler.degerler['tema'], 'light');
  });
}
