import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/gorunum.dart';
import '../categories/kategori.dart';
import '../categories/kategoriler_controller.dart';
import '../shelves/raf.dart';
import '../shelves/raflar_controller.dart';
import 'kitap.dart';
import 'kitap_kapagi.dart';
import 'kitaplar_controller.dart';
import 'puan_secici.dart';
import 'secili_kitap.dart';

/// Silme onayı, silme ve "Geri al"lı bildirim. Başarılıysa true döner.
Future<bool> kitapSil(BuildContext context, WidgetRef ref, Kitap kitap) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: const Text('Kitap silinsin mi?'),
      content: Text('"${kitap.baslik}" kitaplığından kaldırılacak.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(key: const Key('silme_onay'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
      ],
    ),
  );
  if (onay != true || !context.mounted) return false;
  final mesaj = ScaffoldMessenger.of(context);
  // Ekran kapansa da "Geri al" çalışsın diye denetleyici şimdiden alınır.
  final denetleyici = ref.read(kitaplarProvider.notifier);
  try {
    await denetleyici.sil(kitap.id);
  } on ApiHata catch (e) {
    mesaj.showSnackBar(SnackBar(content: Text(e.mesaj)));
    return false;
  }
  mesaj
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text('"${kitap.baslik}" silindi'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          key: const Key('silmeyi_geri_al'),
          label: 'Geri al',
          onPressed: () async {
            try {
              await denetleyici.geriAl(kitap);
              mesaj.showSnackBar(const SnackBar(content: Text('Kitap geri getirildi')));
            } on ApiHata catch (e) {
              mesaj.showSnackBar(SnackBar(content: Text(e.mesaj)));
            }
          },
        ),
      ),
    );
  return true;
}

/// Telefonda tam ekran kitap ayrıntısı.
class KitapDetayScreen extends ConsumerWidget {
  const KitapDetayScreen({super.key, required this.kitapId});

  final int kitapId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitap = ref.watch(kitapProvider(kitapId)).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitap'),
        actions: [
          if (kitap != null) ...[
            IconButton(
              key: const Key('kitap_duzenle'),
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/kitap/${kitap.id}/duzenle'),
            ),
            IconButton(
              key: const Key('kitap_sil'),
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await kitapSil(context, ref, kitap) && context.mounted) context.pop();
              },
            ),
          ],
        ],
      ),
      body: KitapDetayGovdesi(kitapId: kitapId),
    );
  }
}

/// Tablette listenin yanında duran ayrıntı paneli (başlık çubuğu kendi içinde).
class KitapDetayPaneli extends ConsumerWidget {
  const KitapDetayPaneli({super.key, required this.kitapId});

  final int kitapId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitap = ref.watch(kitapProvider(kitapId)).value;
    return Column(
      key: const Key('detay_paneli'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text('Ayrıntı', style: Theme.of(context).textTheme.titleMedium)),
              if (kitap != null) ...[
                IconButton(
                  key: const Key('kitap_duzenle'),
                  tooltip: 'Düzenle',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/kitap/${kitap.id}/duzenle'),
                ),
                IconButton(
                  key: const Key('kitap_sil'),
                  tooltip: 'Sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await kitapSil(context, ref, kitap)) ref.read(seciliKitapProvider.notifier).sec(null);
                  },
                ),
              ],
              IconButton(
                tooltip: 'Kapat',
                icon: const Icon(Icons.close),
                onPressed: () => ref.read(seciliKitapProvider.notifier).sec(null),
              ),
            ],
          ),
        ),
        Expanded(child: KitapDetayGovdesi(kitapId: kitapId, heroEtkin: false)),
      ],
    );
  }
}

class KitapDetayGovdesi extends ConsumerWidget {
  const KitapDetayGovdesi({super.key, required this.kitapId, this.heroEtkin = true});

  final int kitapId;
  final bool heroEtkin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(kitapProvider(kitapId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => HataDurumu(
            baslik: 'Kitap açılamadı',
            hata: e,
            tekrarDene: () => ref.invalidate(kitapProvider(kitapId)),
          ),
          data: (k) => _Ayrinti(
            kitap: k,
            heroEtkin: heroEtkin,
            kategori: kategoriAdi(ref.watch(kategorilerProvider).value, k.kategoriId),
            raf: rafAdi(ref.watch(raflarProvider).value, k.rafId),
          ),
        );
  }
}

class _Ayrinti extends StatelessWidget {
  const _Ayrinti({required this.kitap, required this.heroEtkin, this.kategori, this.raf});

  final Kitap kitap;
  final bool heroEtkin;
  final String? kategori;
  final String? raf;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final satirlar = <(IconData, String, String?)>[
      (Icons.qr_code_2, 'ISBN', kitap.isbn),
      (Icons.business_outlined, 'Yayınevi', kitap.yayinevi),
      (Icons.event_outlined, 'Basım yılı', kitap.yil?.toString()),
      (Icons.menu_book_outlined, 'Sayfa', kitap.sayfa?.toString()),
    ];
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KitapKapagi(kitap: kitap, genislik: 110, heroEtkin: heroEtkin),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kitap.baslik, style: tema.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(kitap.yazar, style: tema.textTheme.titleMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      if (kitap.puan != null) PuanSecici(puan: kitap.puan, boyut: 20),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(avatar: Icon(durumIkonu(kitap.durum), size: 18), label: Text(kitap.durum.etiket)),
                if (kategori != null)
                  Chip(
                    key: const Key('kitap_kategori_etiketi'),
                    avatar: const Icon(Icons.label_outline, size: 18),
                    label: Text(kategori!),
                  ),
                if (raf != null)
                  Chip(
                    key: const Key('kitap_raf_etiketi'),
                    avatar: const Icon(Icons.shelves, size: 18),
                    label: Text(raf!),
                  ),
              ],
            ),
            const Divider(height: 32),
            for (final (ikon, etiket, deger) in satirlar)
              if (deger != null)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(ikon),
                  title: Text(etiket),
                  trailing: Text(deger, style: tema.textTheme.bodyLarge),
                ),
            if (kitap.not != null) ...[
              const SizedBox(height: 8),
              Text('Not', style: tema.textTheme.titleSmall),
              const SizedBox(height: 4),
              Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(kitap.not!))),
            ],
          ],
        ),
      ),
    );
  }
}

IconData durumIkonu(KitapDurumu durum) => switch (durum) {
      KitapDurumu.okunacak => Icons.bookmark_border,
      KitapDurumu.okunuyor => Icons.auto_stories_outlined,
      KitapDurumu.okundu => Icons.check_circle_outline,
    };
