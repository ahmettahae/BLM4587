import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'auth_repository.dart';
import 'kullanici.dart';

enum OturumDurumu { bilinmiyor, girisYok, girisVar }

class AuthState {
  const AuthState(this.durum, [this.kullanici]);

  final OturumDurumu durum;
  final Kullanici? kullanici;
}

/// Oturumun tek sahibi: uygulama açılışında kayıtlı anahtarı dener, giriş/çıkış yapar.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_oturumuGeriYukle);
    return const AuthState(OturumDurumu.bilinmiyor);
  }

  Future<void> _oturumuGeriYukle() async {
    final depo = ref.read(tokenStoreProvider);
    final token = await depo.oku();
    if (token == null) {
      state = const AuthState(OturumDurumu.girisYok);
      return;
    }
    try {
      final kullanici = await ref.read(authRepositoryProvider).ben();
      state = AuthState(OturumDurumu.girisVar, kullanici);
    } on ApiHata catch (e) {
      // Anahtar geçersizse sil; sunucuya ulaşılamadıysa anahtar kalsın, giriş ekranı açılsın.
      if (e.durum == 401) await depo.sil();
      state = const AuthState(OturumDurumu.girisYok);
    }
  }

  /// Hata olursa [ApiHata] fırlatır; ekran mesajı gösterir.
  Future<void> girisYap(String email, String sifre) async {
    final sonuc = await ref.read(authRepositoryProvider).giris(email, sifre);
    await ref.read(tokenStoreProvider).yaz(sonuc.token);
    state = AuthState(OturumDurumu.girisVar, sonuc.kullanici);
  }

  Future<void> kayitOl(String ad, String email, String sifre) async {
    await ref.read(authRepositoryProvider).kayit(ad, email, sifre);
    await girisYap(email, sifre);
  }

  Future<void> cikisYap() async {
    await ref.read(tokenStoreProvider).sil();
    state = const AuthState(OturumDurumu.girisYok);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
