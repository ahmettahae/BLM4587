import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'kullanici.dart';

/// Giriş sonucu: oturum anahtarı ve kullanıcı.
class GirisSonucu {
  const GirisSonucu(this.token, this.kullanici);

  final String token;
  final Kullanici kullanici;
}

/// Kimlik uçlarıyla konuşan katman. Ekranlar Dio'yu doğrudan görmez.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<GirisSonucu> giris(String email, String sifre) async {
    try {
      final yanit = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'username': email.trim(), 'password': sifre},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final veri = yanit.data!;
      return GirisSonucu(veri['access_token'] as String, Kullanici.fromJson(veri['user'] as Map<String, dynamic>));
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
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));
