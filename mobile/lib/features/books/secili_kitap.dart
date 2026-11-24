import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Tablet düzeninde sağ panelde açık olan kitap (telefonda kullanılmaz).
class SeciliKitap extends Notifier<int?> {
  @override
  int? build() {
    ref.watch(authControllerProvider.select((s) => s.kullanici?.id));
    return null;
  }

  void sec(int? id) => state = id;
}

final seciliKitapProvider = NotifierProvider<SeciliKitap, int?>(SeciliKitap.new);
