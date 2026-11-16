import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/dogrulama.dart';
import 'kategori.dart';
import 'kategoriler_controller.dart';

Future<void> _formAc(BuildContext context, {Kategori? mevcut}) {
  return showDialog<void>(context: context, builder: (_) => _KategoriFormu(mevcut: mevcut));
}

Future<void> _sil(BuildContext context, WidgetRef ref, Kategori kategori) async {
  final bilgi = kategori.kitapSayisi == 0
      ? 'Bu kategoride kitap yok.'
      : 'Bu kategorideki ${kategori.kitapSayisi} kitap silinmez, kategorisiz kalır.';
  final onay = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Kategori silinsin mi?'),
      content: Text('"${kategori.ad}" silinecek. $bilgi'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(
          key: const Key('kategori_silme_onay'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (onay != true || !context.mounted) return;
  final mesaj = ScaffoldMessenger.of(context);
  try {
    await ref.read(kategorilerProvider.notifier).sil(kategori.id);
    mesaj.showSnackBar(const SnackBar(content: Text('Kategori silindi')));
  } on ApiHata catch (e) {
    mesaj.showSnackBar(SnackBar(content: Text(e.mesaj)));
  }
}

/// Yalnızca yöneticiye açık kategori yönetimi: listele, ekle, düzenle, sil.
class KategoriYonetimScreen extends ConsumerWidget {
  const KategoriYonetimScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategoriler = ref.watch(kategorilerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori yönetimi', key: Key('kategori_yonetim_baslik'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('kategori_ekle_buton'),
        onPressed: () => _formAc(context),
        icon: const Icon(Icons.add),
        label: const Text('Kategori ekle'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: () => ref.read(kategorilerProvider.notifier).yenile(),
            child: kategoriler.when(
              loading: () => ListView(
                children: const [Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))],
              ),
              error: (e, _) => ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('$e', key: const Key('kategori_liste_hata'), textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => ref.read(kategorilerProvider.notifier).yenile(),
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
                          'Henüz kategori yok. "Kategori ekle" ile ilkini oluştur.',
                          key: Key('kategori_liste_bos'),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [for (final k in liste) _KategoriKarti(kategori: k)],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KategoriKarti extends ConsumerWidget {
  const _KategoriKarti({required this.kategori});

  final Kategori kategori;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final altSatir = [
      if (kategori.aciklama != null) kategori.aciklama!,
      '${kategori.kitapSayisi} kitap',
    ].join(' · ');
    return Card(
      key: Key('kategori_${kategori.id}'),
      child: ListTile(
        title: Text(kategori.ad),
        subtitle: Text(altSatir),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('kategori_duzenle_${kategori.id}'),
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _formAc(context, mevcut: kategori),
            ),
            IconButton(
              key: Key('kategori_sil_${kategori.id}'),
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _sil(context, ref, kategori),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kategori ekleme ([mevcut] null) ve düzenleme penceresi.
class _KategoriFormu extends ConsumerStatefulWidget {
  const _KategoriFormu({this.mevcut});

  final Kategori? mevcut;

  @override
  ConsumerState<_KategoriFormu> createState() => _KategoriFormuState();
}

class _KategoriFormuState extends ConsumerState<_KategoriFormu> {
  final _form = GlobalKey<FormState>();
  late final _ad = TextEditingController(text: widget.mevcut?.ad);
  late final _aciklama = TextEditingController(text: widget.mevcut?.aciklama);
  bool _bekliyor = false;
  String? _hata;

  bool get _duzenleme => widget.mevcut != null;

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    final aciklama = _aciklama.text.trim();
    final girdi = KategoriGirdisi(ad: _ad.text.trim(), aciklama: aciklama.isEmpty ? null : aciklama);
    try {
      final denetleyici = ref.read(kategorilerProvider.notifier);
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
      title: Text(_duzenleme ? 'Kategoriyi düzenle' : 'Kategori ekle'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('kategori_ad'),
                controller: _ad,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Ad *', border: OutlineInputBorder()),
                validator: KategoriDogrulama.ad,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('kategori_aciklama'),
                controller: _aciklama,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Açıklama', border: OutlineInputBorder()),
                validator: KategoriDogrulama.aciklama,
              ),
              if (_hata != null) ...[
                const SizedBox(height: 8),
                Text(_hata!, key: const Key('kategori_hata'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _bekliyor ? null : () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(key: const Key('kategori_kaydet'), onPressed: _bekliyor ? null : _kaydet, child: const Text('Kaydet')),
      ],
    );
  }
}
