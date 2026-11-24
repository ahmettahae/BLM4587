import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ağ katmanı oturumun yenilenemediğini (süresi doldu, iptal edildi) buradan duyurur.
/// Oturum denetleyicisi bunu dinleyip kullanıcıyı giriş ekranına gönderir.
class OturumSonaErdi extends Notifier<int> {
  @override
  int build() => 0;

  void bildir() => state = state + 1;
}

final oturumSonaErdiProvider = NotifierProvider<OturumSonaErdi, int>(OturumSonaErdi.new);
