/// Yöneticinin yönettiği kitap kategorisi (Roman, Bilim vb.).
class Kategori {
  const Kategori({required this.id, required this.ad, this.aciklama, this.kitapSayisi = 0});

  final int id;
  final String ad;
  final String? aciklama;
  final int kitapSayisi;

  factory Kategori.fromJson(Map<String, dynamic> json) => Kategori(
        id: json['id'] as int,
        ad: json['name'] as String,
        aciklama: json['description'] as String?,
        kitapSayisi: (json['book_count'] as int?) ?? 0,
      );
}

/// Ekleme ve düzenleme formunun API'ye gönderdiği veri.
class KategoriGirdisi {
  const KategoriGirdisi({required this.ad, this.aciklama});

  final String ad;
  final String? aciklama;

  Map<String, dynamic> toJson() => {'name': ad, 'description': aciklama};
}

/// Kategori numarasından adı bulur; liste henüz yüklenmediyse ya da kategori yoksa null.
String? kategoriAdi(List<Kategori>? liste, int? id) {
  if (liste == null || id == null) return null;
  for (final k in liste) {
    if (k.id == id) return k.ad;
  }
  return null;
}
