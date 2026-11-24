import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tema.dart';
import '../core/tercihler.dart';
import 'router.dart';

/// Uygulama Türkçe: tarih seçici, kopyala/yapıştır menüsü gibi sistem metinleri de Türkçe gelir.
const uygulamaDili = Locale('tr', 'TR');

class KitapligimApp extends ConsumerWidget {
  const KitapligimApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Kitaplığım',
      debugShowCheckedModeBanner: false,
      theme: temaOlustur(Brightness.light),
      darkTheme: temaOlustur(Brightness.dark),
      themeMode: ref.watch(temaProvider),
      locale: uygulamaDili,
      supportedLocales: const [uygulamaDili],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
