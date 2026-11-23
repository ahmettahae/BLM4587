import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'kitap.dart';
import 'kitap_filtresi.dart';

/// /books uçlarıyla konuşan katman. Hatalar [ApiHata] olarak fırlatılır.
class KitapRepository {
  KitapRepository(this._dio);

  final Dio _dio;

  Future<T> _cagir<T>(Future<T> Function() istek) async {
    try {
      return await istek();
    } on DioException catch (e) {
      throw apiHatasinaCevir(e);
    }
  }

  /// Kitapları [filtre]'ye göre sunucuda süzerek getirir (boş filtre = hepsi).
  Future<List<Kitap>> listele([KitapFiltresi filtre = const KitapFiltresi()]) => _cagir(() async {
        final yanit = await _dio.get<List<dynamic>>('/books', queryParameters: filtre.toQuery());
        return yanit.data!.map((j) => Kitap.fromJson(j as Map<String, dynamic>)).toList();
      });

  Future<Kitap> getir(int id) => _cagir(() async {
        final yanit = await _dio.get<Map<String, dynamic>>('/books/$id');
        return Kitap.fromJson(yanit.data!);
      });

  Future<Kitap> ekle(KitapGirdisi girdi) => _cagir(() async {
        final yanit = await _dio.post<Map<String, dynamic>>('/books', data: girdi.toJson());
        return Kitap.fromJson(yanit.data!);
      });

  Future<Kitap> guncelle(int id, KitapGirdisi girdi) => _cagir(() async {
        final yanit = await _dio.put<Map<String, dynamic>>('/books/$id', data: girdi.toJson());
        return Kitap.fromJson(yanit.data!);
      });

  Future<void> sil(int id) => _cagir(() async {
        await _dio.delete<void>('/books/$id');
      });
}

final kitapRepositoryProvider = Provider<KitapRepository>((ref) => KitapRepository(ref.watch(dioProvider)));
