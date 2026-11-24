import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitapligim/core/api_client.dart';
import 'package:kitapligim/core/token_store.dart';

/// Ağa çıkmayan sahte sunucu: "yeni" token'ı kabul eder, "r1" yenileme token'ını bir kez değiştirir.
class SahteSunucu implements HttpClientAdapter {
  int yenilemeSayisi = 0;
  bool yenilemeReddet = false;
  final List<String> istekler = [];

  ResponseBody _json(int durum, Object govde) => ResponseBody.fromString(
        jsonEncode(govde),
        durum,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    istekler.add('${options.method} ${options.path}');
    if (options.path == '/auth/refresh') {
      yenilemeSayisi++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final govde = options.data as Map<String, dynamic>;
      if (yenilemeReddet || govde['refresh_token'] != 'r1') {
        return _json(401, {'detail': 'Oturumun süresi dolmuş', 'kod': 401, 'hatalar': []});
      }
      return _json(200, {
        'access_token': 'yeni',
        'refresh_token': 'r2',
        'token_type': 'bearer',
        'expires_in': 1800,
        'user': {'id': 1, 'email': 'a@b.com', 'display_name': 'A', 'role': 'user'},
      });
    }
    if (options.path == '/auth/login') {
      return _json(401, {'detail': 'E-posta ya da şifre hatalı', 'kod': 401, 'hatalar': []});
    }
    if (options.path == '/kitap-yok' && options.headers['Authorization'] == 'Bearer yeni') {
      return _json(404, {'detail': 'Kitap bulunamadı', 'kod': 404, 'hatalar': []});
    }
    if (options.headers['Authorization'] == 'Bearer yeni') return _json(200, <Object>[]);
    return _json(401, {'detail': 'Geçersiz ya da süresi dolmuş oturum', 'kod': 401, 'hatalar': []});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late SahteSunucu sunucu;
  late BellekTokenStore depo;
  late int bitisBildirimi;
  late Dio dio;

  setUp(() async {
    sunucu = SahteSunucu();
    depo = BellekTokenStore();
    await depo.yaz('eski', yenileme: 'r1', kalici: false);
    bitisBildirimi = 0;
    dio = dioOlustur(depo, oturumBitti: () => bitisBildirimi++, adapter: sunucu);
  });

  test('401 alınca token yenilenir, istek tekrarlanır, saklama biçimi korunur', () async {
    final yanit = await dio.get<List<dynamic>>('/books');
    expect(yanit.statusCode, 200);
    expect(await depo.oku(), 'yeni');
    expect(await depo.yenilemeOku(), 'r2');
    expect(depo.kalici, isFalse); // "beni hatırla" kapalıysa yenilenen anahtar da cihaza yazılmaz
    expect(depo.kaliciDepo, isEmpty);
    expect(bitisBildirimi, 0);
  });

  test('aynı anda gelen iki 401 için token bir kez yenilenir', () async {
    final sonuclar = await Future.wait([dio.get<List<dynamic>>('/books'), dio.get<List<dynamic>>('/shelves')]);
    expect(sonuclar.map((y) => y.statusCode), [200, 200]);
    expect(sunucu.yenilemeSayisi, 1);
  });

  test('yenileme reddedilirse oturum silinir ve bitti bildirilir', () async {
    sunucu.yenilemeReddet = true;
    await expectLater(dio.get<List<dynamic>>('/books'), throwsA(isA<DioException>()));
    expect(await depo.oku(), isNull);
    expect(await depo.yenilemeOku(), isNull);
    expect(bitisBildirimi, 1);
  });

  test('yenileme token\'ı yoksa doğrudan oturum biter', () async {
    await depo.yaz('eski', kalici: false);
    await expectLater(dio.get<List<dynamic>>('/books'), throwsA(isA<DioException>()));
    expect(sunucu.yenilemeSayisi, 0);
    expect(bitisBildirimi, 1);
  });

  test('yenilemeden sonra tekrarlanan istek de hata verirse hata hemen döner (kilitlenmez)', () async {
    final hata = await dio
        .get<void>('/kitap-yok')
        .then<Object?>((_) => null, onError: (Object e) => e)
        .timeout(const Duration(seconds: 2));
    expect(hata, isA<DioException>());
    expect((hata! as DioException).response?.statusCode, 404);
    // Kuyruk tıkanmadı: sonraki istek de sonuçlanır.
    final sonraki = await dio.get<List<dynamic>>('/books').timeout(const Duration(seconds: 2));
    expect(sonraki.statusCode, 200);
  });

  test('yenileme sürerken çıkış yapılırsa gelen yeni anahtarlar yazılmaz', () async {
    final istek = dio.get<List<dynamic>>('/books').then<Object?>((r) => r, onError: (Object e) => e);
    await Future<void>.delayed(const Duration(milliseconds: 2)); // yenileme isteği yolda
    await depo.sil(); // kullanıcı çıkış yaptı
    final sonuc = await istek.timeout(const Duration(seconds: 2));
    expect(sonuc, isA<DioException>());
    expect(await depo.oku(), isNull);
    expect(await depo.yenilemeOku(), isNull);
  });

  test('giriş ucundaki 401 yenileme denemez (yanlış şifre)', () async {
    await expectLater(dio.post<void>('/auth/login', data: {}), throwsA(isA<DioException>()));
    expect(sunucu.yenilemeSayisi, 0);
    expect(bitisBildirimi, 0);
  });

  group('hata çevirisi', () {
    DioException hata(int durum, Object govde) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: durum, data: govde),
        );

    test('alan hataları Türkçe etiketle mesaja eklenir', () {
      final h = apiHatasinaCevir(hata(422, {
        'detail': 'Girdiğin bilgileri kontrol et',
        'kod': 422,
        'hatalar': [
          {'alan': 'author', 'mesaj': 'En fazla 255 karakter olabilir'},
        ],
      }));
      expect(h.mesaj, 'Girdiğin bilgileri kontrol et: Yazar – En fazla 255 karakter olabilir');
      expect(h.alanHatalari, {'author': 'En fazla 255 karakter olabilir'});
      expect(h.durum, 422);
    });

    test('düz detay mesajı olduğu gibi kalır', () {
      expect(apiHatasinaCevir(hata(429, {'detail': 'Çok fazla hatalı deneme. 15 dakika sonra tekrar dene.'})).mesaj,
          'Çok fazla hatalı deneme. 15 dakika sonra tekrar dene.');
    });

    test('sunucu hatasında anlaşılır mesaj', () {
      expect(apiHatasinaCevir(hata(500, 'Internal Server Error')).mesaj, 'Sunucuda bir sorun oluştu. Biraz sonra tekrar dene.');
    });
  });
}
