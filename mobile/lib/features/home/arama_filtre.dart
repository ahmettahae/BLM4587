import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../books/kitap.dart';
import '../books/kitap_filtresi.dart';
import '../categories/kategori.dart';
import '../categories/kategoriler_controller.dart';
import '../shelves/raf.dart';
import '../shelves/raflar_controller.dart';

/// Ana sayfadaki arama kutusu ve Durum / Kategori / Raf filtreleri.
class AramaVeFiltre extends ConsumerStatefulWidget {
  const AramaVeFiltre({super.key});

  @override
  ConsumerState<AramaVeFiltre> createState() => _AramaVeFiltreState();
}

class _AramaVeFiltreState extends ConsumerState<AramaVeFiltre> {
  late final _arama = TextEditingController(text: ref.read(kitapFiltresiProvider).arama);
  Timer? _gecikme;

  @override
  void dispose() {
    _gecikme?.cancel();
    _arama.dispose();
    super.dispose();
  }

  /// Her tuşta istek atmamak için yazma bittikten kısa süre sonra arar.
  void _yazildi(String metin) {
    _gecikme?.cancel();
    _gecikme = Timer(const Duration(milliseconds: 300), () {
      ref.read(kitapFiltresiProvider.notifier).aramaYap(metin);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filtre başka yerden temizlenirse (Temizle, çıkış) kutu da boşalsın.
    ref.listen(kitapFiltresiProvider.select((f) => f.arama), (_, yeni) {
      if (yeni != _arama.text) _arama.text = yeni;
    });
    final filtre = ref.watch(kitapFiltresiProvider);
    final denetleyici = ref.read(kitapFiltresiProvider.notifier);
    final kategoriler = ref.watch(kategorilerProvider).value ?? const <Kategori>[];
    final raflar = ref.watch(raflarProvider).value ?? const <Raf>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('arama_alani'),
          controller: _arama,
          onChanged: _yazildi,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Başlık, yazar ya da ISBN ara',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _FiltreCipi<KitapDurumu>(
              anahtar: 'filtre_durum',
              baslik: 'Durum',
              secili: filtre.durum?.etiket,
              secenekler: [for (final d in KitapDurumu.values) (d, d.etiket, 'filtre_durum_${d.name}')],
              secildi: denetleyici.durumSec,
            ),
            _FiltreCipi<int>(
              anahtar: 'filtre_kategori',
              baslik: 'Kategori',
              secili: kategoriAdi(kategoriler, filtre.kategoriId),
              secenekler: [for (final k in kategoriler) (k.id, k.ad, 'filtre_kategori_${k.id}')],
              secildi: denetleyici.kategoriSec,
            ),
            _FiltreCipi<int>(
              anahtar: 'filtre_raf',
              baslik: 'Raf',
              secili: rafAdi(raflar, filtre.rafId),
              secenekler: [for (final r in raflar) (r.id, r.ad, 'filtre_raf_${r.id}')],
              secildi: denetleyici.rafSec,
            ),
            PopupMenuButton<KitapSiralama>(
              key: const Key('siralama'),
              tooltip: 'Sıralama',
              initialValue: filtre.siralama,
              onSelected: denetleyici.siralamaSec,
              itemBuilder: (_) => [
                for (final s in KitapSiralama.values)
                  PopupMenuItem(key: Key('siralama_${s.name}'), value: s, child: Text(s.etiket)),
              ],
              child: Chip(
                avatar: const Icon(Icons.sort, size: 18),
                label: Text(filtre.siralama.etiket),
              ),
            ),
            if (!filtre.bosMu)
              ActionChip(
                key: const Key('filtre_temizle'),
                avatar: const Icon(Icons.clear, size: 18),
                label: const Text('Temizle'),
                onPressed: () {
                  _gecikme?.cancel();
                  denetleyici.temizle();
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Dokununca seçenek menüsü açan filtre çipi. "Tümü" seçilince filtre kalkar (null).
class _FiltreCipi<T extends Object> extends StatelessWidget {
  const _FiltreCipi({
    required this.anahtar,
    required this.baslik,
    required this.secili,
    required this.secenekler,
    required this.secildi,
  });

  final String anahtar;
  final String baslik;
  final String? secili;
  final List<(T, String, String)> secenekler;
  final void Function(T?) secildi;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return PopupMenuButton<T?>(
      key: Key(anahtar),
      tooltip: '$baslik filtresi',
      onSelected: secildi,
      itemBuilder: (_) => [
        PopupMenuItem<T?>(key: Key('${anahtar}_tumu'), value: null, child: const Text('Tümü')),
        for (final (deger, ad, k) in secenekler) PopupMenuItem<T?>(key: Key(k), value: deger, child: Text(ad)),
      ],
      child: Chip(
        avatar: Icon(Icons.filter_list, size: 18, color: secili == null ? null : renk.primary),
        label: Text(secili == null ? baslik : '$baslik: $secili'),
        backgroundColor: secili == null ? null : renk.secondaryContainer,
      ),
    );
  }
}
