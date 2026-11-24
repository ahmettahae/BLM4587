import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'oturum_olaylari.dart';
import 'token_store.dart';

/// API adresi. Emülatörde bilgisayarın localhost'una 10.0.2.2 ile ulaşılır.
/// Gerçek cihazda bilgisayarın yerel ağ adresi verilir:
///   flutter run --dart-define=API_URL=http://192.168.137.1:8000
const apiAdresi = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

/// Ekranlara gösterilecek, Türkçe ve anlaşılır hata.
class ApiHata implements Exception {
  ApiHata(this.mesaj, {this.durum, this.alanHatalari = const {}});

  final String mesaj;
  final int? durum;

  /// Sunucunun alan alan doğrulama mesajları (ör. {'author': 'En fazla 255 karakter olabilir'}).
  final Map<String, String> alanHatalari;

  @override
  String toString() => mesaj;
}

const _alanEtiketleri = {
  'title': 'Başlık',
  'author': 'Yazar',
  'isbn': 'ISBN',
  'publisher': 'Yayınevi',
  'year': 'Basım yılı',
  'pages': 'Sayfa sayısı',
  'note': 'Not',
  'rating': 'Puan',
  'status': 'Durum',
  'name': 'Ad',
  'description': 'Açıklama',
  'email': 'E-posta',
  'password': 'Şifre',
  'display_name': 'Ad',
};

/// Dio hatasını kullanıcıya gösterilecek mesaja çevirir.
/// Sunucu her hatayı {"detail": "...", "kod": 422, "hatalar": [{"alan", "mesaj"}]} biçiminde döner.
ApiHata apiHatasinaCevir(DioException e) {
  final durum = e.response?.statusCode;
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return ApiHata('Sunucuya ulaşılamadı. İnternet ya da Wi-Fi bağlantını kontrol et.');
    default:
  }
  final veri = e.response?.data;
  if (veri is Map && veri['detail'] is String) {
    final alanlar = <String, String>{
      if (veri['hatalar'] is List)
        for (final h in veri['hatalar'] as List)
          if (h is Map && h['alan'] is String && h['mesaj'] is String) h['alan'] as String: h['mesaj'] as String,
    };
    var mesaj = veri['detail'] as String;
    if (alanlar.isNotEmpty) {
      final ilk = alanlar.entries.first;
      mesaj = '$mesaj: ${_alanEtiketleri[ilk.key] ?? ilk.key} – ${ilk.value}';
    }
    return ApiHata(mesaj, durum: durum, alanHatalari: alanlar);
  }
  if (durum == 422) return ApiHata('Girdiğin bilgileri kontrol et.', durum: durum);
  if (durum != null && durum >= 500) {
    return ApiHata('Sunucuda bir sorun oluştu. Biraz sonra tekrar dene.', durum: durum);
  }
  return ApiHata('Beklenmeyen bir hata oluştu.', durum: durum);
}

/// İsteklere erişim token'ını ekler. 401 gelirse yenileme token'ıyla yeni bir çift alıp
/// isteği bir kez tekrarlar. Yenileme olmazsa oturumu siler ve [oturumBitti]'yi çağırır.
/// [QueuedInterceptor] hataları sırayla işler: aynı anda gelen 401'ler tek yenileme yapar.
class OturumAraKatmani extends QueuedInterceptor {
  OturumAraKatmani(this._depo, this._oturumBitti, this._yenileDio);

  final TokenStore _depo;
  final void Function() _oturumBitti;

  /// Ara katmansız Dio: yenileme isteği ve yenilemeden sonraki tekrar bununla gider.
  final Dio _yenileDio;

  static const _tekrarlandi = 'oturum_tekrarlandi';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _depo.oku();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) => _hataIsle(err, handler);

  Future<void> _hataIsle(DioException hata, ErrorInterceptorHandler isleyici) async {
    final istek = hata.requestOptions;
    if (hata.response?.statusCode != 401 || istek.path.startsWith('/auth/') || istek.extra[_tekrarlandi] == true) {
      return isleyici.next(hata);
    }
    final kullanilan = istek.headers['Authorization'];
    final mevcut = await _depo.oku();
    // Başka bir istek bu arada token'ı yenilediyse yalnız tekrarla.
    if (mevcut != null && 'Bearer $mevcut' != kullanilan) {
      return _tekrarla(istek, mevcut, isleyici, hata);
    }
    final yenileme = await _depo.yenilemeOku();
    if (yenileme == null) {
      await _bitir();
      return isleyici.next(hata);
    }
    final String yeni;
    final nesil = _depo.nesil;
    try {
      final yanit = await _yenileDio.post<Map<String, dynamic>>('/auth/refresh', data: {'refresh_token': yenileme});
      final veri = yanit.data!;
      yeni = veri['access_token'] as String;
      // Yenileme yoldayken çıkış yapıldıysa yeni anahtarları yazma (oturum geri gelmesin).
      if (_depo.nesil != nesil) return isleyici.next(hata);
      await _depo.yaz(yeni, yenileme: veri['refresh_token'] as String?, kalici: _depo.kalici);
    } on DioException catch (yenilemeHatasi) {
      if (yenilemeHatasi.response?.statusCode == 401) {
        await _bitir();
        return isleyici.next(hata);
      }
      return isleyici.next(yenilemeHatasi); // ağ hatası: oturum kalsın
    }
    return _tekrarla(istek, yeni, isleyici, hata);
  }

  Future<void> _bitir() async {
    await _depo.sil();
    _oturumBitti();
  }

  /// Tekrar, bu ara katmanın OLMADIĞI Dio ile yapılır: tekrar da hata verirse hata kuyruğa
  /// geri girip kendini beklemez (kilitlenme olmaz).
  Future<void> _tekrarla(RequestOptions istek, String token, ErrorInterceptorHandler isleyici, DioException hata) async {
    istek.headers['Authorization'] = 'Bearer $token';
    istek.extra[_tekrarlandi] = true;
    try {
      isleyici.resolve(await _yenileDio.fetch<dynamic>(istek));
    } on DioException catch (e) {
      isleyici.next(e);
    }
  }
}

/// Uygulamanın tek Dio örneği; testlerde [adapter] ile sahte sunucu verilir.
Dio dioOlustur(TokenStore depo, {required void Function() oturumBitti, HttpClientAdapter? adapter}) {
  BaseOptions ayarlar() => BaseOptions(
        baseUrl: apiAdresi,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
      );
  final yenileDio = Dio(ayarlar());
  final dio = Dio(ayarlar());
  if (adapter != null) {
    yenileDio.httpClientAdapter = adapter;
    dio.httpClientAdapter = adapter;
  }
  dio.interceptors.add(OturumAraKatmani(depo, oturumBitti, yenileDio));
  return dio;
}

final tokenStoreProvider = Provider<TokenStore>((ref) => GuvenliTokenStore());

final dioProvider = Provider<Dio>((ref) {
  return dioOlustur(
    ref.watch(tokenStoreProvider),
    oturumBitti: () => ref.read(oturumSonaErdiProvider.notifier).bildir(),
  );
});
