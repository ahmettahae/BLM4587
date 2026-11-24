import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// Yanlışlıkla çıkışı önlemek için onay penceresi; onaylanırsa oturum kapanır.
Future<void> cikisOnayla(BuildContext context, WidgetRef ref) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.logout),
      title: const Text('Çıkış yapılsın mı?'),
      content: const Text('Tekrar girmek için e-posta ve şifren gerekecek.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(
          key: const Key('cikis_onay'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Çıkış yap'),
        ),
      ],
    ),
  );
  if (onay == true) await ref.read(authControllerProvider.notifier).cikisYap();
}
