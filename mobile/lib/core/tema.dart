import 'package:flutter/material.dart';

/// Uygulamanın ana rengi: koyu yeşil (eski kitap cildi). Açık ve koyu tema bu renkten türetilir.
const anaRenk = Color(0xFF2E6B57);

ThemeData temaOlustur(Brightness parlaklik) {
  final renkler = ColorScheme.fromSeed(seedColor: anaRenk, brightness: parlaklik);
  final yuvarlak = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  // Başlık yazı tipi temanın kendi yazı stilinden türetilir (font ailesi korunur).
  final yazilar = ThemeData(useMaterial3: true, colorScheme: renkler).textTheme;
  return ThemeData(
    useMaterial3: true,
    colorScheme: renkler,
    scaffoldBackgroundColor: renkler.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: renkler.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: yazilar.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: renkler.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: renkler.surfaceContainerLow,
      shape: yuvarlak,
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: renkler.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    navigationBarTheme: NavigationBarThemeData(indicatorColor: renkler.secondaryContainer),
  );
}
