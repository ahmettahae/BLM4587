import 'package:flutter/material.dart';

import 'kitap.dart';

/// Open Library'nin ücretsiz kapak servisi. `default=false`: kapak yoksa 404 döner, biz de harfli kapak çizeriz.
String? kapakAdresi(String? isbn, {String boyut = 'M'}) =>
    isbn == null ? null : 'https://covers.openlibrary.org/b/isbn/$isbn-$boyut.jpg?default=false';

/// Kitap kapağı: ISBN'den gerçek kapak; yoksa, yüklenemezse ya da internet yoksa
/// başlığa göre renklendirilmiş, baş harfli kapak. [heroEtkin] ise listeden detaya kayarak geçer.
class KitapKapagi extends StatelessWidget {
  const KitapKapagi({super.key, required this.kitap, this.genislik = 48, this.heroEtkin = true});

  final Kitap kitap;
  final double genislik;
  final bool heroEtkin;

  static String heroEtiketi(int id) => 'kapak_$id';

  @override
  Widget build(BuildContext context) {
    final yukseklik = genislik * 1.5;
    final adres = kapakAdresi(kitap.isbn, boyut: genislik > 80 ? 'L' : 'M');
    final yedek = _HarfliKapak(baslik: kitap.baslik, genislik: genislik, yukseklik: yukseklik);
    final kapak = ClipRRect(
      borderRadius: BorderRadius.circular(genislik / 10),
      child: SizedBox(
        width: genislik,
        height: yukseklik,
        child: adres == null
            ? yedek
            : Image.network(
                adres,
                fit: BoxFit.cover,
                semanticLabel: '${kitap.baslik} kapağı',
                loadingBuilder: (context, cocuk, ilerleme) => ilerleme == null ? cocuk : yedek,
                errorBuilder: (_, _, _) => yedek,
              ),
      ),
    );
    return heroEtkin ? Hero(tag: heroEtiketi(kitap.id), child: kapak) : kapak;
  }
}

class _HarfliKapak extends StatelessWidget {
  const _HarfliKapak({required this.baslik, required this.genislik, required this.yukseklik});

  final String baslik;
  final double genislik;
  final double yukseklik;

  static const _renkler = [
    Color(0xFF2E6B57),
    Color(0xFF8A4F3D),
    Color(0xFF3E5C8A),
    Color(0xFF7A5C99),
    Color(0xFFB0782A),
    Color(0xFF4F7A3A),
    Color(0xFF9C3D54),
    Color(0xFF2F7A85),
  ];

  /// Aynı başlık her zaman aynı rengi alır.
  Color get _renk => _renkler[baslik.codeUnits.fold<int>(0, (t, c) => (t * 31 + c) & 0x7fffffff) % _renkler.length];

  String get _harfler {
    final kelimeler = baslik.trim().split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    if (kelimeler.isEmpty) return '?';
    final ilk = kelimeler.first.characters.first;
    final ikinci = kelimeler.length > 1 ? kelimeler[1].characters.first : '';
    return (ilk + ikinci).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: genislik,
      height: yukseklik,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_renk, Color.lerp(_renk, Colors.black, 0.35)!],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _harfler,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: genislik * 0.36),
      ),
    );
  }
}
