import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'kitap.dart';

/// Liste sıralaması: API'deki değer ve ekranda görünen ad.
enum KitapSiralama {
  yeni('En yeni'),
  eski('En eski'),
  baslik('Başlık (A-Z)'),
  yazar('Yazar (A-Z)'),
  puan('Puan');

  const KitapSiralama(this.etiket);

  final String etiket;
}

/// Ana sayfadaki arama, filtre ve sıralama seçimleri. Boş alanlar sunucuya gönderilmez.
class KitapFiltresi {
  const KitapFiltresi({this.arama = '', this.durum, this.kategoriId, this.rafId, this.siralama = KitapSiralama.yeni});

  final String arama;
  final KitapDurumu? durum;
  final int? kategoriId;
  final int? rafId;
  final KitapSiralama siralama;

  /// Süzme yok mu? (Sıralama süzme değildir; "Temizle" onu değiştirmez.)
  bool get bosMu => arama.trim().isEmpty && durum == null && kategoriId == null && rafId == null;

  /// Yeni eklenen kitap listenin başına doğrudan konabilir mi (süzme yok ve en yeni başta)?
  bool get yeniBastaMi => bosMu && siralama == KitapSiralama.yeni;

  /// Null bir değeri bilerek seçmek için (ör. "Tümü") ilgili `...Temizle` bayrağını ver.
  KitapFiltresi copyWith({
    String? arama,
    KitapDurumu? durum,
    int? kategoriId,
    int? rafId,
    KitapSiralama? siralama,
    bool durumTemizle = false,
    bool kategoriTemizle = false,
    bool rafTemizle = false,
  }) =>
      KitapFiltresi(
        arama: arama ?? this.arama,
        durum: durumTemizle ? null : (durum ?? this.durum),
        kategoriId: kategoriTemizle ? null : (kategoriId ?? this.kategoriId),
        rafId: rafTemizle ? null : (rafId ?? this.rafId),
        siralama: siralama ?? this.siralama,
      );

  /// GET /books sorgu parametreleri.
  Map<String, dynamic> toQuery() => {
        if (arama.trim().isNotEmpty) 'search': arama.trim(),
        if (durum != null) 'status': durum!.name,
        if (kategoriId != null) 'category': kategoriId,
        if (rafId != null) 'shelf': rafId,
        if (siralama != KitapSiralama.yeni) 'sort': siralama.name,
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
  void siralamaSec(KitapSiralama siralama) => state = state.copyWith(siralama: siralama);

  /// Süzmeyi kaldırır, seçili sıralama kalır.
  void temizle() => state = KitapFiltresi(siralama: state.siralama);

  /// Raflar ekranından bir rafa gidilince: yalnız o raf süzülür (önceki arama/filtre kalkar).
  void yalnizRaf(int id) => state = KitapFiltresi(rafId: id, siralama: state.siralama);
}

final kitapFiltresiProvider = NotifierProvider<KitapFiltresiController, KitapFiltresi>(KitapFiltresiController.new);
