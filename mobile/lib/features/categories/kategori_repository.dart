import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'kategori.dart';

/// /categories uçlarıyla konuşan katman. Hatalar [ApiHata] olarak fırlatılır.
class KategoriRepository {
  KategoriRepository(this._dio);

  final Dio _dio;

  Future<T> _cagir<T>(Future<T> Function() istek) async {
    try {
      return await istek();
    } on DioException catch (e) {
      throw apiHatasinaCevir(e);
    }
  }

  Future<List<Kategori>> listele() => _cagir(() async {
        final yanit = await _dio.get<List<dynamic>>('/categories');
        return yanit.data!.map((j) => Kategori.fromJson(j as Map<String, dynamic>)).toList();
      });

  Future<Kategori> ekle(KategoriGirdisi girdi) => _cagir(() async {
        final yanit = await _dio.post<Map<String, dynamic>>('/categories', data: girdi.toJson());
        return Kategori.fromJson(yanit.data!);
      });

  Future<Kategori> guncelle(int id, KategoriGirdisi girdi) => _cagir(() async {
        final yanit = await _dio.put<Map<String, dynamic>>('/categories/$id', data: girdi.toJson());
        return Kategori.fromJson(yanit.data!);
      });

  Future<void> sil(int id) => _cagir(() async {
        await _dio.delete<void>('/categories/$id');
      });
}

final kategoriRepositoryProvider = Provider<KategoriRepository>((ref) => KategoriRepository(ref.watch(dioProvider)));
