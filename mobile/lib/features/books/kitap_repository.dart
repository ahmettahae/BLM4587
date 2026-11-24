import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'kitap.dart';
import 'kitap_filtresi.dart';

/// Bir sayfa kitap ve filtreye uyan toplam sayı (sunucunun X-Total-Count başlığı).
class KitapSayfasi {
  const KitapSayfasi(this.kitaplar, this.toplam);

  final List<Kitap> kitaplar;
  final int toplam;
}

/// Kitapların okuma durumlarına göre sayısı (GET /books/summary).
class KitapOzeti {
  const KitapOzeti({this.toplam = 0, this.okunacak = 0, this.okunuyor = 0, this.okundu = 0});

  final int toplam;
  final int okunacak;
  final int okunuyor;
  final int okundu;

  factory KitapOzeti.fromJson(Map<String, dynamic> j) => KitapOzeti(
        toplam: j['toplam'] as int,
        okunacak: j['okunacak'] as int,
        okunuyor: j['okunuyor'] as int,
        okundu: j['okundu'] as int,
      );
}

/// /books uçlarıyla konuşan katman. Hatalar [ApiHata] olarak fırlatılır.
class KitapRepository {
  KitapRepository(this._dio);

  final Dio _dio;

  /// Kaydırdıkça yüklenen sayfanın boyutu.
  static const sayfaBoyutu = 20;

  Future<T> _cagir<T>(Future<T> Function() istek) async {
    try {
      return await istek();
    } on DioException catch (e) {
      throw apiHatasinaCevir(e);
    }
  }

  /// [filtre]'ye uyan kitaplardan [offset]'ten başlayan bir sayfa (süzme ve sıralama sunucuda).
  Future<KitapSayfasi> sayfa(KitapFiltresi filtre, {int offset = 0, int limit = sayfaBoyutu}) => _cagir(() async {
        final yanit = await _dio.get<List<dynamic>>(
          '/books',
          queryParameters: {...filtre.toQuery(), 'limit': limit, 'offset': offset},
        );
        final kitaplar = yanit.data!.map((j) => Kitap.fromJson(j as Map<String, dynamic>)).toList();
        final toplam = int.tryParse(yanit.headers.value('x-total-count') ?? '') ?? offset + kitaplar.length;
        return KitapSayfasi(kitaplar, toplam);
      });

  Future<KitapOzeti> ozet() => _cagir(() async {
        final yanit = await _dio.get<Map<String, dynamic>>('/books/summary');
        return KitapOzeti.fromJson(yanit.data!);
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
