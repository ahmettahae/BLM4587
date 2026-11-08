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
}
