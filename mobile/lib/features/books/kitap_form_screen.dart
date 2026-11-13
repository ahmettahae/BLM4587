import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/dogrulama.dart';
import 'kitap.dart';
import 'kitaplar_controller.dart';
import 'puan_secici.dart';

/// Kitap ekleme ([kitapId] null) ve düzenleme ekranı.
class KitapFormScreen extends ConsumerWidget {
  const KitapFormScreen({super.key, this.kitapId});

  final int? kitapId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = kitapId;
    if (id == null) return const _KitapForm();
    return ref.watch(kitapProvider(id)).when(
          data: (kitap) => _KitapForm(mevcut: kitap),
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
        );
  }
}

class _KitapForm extends ConsumerStatefulWidget {
  const _KitapForm({this.mevcut});

  final Kitap? mevcut;

  @override
  ConsumerState<_KitapForm> createState() => _KitapFormState();
}

class _KitapFormState extends ConsumerState<_KitapForm> {
  final _form = GlobalKey<FormState>();
  late final _baslik = TextEditingController(text: widget.mevcut?.baslik);
  late final _yazar = TextEditingController(text: widget.mevcut?.yazar);
  late final _isbn = TextEditingController(text: widget.mevcut?.isbn);
  late final _yayinevi = TextEditingController(text: widget.mevcut?.yayinevi);
  late final _yil = TextEditingController(text: widget.mevcut?.yil?.toString());
  late final _sayfa = TextEditingController(text: widget.mevcut?.sayfa?.toString());
  late final _not = TextEditingController(text: widget.mevcut?.not);
  late KitapDurumu _durum = widget.mevcut?.durum ?? KitapDurumu.okunacak;
  late int? _puan = widget.mevcut?.puan;
  bool _bekliyor = false;
  String? _hata;

  bool get _duzenleme => widget.mevcut != null;

  @override
  void dispose() {
    for (final c in [_baslik, _yazar, _isbn, _yayinevi, _yil, _sayfa, _not]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _metin(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _kaydet() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    final girdi = KitapGirdisi(
      baslik: _baslik.text.trim(),
      yazar: _yazar.text.trim(),
      isbn: KitapDogrulama.isbnTemizle(_isbn.text),
      yayinevi: _metin(_yayinevi),
      yil: int.tryParse(_yil.text.trim()),
      sayfa: int.tryParse(_sayfa.text.trim()),
      not: _metin(_not),
      durum: _durum,
      puan: _puan,
      kategoriId: widget.mevcut?.kategoriId,
      rafId: widget.mevcut?.rafId,
    );
    try {
      final denetleyici = ref.read(kitaplarProvider.notifier);
      if (_duzenleme) {
        await denetleyici.guncelle(widget.mevcut!.id, girdi);
      } else {
        await denetleyici.ekle(girdi);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_duzenleme ? 'Kitap güncellendi' : 'Kitap eklendi')));
        context.pop();
      }
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  InputDecoration _alan(String etiket) => InputDecoration(labelText: etiket, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    final rakam = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(title: Text(_duzenleme ? 'Kitabı düzenle' : 'Kitap ekle')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    key: const Key('kitap_baslik'),
                    controller: _baslik,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _alan('Başlık *'),
                    validator: KitapDogrulama.baslik,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('kitap_yazar'),
                    controller: _yazar,
                    textCapitalization: TextCapitalization.words,
                    decoration: _alan('Yazar *'),
                    validator: KitapDogrulama.yazar,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('kitap_isbn'),
                    controller: _isbn,
                    keyboardType: TextInputType.text,
                    decoration: _alan('ISBN'),
                    validator: KitapDogrulama.isbn,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('kitap_yayinevi'),
                    controller: _yayinevi,
                    decoration: _alan('Yayınevi'),
                    validator: KitapDogrulama.yayinevi,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('kitap_yil'),
                          controller: _yil,
                          keyboardType: TextInputType.number,
                          inputFormatters: rakam,
                          decoration: _alan('Basım yılı'),
                          validator: KitapDogrulama.yil,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const Key('kitap_sayfa'),
                          controller: _sayfa,
                          keyboardType: TextInputType.number,
                          inputFormatters: rakam,
                          decoration: _alan('Sayfa'),
                          validator: KitapDogrulama.sayfa,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Okuma durumu', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<KitapDurumu>(
                    key: const Key('kitap_durum'),
                    segments: [
                      for (final d in KitapDurumu.values) ButtonSegment(value: d, label: Text(d.etiket)),
                    ],
                    selected: {_durum},
                    onSelectionChanged: (s) => setState(() => _durum = s.first),
                  ),
                  const SizedBox(height: 16),
                  Text('Puan', style: Theme.of(context).textTheme.titleSmall),
                  PuanSecici(puan: _puan, onDegisti: (p) => setState(() => _puan = p)),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('kitap_not'),
                    controller: _not,
                    minLines: 2,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: _alan('Not'),
                    validator: KitapDogrulama.not,
                  ),
                  if (_hata != null) ...[
                    const SizedBox(height: 4),
                    Text(_hata!, key: const Key('kitap_hata'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('kitap_kaydet'),
                    onPressed: _bekliyor ? null : _kaydet,
                    icon: _bekliyor
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Kaydet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
