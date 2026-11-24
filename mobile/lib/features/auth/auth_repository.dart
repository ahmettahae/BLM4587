import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'kullanici.dart';

/// Giriş sonucu: erişim token'ı, yenileme token'ı ve kullanıcı.
class GirisSonucu {
  const GirisSonucu(this.token, this.kullanici, {this.yenileme});

  final String token;
  final Kullanici kullanici;
  final String? yenileme;
}

/// Kimlik uçlarıyla konuşan katman. Ekranlar Dio'yu doğrudan görmez.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// [beniHatirla] sunucuya da gider: işaretliyse yenileme token'ı 30 gün, değilse 12 saat geçerli.
  Future<GirisSonucu> giris(String email, String sifre, {bool beniHatirla = false}) async {
    try {
      final yanit = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'username': email.trim(), 'password': sifre, 'remember_me': beniHatirla ? 'true' : 'false'},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final veri = yanit.data!;
      return GirisSonucu(
        veri['access_token'] as String,
        Kullanici.fromJson(veri['user'] as Map<String, dynamic>),
        yenileme: veri['refresh_token'] as String?,
      );
    } on DioException catch (e) {
      throw apiHatasinaCevir(e);
    }
  }

  Future<void> kayit(String ad, String email, String sifre) async {
    try {
      await _dio.post<void>(
        '/auth/register',
        data: {'display_name': ad.trim(), 'email': email.trim(), 'password': sifre},
      );
    } on DioException catch (e) {
      throw apiHatasinaCevir(e);
    }
  }

  Future<Kullanici> ben() async {
    try {
      final yanit = await _dio.get<Map<String, dynamic>>('/me');
      return Kullanici.fromJson(yanit.data!);
    } on DioException catch (e) {
      throw apiHatasinaCevir(e);
    }
  }

  /// Sunucudaki yenileme token'ını iptal eder. Ağ hatası çıkışı engellemez.
  Future<void> cikis(String yenileme) async {
    try {
      await _dio.post<void>('/auth/logout', data: {'refresh_token': yenileme});
    } on DioException {
      // Çıkış yerelde zaten tamamlandı; sunucuya ulaşılamazsa token kendi süresinde ölür.
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));
