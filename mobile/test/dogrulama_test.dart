import 'package:flutter_test/flutter_test.dart';
import 'package:kitapligim/core/dogrulama.dart';

void main() {
  group('e-posta', () {
    test('boş ya da bozuk adres reddedilir', () {
      expect(Dogrulama.eposta(null), isNotNull);
      expect(Dogrulama.eposta('   '), isNotNull);
      expect(Dogrulama.eposta('abc'), isNotNull);
      expect(Dogrulama.eposta('abc@'), isNotNull);
      expect(Dogrulama.eposta('a b@c.com'), isNotNull);
    });

    test('geçerli adres kabul edilir', () {
      expect(Dogrulama.eposta('kisi@ornek.com'), isNull);
      expect(Dogrulama.eposta('  kisi@ornek.com '), isNull);
    });
  });

  group('şifre', () {
    test('8 karakterden kısa şifre reddedilir', () {
      expect(Dogrulama.sifre(''), isNotNull);
      expect(Dogrulama.sifre('1234567'), isNotNull);
    });

    test('8 ve üstü kabul edilir', () {
      expect(Dogrulama.sifre('12345678'), isNull);
    });
  });

  group('ad', () {
    test('boşluktan oluşan ad reddedilir', () {
      expect(Dogrulama.ad('   '), isNotNull);
      expect(Dogrulama.ad('Ayşe'), isNull);
    });
  });

  group('kitap', () {
    test('başlık ve yazar zorunlu, 255 karakter sınırı var', () {
      expect(KitapDogrulama.baslik('  '), 'Başlık gerekli');
      expect(KitapDogrulama.yazar(null), 'Yazar gerekli');
      expect(KitapDogrulama.baslik('a' * 256), isNotNull);
      expect(KitapDogrulama.baslik('Tutunamayanlar'), isNull);
    });

    test('ISBN 10 (X dahil) ya da 13 hane; tire ve boşluk atılır', () {
      expect(KitapDogrulama.isbn(''), isNull);
      expect(KitapDogrulama.isbn('978-975-470-090-5'), isNull);
      expect(KitapDogrulama.isbn('0 8044 2957 x'), isNull);
      expect(KitapDogrulama.isbn('12345'), isNotNull);
      expect(KitapDogrulama.isbn('97897547009X5'), isNotNull);
      expect(KitapDogrulama.isbnTemizle('0-8044-2957-x'), '080442957X');
      expect(KitapDogrulama.isbnTemizle('  '), isNull);
    });

    test('yıl gelecekte olamaz, sayfa 1-50000', () {
      final simdi = DateTime(2026, 11, 13);
      expect(KitapDogrulama.yil('', simdi: simdi), isNull);
      expect(KitapDogrulama.yil('2027', simdi: simdi), isNull);
      expect(KitapDogrulama.yil('2028', simdi: simdi), isNotNull);
      expect(KitapDogrulama.yil('0', simdi: simdi), isNotNull);
      expect(KitapDogrulama.sayfa('0'), isNotNull);
      expect(KitapDogrulama.sayfa('50001'), isNotNull);
      expect(KitapDogrulama.sayfa('724'), isNull);
    });
  });
}
