import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'kitap.dart';

/// Ana sayfadaki arama ve filtre seçimleri. Boş alanlar sunucuya gönderilmez.
class KitapFiltresi {
  const KitapFiltresi({this.arama = '', this.durum, this.kategoriId, this.rafId});

  final String arama;
  final KitapDurumu? durum;
  final int? kategoriId;
  final int? rafId;

  bool get bosMu => arama.trim().isEmpty && durum == null && kategoriId == null && rafId == null;

  /// Null bir değeri bilerek seçmek için (ör. "Tümü") ilgili `...Temizle` bayrağını ver.
  KitapFiltresi copyWith({
    String? arama,
    KitapDurumu? durum,
    int? kategoriId,
    int? rafId,
    bool durumTemizle = false,
    bool kategoriTemizle = false,
    bool rafTemizle = false,
  }) =>
      KitapFiltresi(
        arama: arama ?? this.arama,
        durum: durumTemizle ? null : (durum ?? this.durum),
        kategoriId: kategoriTemizle ? null : (kategoriId ?? this.kategoriId),
        rafId: rafTemizle ? null : (rafId ?? this.rafId),
      );

  /// GET /books sorgu parametreleri.
  Map<String, dynamic> toQuery() => {
        if (arama.trim().isNotEmpty) 'search': arama.trim(),
        if (durum != null) 'status': durum!.name,
        if (kategoriId != null) 'category': kategoriId,
        if (rafId != null) 'shelf': rafId,
      };
}

class KitapFiltresiController extends Notifier<KitapFiltresi> {
  @override
  KitapFiltresi build() {
    // Kullanıcı değişince (çıkış/giriş) filtre sıfırlanır.
    ref.watch(authControllerProvider.select((s) => s.kullanici?.id));
    return const KitapFiltresi();
  }

  void aramaYap(String metin) => state = state.copyWith(arama: metin);
  void durumSec(KitapDurumu? durum) => state = state.copyWith(durum: durum, durumTemizle: durum == null);
  void kategoriSec(int? id) => state = state.copyWith(kategoriId: id, kategoriTemizle: id == null);
  void rafSec(int? id) => state = state.copyWith(rafId: id, rafTemizle: id == null);
  void temizle() => state = const KitapFiltresi();
}

final kitapFiltresiProvider = NotifierProvider<KitapFiltresiController, KitapFiltresi>(KitapFiltresiController.new);
