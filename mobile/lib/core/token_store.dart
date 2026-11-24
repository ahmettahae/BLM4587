import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Oturum anahtarlarının (erişim + yenileme token'ı) ve "beni hatırla" tercihlerinin saklandığı yer.
///
/// Anahtarlar her zaman bellekte tutulur. [yaz]'a `kalici: true` verilirse ("beni hatırla")
/// cihazın güvenli deposuna da yazılır; böylece uygulama kapanıp açılınca oturum sürer.
/// `kalici: false` ise güvenli depodaki eski anahtarlar silinir; oturum uygulama kapanınca biter.
abstract class TokenStore {
  /// Erişim token'ı (yoksa null).
  Future<String?> oku();

  /// Yenileme token'ı (yoksa null).
  Future<String?> yenilemeOku();

  Future<void> yaz(String erisim, {String? yenileme, bool kalici = true});

  /// Oturum anahtarlarını siler (tercihler ve hatırlanan e-posta kalır).
  Future<void> sil();

  /// Son yazımın kalıcı olup olmadığı; yenilenen anahtarlar aynı şekilde saklanır.
  bool get kalici;

  /// Her [sil]'de artar. Yenileme yoldayken çıkış yapıldıysa gelen anahtarlar yazılmaz.
  int get nesil;

  Future<String?> hatirlananEposta();
  Future<void> epostaHatirla(String? email);

  Future<bool> beniHatirlaTercihi();
  Future<void> beniHatirlaKaydet(bool deger);
}

/// Anahtarları cihazın güvenli deposunda (Android Keystore) tutar.
class GuvenliTokenStore implements TokenStore {
  static const _erisimAnahtari = 'access_token';
  static const _yenilemeAnahtari = 'refresh_token';
  static const _epostaAnahtari = 'hatirlanan_eposta';
  static const _tercihAnahtari = 'beni_hatirla';

  final _depo = const FlutterSecureStorage();
  String? _erisim;
  String? _yenileme;
  bool _kalici = true;
  bool _depodanOkundu = false;
  Future<void>? _ilkOkumaIsi;
  int _nesil = 0;

  /// Aynı anda gelen ilk okumalar tek bir okumayı bekler.
  Future<void> _ilkOkuma() {
    if (_depodanOkundu) return Future.value();
    return _ilkOkumaIsi ??= () async {
      final erisim = await _depo.read(key: _erisimAnahtari);
      final yenileme = await _depo.read(key: _yenilemeAnahtari);
      if (!_depodanOkundu) {
        _erisim = erisim;
        _yenileme = yenileme;
        _depodanOkundu = true;
      }
    }();
  }

  @override
  bool get kalici => _kalici;

  @override
  int get nesil => _nesil;

  @override
  Future<String?> oku() async {
    await _ilkOkuma();
    return _erisim;
  }

  @override
  Future<String?> yenilemeOku() async {
    await _ilkOkuma();
    return _yenileme;
  }

  @override
  Future<void> yaz(String erisim, {String? yenileme, bool kalici = true}) async {
    _depodanOkundu = true;
    _erisim = erisim;
    _yenileme = yenileme;
    _kalici = kalici;
    if (kalici) {
      await _depo.write(key: _erisimAnahtari, value: erisim);
      if (yenileme != null) {
        await _depo.write(key: _yenilemeAnahtari, value: yenileme);
      } else {
        await _depo.delete(key: _yenilemeAnahtari);
      }
    } else {
      await _depo.delete(key: _erisimAnahtari);
      await _depo.delete(key: _yenilemeAnahtari);
    }
  }

  @override
  Future<void> sil() async {
    _nesil++;
    _depodanOkundu = true;
    _erisim = null;
    _yenileme = null;
    await _depo.delete(key: _erisimAnahtari);
    await _depo.delete(key: _yenilemeAnahtari);
  }

  @override
  Future<String?> hatirlananEposta() => _depo.read(key: _epostaAnahtari);

  @override
  Future<void> epostaHatirla(String? email) =>
      email == null ? _depo.delete(key: _epostaAnahtari) : _depo.write(key: _epostaAnahtari, value: email);

  @override
  Future<bool> beniHatirlaTercihi() async => (await _depo.read(key: _tercihAnahtari)) == 'evet';

  @override
  Future<void> beniHatirlaKaydet(bool deger) => _depo.write(key: _tercihAnahtari, value: deger ? 'evet' : 'hayir');
}

/// Testler için: her şey bellekte. [kaliciDepo] "beni hatırla" ile cihaza yazılacak olanı gösterir.
class BellekTokenStore implements TokenStore {
  String? _erisim;
  String? _yenileme;
  bool _kalici = true;
  String? _eposta;
  bool _tercih = false;
  int _nesil = 0;

  @override
  int get nesil => _nesil;

  /// Uygulama yeniden açılsaydı güvenli depoda kalacak anahtarlar.
  final Map<String, String> kaliciDepo = {};

  @override
  bool get kalici => _kalici;

  @override
  Future<String?> oku() async => _erisim;

  @override
  Future<String?> yenilemeOku() async => _yenileme;

  @override
  Future<void> yaz(String erisim, {String? yenileme, bool kalici = true}) async {
    _erisim = erisim;
    _yenileme = yenileme;
    _kalici = kalici;
    kaliciDepo.clear();
    if (kalici) {
      kaliciDepo['erisim'] = erisim;
      if (yenileme != null) kaliciDepo['yenileme'] = yenileme;
    }
  }

  @override
  Future<void> sil() async {
    _nesil++;
    _erisim = null;
    _yenileme = null;
    kaliciDepo.clear();
  }

  @override
  Future<String?> hatirlananEposta() async => _eposta;

  @override
  Future<void> epostaHatirla(String? email) async => _eposta = email;

  @override
  Future<bool> beniHatirlaTercihi() async => _tercih;

  @override
  Future<void> beniHatirlaKaydet(bool deger) async => _tercih = deger;
}
