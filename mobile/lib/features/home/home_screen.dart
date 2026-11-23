import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../books/kitap.dart';
import '../books/kitap_filtresi.dart';
import '../books/kitaplar_controller.dart';
import '../categories/kategori.dart';
import '../categories/kategoriler_controller.dart';
import 'arama_filtre.dart';

/// Giriş sonrası ana sayfa: selam, yönetici bölümü (yalnız yönetici) ve kitap listesi.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kullanici = ref.watch(authControllerProvider).kullanici;
    final kitaplar = ref.watch(kitaplarProvider);
    final kategoriler = ref.watch(kategorilerProvider).value;
    final filtreBos = ref.watch(kitapFiltresiProvider.select((f) => f.bosMu));
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitaplığım'),
        actions: [
          IconButton(
            key: const Key('cikis_buton'),
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).cikisYap(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('kitap_ekle_buton'),
        onPressed: () => context.push('/kitap/yeni'),
        icon: const Icon(Icons.add),
        label: const Text('Kitap ekle'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: () => ref.read(kitaplarProvider.notifier).yenile(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text('Merhaba ${kullanici?.ad ?? ''}', style: tema.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(kullanici?.email ?? '', style: tema.textTheme.bodyMedium),
                const SizedBox(height: 12),
                if (kullanici?.yoneticiMi ?? false)
                  Card(
                    key: const Key('yonetici_karti'),
                    child: ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('Yönetim'),
                      subtitle: const Text('Kategorileri yönet'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/yonetim/kategoriler'),
                    ),
                  ),
                Card(
                  key: const Key('raflar_karti'),
                  child: ListTile(
                    leading: const Icon(Icons.shelves),
                    title: const Text('Raflarım'),
                    subtitle: const Text('Rafları ekle, adlandır, sil'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/raflar'),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Kitaplarım', style: tema.textTheme.titleMedium),
                const SizedBox(height: 8),
                const AramaVeFiltre(),
                const SizedBox(height: 8),
                ...kitaplar.when(
                  loading: () => const [
                    Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                  ],
                  error: (e, _) => [
                    _BosDurum(
                      key: const Key('kitap_liste_hata'),
                      ikon: Icons.cloud_off_outlined,
                      mesaj: '$e',
                      eylem: TextButton(
                        onPressed: () => ref.read(kitaplarProvider.notifier).yenile(),
                        child: const Text('Tekrar dene'),
                      ),
                    ),
                  ],
                  data: (liste) => liste.isEmpty
                      ? [
                          filtreBos
                              ? const _BosDurum(
                                  key: Key('kitap_liste_bos'),
                                  ikon: Icons.menu_book_outlined,
                                  mesaj: 'Henüz kitap yok. "Kitap ekle" ile ilk kitabını ekle.',
                                )
                              : const _BosDurum(
                                  key: Key('kitap_liste_filtre_bos'),
                                  ikon: Icons.search_off,
                                  mesaj: 'Bu filtreye uyan kitap yok.',
                                ),
                        ]
                      : [for (final k in liste) _KitapKarti(kitap: k, kategori: kategoriAdi(kategoriler, k.kategoriId))],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KitapKarti extends StatelessWidget {
  const _KitapKarti({required this.kitap, this.kategori});

  final Kitap kitap;
  final String? kategori;

  IconData get _ikon => switch (kitap.durum) {
        KitapDurumu.okunacak => Icons.bookmark_border,
        KitapDurumu.okunuyor => Icons.auto_stories_outlined,
        KitapDurumu.okundu => Icons.check_circle_outline,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('kitap_${kitap.id}'),
      child: ListTile(
        leading: Icon(_ikon),
        title: Text(kitap.baslik, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          kategori == null ? kitap.yazar : '${kitap.yazar} · $kategori',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(kitap.durum.etiket, style: Theme.of(context).textTheme.labelMedium),
        onTap: () => context.push('/kitap/${kitap.id}'),
      ),
    );
  }
}

class _BosDurum extends StatelessWidget {
  const _BosDurum({super.key, required this.ikon, required this.mesaj, this.eylem});

  final IconData ikon;
  final String mesaj;
  final Widget? eylem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(ikon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(mesaj, textAlign: TextAlign.center),
          ?eylem,
        ],
      ),
    );
  }
}
