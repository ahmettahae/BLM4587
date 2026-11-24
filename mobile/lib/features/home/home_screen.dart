import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/gorunum.dart';
import '../auth/auth_controller.dart';
import '../books/kitap.dart';
import '../books/kitap_detay_screen.dart';
import '../books/kitap_filtresi.dart';
import '../books/kitap_kapagi.dart';
import '../books/kitaplar_controller.dart';
import '../books/secili_kitap.dart';
import '../categories/kategori.dart';
import '../categories/kategoriler_controller.dart';
import 'arama_filtre.dart';

/// Kitaplar sekmesi. Telefonda tek liste; tablette solda liste, sağda seçili kitabın ayrıntısı.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genis = genisEkranMi(context);
    final secili = ref.watch(seciliKitapProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kitaplığım')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('kitap_ekle_buton'),
        onPressed: () => context.push('/kitap/yeni'),
        icon: const Icon(Icons.add),
        label: const Text('Kitap ekle'),
      ),
      body: genis
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: 440, child: _KitapListesi(genis: true)),
                const VerticalDivider(width: 1),
                Expanded(
                  child: secili == null
                      ? const Center(
                          child: BosDurum(
                            key: Key('detay_bos'),
                            ikon: Icons.auto_stories_outlined,
                            mesaj: 'Ayrıntısını görmek için soldan bir kitap seç.',
                          ),
                        )
                      : KitapDetayPaneli(key: ValueKey(secili), kitapId: secili),
                ),
              ],
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: const _KitapListesi(genis: false),
              ),
            ),
    );
  }
}

class _KitapListesi extends ConsumerWidget {
  const _KitapListesi({required this.genis});

  final bool genis;

  /// Listenin sonuna 400 pikselden az kalınca sonraki sayfayı iste.
  bool _kaydirildi(ScrollNotification bildirim, WidgetRef ref) {
    final liste = ref.read(kitaplarProvider).value;
    if (bildirim.metrics.extentAfter < 400 && (liste?.otomatikYuklenebilir ?? false)) {
      ref.read(kitaplarProvider.notifier).dahaFazlaYukle();
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kullanici = ref.watch(authControllerProvider).kullanici;
    final kitaplar = ref.watch(kitaplarProvider);
    final kategoriler = ref.watch(kategorilerProvider).value;
    final filtreBos = ref.watch(kitapFiltresiProvider.select((f) => f.bosMu));
    final secili = genis ? ref.watch(seciliKitapProvider) : null;
    final tema = Theme.of(context);
    final toplam = kitaplar.value?.toplam;
    return NotificationListener<ScrollNotification>(
      onNotification: (b) => _kaydirildi(b, ref),
      child: RefreshIndicator(
        onRefresh: () => ref.read(kitaplarProvider.notifier).yenile(),
        child: ListView(
          key: const Key('kitap_listesi'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Text('Merhaba ${kullanici?.ad ?? ''}', style: tema.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const _OzetKarti(),
            const SizedBox(height: 16),
            Text(
              toplam == null ? 'Kitaplarım' : 'Kitaplarım · $toplam',
              key: const Key('kitaplarim_basligi'),
              style: tema.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const AramaVeFiltre(),
            const SizedBox(height: 8),
            ...kitaplar.when(
              loading: () => const [IskeletListe()],
              error: (e, _) => [
                HataDurumu(
                  key: const Key('kitap_liste_hata'),
                  baslik: 'Kitaplar yüklenemedi',
                  hata: e,
                  tekrarDene: () => ref.read(kitaplarProvider.notifier).yenile(),
                ),
              ],
              data: (liste) => liste.kitaplar.isEmpty
                  ? [
                      filtreBos
                          ? const BosDurum(
                              key: Key('kitap_liste_bos'),
                              ikon: Icons.menu_book_outlined,
                              baslik: 'Kitaplığın boş',
                              mesaj: '"Kitap ekle" ile ilk kitabını ekle.',
                            )
                          : const BosDurum(
                              key: Key('kitap_liste_filtre_bos'),
                              ikon: Icons.search_off,
                              mesaj: 'Bu filtreye uyan kitap yok.',
                            ),
                    ]
                  : [
                      for (final k in liste.kitaplar)
                        _KitapKarti(
                          kitap: k,
                          kategori: kategoriAdi(kategoriler, k.kategoriId),
                          secili: k.id == secili,
                          onTap: genis
                              ? () => ref.read(seciliKitapProvider.notifier).sec(k.id)
                              : () => context.push('/kitap/${k.id}'),
                        ),
                      if (liste.dahaYukleniyor)
                        const Padding(
                          key: Key('daha_yukleniyor'),
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (liste.dahaHatasi)
                        Padding(
                          key: const Key('daha_hata'),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Text('Devamı yüklenemedi.'),
                              TextButton.icon(
                                key: const Key('daha_tekrar_dene'),
                                onPressed: () => ref.read(kitaplarProvider.notifier).dahaFazlaYukle(tekrar: true),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Toplam, okunan ve okunmakta olan kitap sayıları; okunan oranı çubukla.
class _OzetKarti extends ConsumerWidget {
  const _OzetKarti();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ozet = ref.watch(kitapOzetiProvider).value;
    if (ozet == null || ozet.toplam == 0) return const SizedBox.shrink();
    final tema = Theme.of(context);
    Widget sayi(String anahtar, int deger, String etiket, IconData ikon) => Expanded(
          child: Column(
            children: [
              Icon(ikon, color: tema.colorScheme.primary),
              const SizedBox(height: 4),
              Text('$deger', key: Key(anahtar), style: tema.textTheme.headlineSmall),
              Text(etiket, style: tema.textTheme.bodySmall),
            ],
          ),
        );
    return Card(
      key: const Key('ozet_karti'),
      color: tema.colorScheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                sayi('ozet_toplam', ozet.toplam, 'Kitap', Icons.library_books_outlined),
                sayi('ozet_okunuyor', ozet.okunuyor, 'Okunuyor', Icons.auto_stories_outlined),
                sayi('ozet_okundu', ozet.okundu, 'Okundu', Icons.check_circle_outline),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: ozet.okundu / ozet.toplam, minHeight: 6),
            ),
            const SizedBox(height: 4),
            Text(
              'Kitaplığının %${(ozet.okundu * 100 / ozet.toplam).round()}\'ini okudun',
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _KitapKarti extends StatelessWidget {
  const _KitapKarti({required this.kitap, required this.onTap, this.kategori, this.secili = false});

  final Kitap kitap;
  final String? kategori;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      key: Key('kitap_${kitap.id}'),
      color: secili ? tema.colorScheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              KitapKapagi(kitap: kitap, genislik: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kitap.baslik, maxLines: 2, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      kategori == null ? kitap.yazar : '${kitap.yazar} · $kategori',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(durumIkonu(kitap.durum), size: 20, color: tema.colorScheme.primary),
                  const SizedBox(height: 2),
                  Text(kitap.durum.etiket, style: tema.textTheme.labelMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
