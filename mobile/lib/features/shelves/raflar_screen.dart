import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/dogrulama.dart';
import '../books/kitap_filtresi.dart';
import 'raf.dart';
import 'raflar_controller.dart';

Future<void> _formAc(BuildContext context, {Raf? mevcut}) {
  return showDialog<void>(context: context, builder: (_) => _RafFormu(mevcut: mevcut));
}

Future<void> _sil(BuildContext context, WidgetRef ref, Raf raf) async {
  final bilgi = raf.kitapSayisi == 0
      ? 'Bu rafta kitap yok.'
      : 'Bu raftaki ${raf.kitapSayisi} kitap silinmez, rafsız kalır.';
  final onay = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Raf silinsin mi?'),
      content: Text('"${raf.ad}" silinecek. $bilgi'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(
          key: const Key('raf_silme_onay'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (onay != true || !context.mounted) return;
  final mesaj = ScaffoldMessenger.of(context);
  try {
    await ref.read(raflarProvider.notifier).sil(raf.id);
    mesaj.showSnackBar(const SnackBar(content: Text('Raf silindi')));
  } on ApiHata catch (e) {
    mesaj.showSnackBar(SnackBar(content: Text(e.mesaj)));
  }
}

/// Kullanıcının rafları: listele, ekle, yeniden adlandır, sil.
class RaflarScreen extends ConsumerWidget {
  const RaflarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raflar = ref.watch(raflarProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Raflarım', key: Key('raflar_baslik'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('raf_ekle_buton'),
        onPressed: () => _formAc(context),
        icon: const Icon(Icons.add),
        label: const Text('Raf ekle'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: () => ref.read(raflarProvider.notifier).yenile(),
            child: raflar.when(
              loading: () => ListView(
                children: const [Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))],
              ),
              error: (e, _) => ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('$e', key: const Key('raf_liste_hata'), textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => ref.read(raflarProvider.notifier).yenile(),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
              data: (liste) => liste.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32),
                      children: const [
                        Text(
                          'Henüz raf yok. "Raf ekle" ile ilk rafını oluştur.',
                          key: Key('raf_liste_bos'),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [for (final r in liste) _RafKarti(raf: r)],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RafKarti extends ConsumerWidget {
  const _RafKarti({required this.raf});

  final Raf raf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: Key('raf_${raf.id}'),
      child: ListTile(
        leading: const Icon(Icons.shelves),
        title: Text(raf.ad),
        subtitle: Text('${raf.kitapSayisi} kitap'),
        // Rafa dokununca ana sayfa bu rafın kitaplarıyla açılır.
        onTap: () {
          ref.read(kitapFiltresiProvider.notifier).rafSec(raf.id);
          context.go('/');
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('raf_duzenle_${raf.id}'),
              tooltip: 'Yeniden adlandır',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _formAc(context, mevcut: raf),
            ),
            IconButton(
              key: Key('raf_sil_${raf.id}'),
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _sil(context, ref, raf),
            ),
          ],
        ),
      ),
    );
  }
}

/// Raf ekleme ([mevcut] null) ve yeniden adlandırma penceresi.
class _RafFormu extends ConsumerStatefulWidget {
  const _RafFormu({this.mevcut});

  final Raf? mevcut;

  @override
  ConsumerState<_RafFormu> createState() => _RafFormuState();
}

class _RafFormuState extends ConsumerState<_RafFormu> {
  final _form = GlobalKey<FormState>();
  late final _ad = TextEditingController(text: widget.mevcut?.ad);
  bool _bekliyor = false;
  String? _hata;

  bool get _duzenleme => widget.mevcut != null;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    final girdi = RafGirdisi(ad: _ad.text.trim());
    try {
      final denetleyici = ref.read(raflarProvider.notifier);
      if (_duzenleme) {
        await denetleyici.guncelle(widget.mevcut!.id, girdi);
      } else {
        await denetleyici.ekle(girdi);
      }
      if (mounted) Navigator.pop(context);
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_duzenleme ? 'Rafı yeniden adlandır' : 'Raf ekle'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('raf_ad_alani'),
                controller: _ad,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Ad *', border: OutlineInputBorder()),
                validator: RafDogrulama.ad,
                onFieldSubmitted: (_) => _bekliyor ? null : _kaydet(),
              ),
              if (_hata != null) ...[
                const SizedBox(height: 8),
                Text(_hata!, key: const Key('raf_hata'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _bekliyor ? null : () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(key: const Key('raf_kaydet'), onPressed: _bekliyor ? null : _kaydet, child: const Text('Kaydet')),
      ],
    );
  }
}
