import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Küçük kullanıcı tercihleri (tema, sıralama). Testlerde bellekteki sürüm kullanılır.
abstract class TercihDeposu {
  Future<String?> oku(String anahtar);
  Future<void> yaz(String anahtar, String deger);
}

class GuvenliTercihDeposu implements TercihDeposu {
  final _depo = const FlutterSecureStorage();

  @override
  Future<String?> oku(String anahtar) => _depo.read(key: 'tercih_$anahtar');

  @override
  Future<void> yaz(String anahtar, String deger) => _depo.write(key: 'tercih_$anahtar', value: deger);
}

class BellekTercihDeposu implements TercihDeposu {
  final Map<String, String> degerler = {};

  @override
  Future<String?> oku(String anahtar) async => degerler[anahtar];

  @override
  Future<void> yaz(String anahtar, String deger) async => degerler[anahtar] = deger;
}

final tercihDeposuProvider = Provider<TercihDeposu>((ref) => GuvenliTercihDeposu());

/// Açık / koyu / sistem teması. Seçim cihazda saklanır.
class TemaController extends Notifier<ThemeMode> {
  static const anahtar = 'tema';

  @override
  ThemeMode build() {
    Future.microtask(_yukle);
    return ThemeMode.system;
  }

  Future<void> _yukle() async {
    try {
      final kayitli = await ref.read(tercihDeposuProvider).oku(anahtar);
      final secim = ThemeMode.values.where((m) => m.name == kayitli).firstOrNull;
      if (secim != null) state = secim;
    } catch (_) {
      // Depo okunamazsa sistem teması kalır.
    }
  }

  Future<void> sec(ThemeMode mod) async {
    state = mod;
    try {
      await ref.read(tercihDeposuProvider).yaz(anahtar, mod.name);
    } catch (_) {
      // Kaydedilemese de bu oturumda geçerli.
    }
  }
}

final temaProvider = NotifierProvider<TemaController, ThemeMode>(TemaController.new);
