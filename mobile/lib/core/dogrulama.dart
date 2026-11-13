/// Form alanı doğrulayıcıları. Geçerliyse null, değilse hata mesajı döner.
/// API de aynı kuralları uygular; burada amaç kullanıcıya hemen geri bildirim vermek.
class Dogrulama {
  static final _epostaDeseni = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? eposta(String? deger) {
    final v = deger?.trim() ?? '';
    if (v.isEmpty) return 'E-posta gerekli';
    if (!_epostaDeseni.hasMatch(v)) return 'Geçerli bir e-posta yaz';
    return null;
  }

  static String? sifre(String? deger) {
    final v = deger ?? '';
    if (v.isEmpty) return 'Şifre gerekli';
    if (v.length < 8) return 'Şifre en az 8 karakter olmalı';
    if (v.length > 128) return 'Şifre en fazla 128 karakter olabilir';
    return null;
  }

  static String? ad(String? deger) {
    final v = deger?.trim() ?? '';
    if (v.isEmpty) return 'Ad gerekli';
    if (v.length > 100) return 'Ad en fazla 100 karakter olabilir';
    return null;
  }
}

/// Kitap formu doğrulayıcıları (API'deki BookIn kurallarıyla aynı).
class KitapDogrulama {
  static String? _zorunlu(String? deger, String alan) {
    final v = deger?.trim() ?? '';
    if (v.isEmpty) return '$alan gerekli';
    if (v.length > 255) return '$alan en fazla 255 karakter olabilir';
    return null;
  }

  static String? baslik(String? deger) => _zorunlu(deger, 'Başlık');

  static String? yazar(String? deger) => _zorunlu(deger, 'Yazar');

  static String? yayinevi(String? deger) =>
      (deger?.trim().length ?? 0) > 255 ? 'Yayınevi en fazla 255 karakter olabilir' : null;

  /// Tire ve boşlukları atar, büyük harfe çevirir. Boşsa null.
  static String? isbnTemizle(String? deger) {
    final v = (deger ?? '').replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    return v.isEmpty ? null : v;
  }

  static String? isbn(String? deger) {
    final v = isbnTemizle(deger);
    if (v == null) return null;
    if (RegExp(r'^\d{13}$').hasMatch(v) || RegExp(r'^\d{9}[\dX]$').hasMatch(v)) return null;
    return 'ISBN 10 ya da 13 haneli olmalı';
  }

  static String? yil(String? deger, {DateTime? simdi}) {
    final v = deger?.trim() ?? '';
    if (v.isEmpty) return null;
    final yil = int.tryParse(v);
    if (yil == null || yil < 1) return 'Geçerli bir yıl yaz';
    if (yil > (simdi ?? DateTime.now()).year + 1) return 'Basım yılı gelecekte olamaz';
    return null;
  }

  static String? sayfa(String? deger) {
    final v = deger?.trim() ?? '';
    if (v.isEmpty) return null;
    final sayi = int.tryParse(v);
    if (sayi == null || sayi < 1 || sayi > 50000) return 'Sayfa 1 ile 50000 arasında olmalı';
    return null;
  }

  static String? not(String? deger) => (deger?.length ?? 0) > 2000 ? 'Not en fazla 2000 karakter olabilir' : null;
}
