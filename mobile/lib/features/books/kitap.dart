/// Okuma durumları: API'deki değer ve ekranda görünen ad.
enum KitapDurumu {
  okunacak('Okunacak'),
  okunuyor('Okunuyor'),
  okundu('Okundu');

  const KitapDurumu(this.etiket);

  final String etiket;

  static KitapDurumu cozumle(String deger) =>
      KitapDurumu.values.firstWhere((d) => d.name == deger, orElse: () => KitapDurumu.okunacak);
}

class Kitap {
  const Kitap({
    required this.id,
    required this.baslik,
    required this.yazar,
    this.isbn,
    this.yayinevi,
    this.yil,
    this.sayfa,
    this.not,
    this.durum = KitapDurumu.okunacak,
    this.puan,
    this.kategoriId,
    this.rafId,
  });

  final int id;
  final String baslik;
  final String yazar;
  final String? isbn;
  final String? yayinevi;
  final int? yil;
  final int? sayfa;
  final String? not;
  final KitapDurumu durum;
  final int? puan;
  final int? kategoriId;
  final int? rafId;

  factory Kitap.fromJson(Map<String, dynamic> json) => Kitap(
        id: json['id'] as int,
        baslik: json['title'] as String,
        yazar: json['author'] as String,
        isbn: json['isbn'] as String?,
        yayinevi: json['publisher'] as String?,
        yil: json['year'] as int?,
        sayfa: json['pages'] as int?,
        not: json['note'] as String?,
        durum: KitapDurumu.cozumle(json['status'] as String),
        puan: json['rating'] as int?,
        kategoriId: json['category_id'] as int?,
        rafId: json['shelf_id'] as int?,
      );
}

/// Ekleme ve düzenleme formunun API'ye gönderdiği veri (id yok). Kategori ve raf formda seçilir.
class KitapGirdisi {
  const KitapGirdisi({
    required this.baslik,
    required this.yazar,
    this.isbn,
    this.yayinevi,
    this.yil,
    this.sayfa,
    this.not,
    this.durum = KitapDurumu.okunacak,
    this.puan,
    this.kategoriId,
    this.rafId,
  });

  final String baslik;
  final String yazar;
  final String? isbn;
  final String? yayinevi;
  final int? yil;
  final int? sayfa;
  final String? not;
  final KitapDurumu durum;
  final int? puan;
  final int? kategoriId;
  final int? rafId;

  Map<String, dynamic> toJson() => {
        'title': baslik,
        'author': yazar,
        'isbn': isbn,
        'publisher': yayinevi,
        'year': yil,
        'pages': sayfa,
        'note': not,
        'status': durum.name,
        'rating': puan,
        'category_id': kategoriId,
        'shelf_id': rafId,
      };
}
