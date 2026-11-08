import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Giriş sonrası ana sayfa. Kitap listesi 3. haftada buraya gelecek;
/// şimdilik oturumu ve rolü gösterir, yönetici için ayrı bir bölüm açar.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kullanici = ref.watch(authControllerProvider).kullanici;
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitaplığım'),
        actions: [
          IconButton(
            key: const Key('cikis_buton'),
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).cikisYap(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Merhaba ${kullanici?.ad ?? ''}', style: tema.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(kullanici?.email ?? '', style: tema.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Kitaplarım'),
                  subtitle: const Text('Kitap listesi 3. haftada eklenecek'),
                ),
              ),
              if (kullanici?.yoneticiMi ?? false)
                Card(
                  key: const Key('yonetici_karti'),
                  child: ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Yönetim'),
                    subtitle: const Text('Kategori yönetimi 4. haftada eklenecek'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
