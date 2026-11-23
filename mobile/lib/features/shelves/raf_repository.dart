import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'raf.dart';

/// /shelves uçlarıyla konuşan katman. Hatalar [ApiHata] olarak fırlatılır.
class RafRepository {
  RafRepository(this._dio);

  final Dio _dio;

  Future<T> _cagir<T>(Future<T> Function() istek) async {
    try {
      return await istek();
    } on DioException catch (e) {
      throw apiHatasinaCevir(e);
    }
  }

  Future<List<Raf>> listele() => _cagir(() async {
        final yanit = await _dio.get<List<dynamic>>('/shelves');
        return yanit.data!.map((j) => Raf.fromJson(j as Map<String, dynamic>)).toList();
      });

  Future<Raf> ekle(RafGirdisi girdi) => _cagir(() async {
        final yanit = await _dio.post<Map<String, dynamic>>('/shelves', data: girdi.toJson());
        return Raf.fromJson(yanit.data!);
      });

  Future<Raf> guncelle(int id, RafGirdisi girdi) => _cagir(() async {
        final yanit = await _dio.put<Map<String, dynamic>>('/shelves/$id', data: girdi.toJson());
        return Raf.fromJson(yanit.data!);
      });

  Future<void> sil(int id) => _cagir(() async {
        await _dio.delete<void>('/shelves/$id');
      });
}

final rafRepositoryProvider = Provider<RafRepository>((ref) => RafRepository(ref.watch(dioProvider)));
