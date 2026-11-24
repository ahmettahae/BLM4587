import 'package:flutter/material.dart';

import 'api_client.dart';

/// Bu genişlikten itibaren tablet düzeni: yan gezinme ve liste + ayrıntı yan yana.
const genisEkranSiniri = 840.0;

bool genisEkranMi(BuildContext context) => MediaQuery.sizeOf(context).width >= genisEkranSiniri;

/// Hata için kullanıcıya gösterilecek metin: ham istisna yerine anlaşılır cümle.
String hataMetni(Object hata) => hata is ApiHata ? hata.mesaj : 'Beklenmeyen bir sorun oluştu. Tekrar dene.';

/// Boş liste, filtre sonucu yok gibi durumlar için ikonlu, ortalanmış mesaj.
class BosDurum extends StatelessWidget {
  const BosDurum({super.key, required this.ikon, required this.mesaj, this.baslik, this.eylem});

  final IconData ikon;
  final String? baslik;
  final String mesaj;
  final Widget? eylem;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(ikon, size: 56, color: tema.colorScheme.outline),
          const SizedBox(height: 12),
          if (baslik != null) ...[
            Text(baslik!, style: tema.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 4),
          ],
          Text(mesaj, textAlign: TextAlign.center, style: tema.textTheme.bodyMedium),
          if (eylem != null) ...[const SizedBox(height: 12), eylem!],
        ],
      ),
    );
  }
}

/// Yükleme hatası: ne olduğunu söyler, "Tekrar dene" düğmesi verir.
class HataDurumu extends StatelessWidget {
  const HataDurumu({super.key, required this.baslik, required this.hata, required this.tekrarDene});

  final String baslik;
  final Object hata;
  final VoidCallback tekrarDene;

  @override
  Widget build(BuildContext context) {
    final baglantiYok = hata is ApiHata && (hata as ApiHata).durum == null;
    return BosDurum(
      ikon: baglantiYok ? Icons.wifi_off_rounded : Icons.error_outline,
      baslik: baslik,
      mesaj: hataMetni(hata),
      eylem: FilledButton.tonalIcon(
        key: const Key('tekrar_dene'),
        onPressed: tekrarDene,
        icon: const Icon(Icons.refresh),
        label: const Text('Tekrar dene'),
      ),
    );
  }
}

/// Liste yüklenirken içerik biçiminde gri kutular (dönen çark yerine).
class IskeletListe extends StatefulWidget {
  const IskeletListe({super.key, this.adet = 6});

  final int adet;

  @override
  State<IskeletListe> createState() => _IskeletListeState();
}

class _IskeletListeState extends State<IskeletListe> with SingleTickerProviderStateMixin {
  late final _animasyon = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _animasyon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget kutu(double g, double y) => Container(
          width: g,
          height: y,
          decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(6)),
        );
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_animasyon),
      child: Column(
        key: const Key('iskelet_liste'),
        children: [
          for (var i = 0; i < widget.adet; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    kutu(40, 60),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [kutu(double.infinity, 14), const SizedBox(height: 8), kutu(120, 12)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
