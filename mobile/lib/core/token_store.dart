import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Oturum anahtarının (JWT) saklandığı yer. Testlerde bellekteki sürüm kullanılır.
abstract class TokenStore {
  Future<String?> oku();
  Future<void> yaz(String token);
  Future<void> sil();
}

/// Anahtarı cihazın güvenli deposunda (Android Keystore) tutar.
class GuvenliTokenStore implements TokenStore {
  static const _anahtar = 'access_token';
  final _depo = const FlutterSecureStorage();

  @override
  Future<String?> oku() => _depo.read(key: _anahtar);

  @override
  Future<void> yaz(String token) => _depo.write(key: _anahtar, value: token);

  @override
  Future<void> sil() => _depo.delete(key: _anahtar);
}

class BellekTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> oku() async => _token;

  @override
  Future<void> yaz(String token) async => _token = token;

  @override
  Future<void> sil() async => _token = null;
}
