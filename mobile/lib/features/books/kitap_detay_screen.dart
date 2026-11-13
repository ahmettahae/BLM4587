import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import 'kitap.dart';
import 'kitaplar_controller.dart';
import 'puan_secici.dart';

class KitapDetayScreen extends ConsumerWidget {
  const KitapDetayScreen({super.key, required this.kitapId});

  final int kitapId;

  Future<void> _sil(BuildContext context, WidgetRef ref, Kitap kitap) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kitap silinsin mi?'),
        content: Text('"${kitap.baslik}" kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(key: const Key('silme_onay'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;
    final mesaj = ScaffoldMessenger.of(context);
    try {
      await ref.read(kitaplarProvider.notifier).sil(kitap.id);
      mesaj.showSnackBar(const SnackBar(content: Text('Kitap silindi')));
      if (context.mounted) context.pop();
    } on ApiHata catch (e) {
      mesaj.showSnackBar(SnackBar(content: Text(e.mesaj)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durum = ref.watch(kitapProvider(kitapId));
    final kitap = durum.value;
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
              onPressed: () => _sil(context, ref, kitap),
            ),
          ],
        ],
      ),
      body: durum.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
        data: (k) => _Ayrinti(kitap: k),
      ),
    );
  }
}

class _Ayrinti extends StatelessWidget {
  const _Ayrinti({required this.kitap});

  final Kitap kitap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final satirlar = <(String, String?)>[
      ('ISBN', kitap.isbn),
      ('Yayınevi', kitap.yayinevi),
      ('Basım yılı', kitap.yil?.toString()),
      ('Sayfa', kitap.sayfa?.toString()),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(kitap.baslik, style: tema.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(kitap.yazar, style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(kitap.durum.etiket)),
                if (kitap.puan != null) PuanSecici(puan: kitap.puan, boyut: 20),
              ],
            ),
            const Divider(height: 32),
            for (final (etiket, deger) in satirlar)
              if (deger != null)
                ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(etiket), trailing: Text(deger)),
            if (kitap.not != null) ...[
              const SizedBox(height: 8),
              Text('Not', style: tema.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(kitap.not!),
            ],
          ],
        ),
      ),
    );
  }
}
