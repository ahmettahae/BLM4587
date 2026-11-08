import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_store.dart';

/// API adresi. Emülatörde bilgisayarın localhost'una 10.0.2.2 ile ulaşılır.
/// Gerçek telefonda bilgisayarın yerel ağ adresi verilir:
///   flutter run --dart-define=API_URL=http://192.168.1.20:8000
const apiAdresi = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

/// Ekranlara gösterilecek, Türkçe ve anlaşılır hata.
class ApiHata implements Exception {
  ApiHata(this.mesaj, {this.durum});

  final String mesaj;
  final int? durum;

  @override
  String toString() => mesaj;
}

/// Dio hatasını kullanıcıya gösterilecek mesaja çevirir.
ApiHata apiHatasinaCevir(DioException e) {
  final durum = e.response?.statusCode;
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return ApiHata('Sunucuya ulaşılamadı. API çalışıyor mu ve adres doğru mu?');
    default:
  }
  final veri = e.response?.data;
  if (veri is Map && veri['detail'] is String) {
    return ApiHata(veri['detail'] as String, durum: durum);
  }
  if (durum == 422) {
    return ApiHata('Girdiğin bilgileri kontrol et.', durum: durum);
  }
  return ApiHata('Beklenmeyen bir hata oluştu.', durum: durum);
}

final tokenStoreProvider = Provider<TokenStore>((ref) => GuvenliTokenStore());

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiAdresi,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final store = ref.watch(tokenStoreProvider);
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (istek, isleyici) async {
        final token = await store.oku();
        if (token != null) {
          istek.headers['Authorization'] = 'Bearer $token';
        }
        isleyici.next(istek);
      },
    ),
  );
  return dio;
});
