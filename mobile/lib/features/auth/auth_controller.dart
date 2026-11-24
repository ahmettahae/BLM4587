import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/oturum_olaylari.dart';
import 'auth_repository.dart';
import 'kullanici.dart';

enum OturumDurumu { bilinmiyor, girisYok, girisVar }

class AuthState {
  const AuthState(this.durum, [this.kullanici, this.bilgi]);

  final OturumDurumu durum;
  final Kullanici? kullanici;

  /// Giriş ekranında gösterilecek bilgi (ör. "Oturumun sona erdi").
  final String? bilgi;
}

const oturumSonaErdiMesaji = 'Oturumun sona erdi. Tekrar giriş yap.';

/// Oturumun tek sahibi: uygulama açılışında kayıtlı anahtarı dener, giriş/çıkış yapar.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Ağ katmanı token'ı yenileyemezse kullanıcıyı giriş ekranına gönder.
    ref.listen(oturumSonaErdiProvider, (_, _) {
      if (state.durum != OturumDurumu.girisYok) {
        state = const AuthState(OturumDurumu.girisYok, null, oturumSonaErdiMesaji);
      }
    });
    Future.microtask(_oturumuGeriYukle);
    return const AuthState(OturumDurumu.bilinmiyor);
  }

  Future<void> _oturumuGeriYukle() async {
    final depo = ref.read(tokenStoreProvider);
    try {
      final token = await depo.oku();
      if (token == null) {
        state = const AuthState(OturumDurumu.girisYok);
        return;
      }
      final kullanici = await ref.read(authRepositoryProvider).ben();
      state = AuthState(OturumDurumu.girisVar, kullanici);
    } on ApiHata catch (e) {
      // Anahtar geçersizse sil; sunucuya ulaşılamadıysa anahtar kalsın, giriş ekranı açılsın.
      if (e.durum == 401) await depo.sil();
      if (state.durum == OturumDurumu.bilinmiyor) state = const AuthState(OturumDurumu.girisYok);
    } catch (_) {
      // Güvenli depo okunamadı (ör. yedekten geri yükleme): açılış ekranında kalma, girişe geç.
      if (state.durum == OturumDurumu.bilinmiyor) state = const AuthState(OturumDurumu.girisYok);
    }
  }

  /// Hata olursa [ApiHata] fırlatır; ekran mesajı gösterir.
  /// [beniHatirla] işaretliyse oturum ve e-posta cihaza kaydedilir; değilse uygulama kapanınca oturum biter.
  Future<void> girisYap(String email, String sifre, {bool beniHatirla = false}) async {
    final sonuc = await ref.read(authRepositoryProvider).giris(email, sifre, beniHatirla: beniHatirla);
    final depo = ref.read(tokenStoreProvider);
    await depo.yaz(sonuc.token, yenileme: sonuc.yenileme, kalici: beniHatirla);
    await depo.beniHatirlaKaydet(beniHatirla);
    await depo.epostaHatirla(beniHatirla ? email.trim() : null);
    state = AuthState(OturumDurumu.girisVar, sonuc.kullanici);
  }

  Future<void> kayitOl(String ad, String email, String sifre) async {
    await ref.read(authRepositoryProvider).kayit(ad, email, sifre);
    final beniHatirla = await ref.read(tokenStoreProvider).beniHatirlaTercihi();
    await girisYap(email, sifre, beniHatirla: beniHatirla);
  }

  Future<void> cikisYap() async {
    final depo = ref.read(tokenStoreProvider);
    final yenileme = await depo.yenilemeOku();
    await depo.sil();
    state = const AuthState(OturumDurumu.girisYok);
    if (yenileme != null) await ref.read(authRepositoryProvider).cikis(yenileme);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
