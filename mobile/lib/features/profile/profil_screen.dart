import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api_client.dart';
import '../../core/tercihler.dart';
import '../auth/auth_controller.dart';
import '../auth/cikis_onayi.dart';

/// Uygulamanın sürümü (pubspec.yaml'daki version). Testlerde sabit değer verilir.
final surumProvider = FutureProvider<String>((ref) async {
  final bilgi = await PackageInfo.fromPlatform();
  return '${bilgi.version} (${bilgi.buildNumber})';
});

/// Profil ve ayarlar: hesap bilgisi, tema seçimi, uygulama sürümü, çıkış.
class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kullanici = ref.watch(authControllerProvider).kullanici;
    final tema = Theme.of(context);
    final surum = ref.watch(surumProvider).value;
    final ad = kullanici?.ad ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Profil', key: Key('profil_baslik'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: tema.colorScheme.primary,
                        child: Text(
                          ad.isEmpty ? '?' : ad.characters.first.toUpperCase(),
                          style: TextStyle(fontSize: 26, color: tema.colorScheme.onPrimary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ad, key: const Key('profil_ad'), style: tema.textTheme.titleLarge),
                            Text(kullanici?.email ?? '', style: tema.textTheme.bodyMedium),
                            const SizedBox(height: 6),
                            Chip(
                              key: const Key('profil_rol'),
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(
                                kullanici?.yoneticiMi ?? false ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                                size: 18,
                              ),
                              label: Text(kullanici?.yoneticiMi ?? false ? 'Yönetici' : 'Kullanıcı'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Görünüm', style: tema.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                key: const Key('tema_secici'),
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Sistem')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Açık')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Koyu')),
                ],
                selected: {ref.watch(temaProvider)},
                onSelectionChanged: (secim) => ref.read(temaProvider.notifier).sec(secim.first),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Uygulama sürümü'),
                      trailing: Text(surum ?? '…', key: const Key('profil_surum')),
                    ),
                    const ListTile(
                      leading: Icon(Icons.dns_outlined),
                      title: Text('Sunucu'),
                      subtitle: Text(apiAdresi),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('cikis_buton'),
                onPressed: () => cikisOnayla(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Çıkış yap'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tema.colorScheme.error,
                  minimumSize: const Size(64, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
