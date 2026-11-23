/// Kullanıcının kendi kitap rafı (Salon, Yatak odası vb.).
class Raf {
  const Raf({required this.id, required this.ad, this.kitapSayisi = 0});

  final int id;
  final String ad;
  final int kitapSayisi;

  factory Raf.fromJson(Map<String, dynamic> json) => Raf(
        id: json['id'] as int,
        ad: json['name'] as String,
        kitapSayisi: (json['book_count'] as int?) ?? 0,
      );
}

/// Ekleme ve yeniden adlandırma penceresinin API'ye gönderdiği veri.
class RafGirdisi {
  const RafGirdisi({required this.ad});

  final String ad;

  Map<String, dynamic> toJson() => {'name': ad};
}

/// Raf numarasından adı bulur; liste henüz yüklenmediyse ya da raf yoksa null.
String? rafAdi(List<Raf>? liste, int? id) {
  if (liste == null || id == null) return null;
  for (final r in liste) {
    if (r.id == id) return r.ad;
  }
  return null;
}
