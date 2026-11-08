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
