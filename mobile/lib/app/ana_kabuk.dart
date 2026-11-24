import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/gorunum.dart';
import '../features/auth/auth_controller.dart';

/// Sekme: dal numarası (router'daki sıra), ikon, ad, test anahtarı, yalnız yöneticiye mi.
typedef _Sekme = ({int dal, IconData ikon, IconData seciliIkon, String ad, String anahtar, bool yonetici});

const List<_Sekme> _sekmeler = [
  (dal: 0, ikon: Icons.library_books_outlined, seciliIkon: Icons.library_books, ad: 'Kitaplar', anahtar: 'nav_kitaplar', yonetici: false),
  (dal: 1, ikon: Icons.shelves, seciliIkon: Icons.shelves, ad: 'Raflar', anahtar: 'nav_raflar', yonetici: false),
  (
    dal: 2,
    ikon: Icons.admin_panel_settings_outlined,
    seciliIkon: Icons.admin_panel_settings,
    ad: 'Yönetim',
    anahtar: 'nav_yonetim',
    yonetici: true,
  ),
  (dal: 3, ikon: Icons.person_outline, seciliIkon: Icons.person, ad: 'Profil', anahtar: 'nav_profil', yonetici: false),
];

/// Giriş sonrası iskelet: telefonda alt gezinme çubuğu, tablette solda gezinme rayı.
/// Her sekme kendi gezinme geçmişini korur (StatefulShellRoute).
class AnaKabuk extends ConsumerWidget {
  const AnaKabuk({super.key, required this.kabuk});

  final StatefulNavigationShell kabuk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yonetici = ref.watch(authControllerProvider.select((s) => s.kullanici?.yoneticiMi ?? false));
    final gorunen = [for (final s in _sekmeler) if (!s.yonetici || yonetici) s];
    final secili = gorunen.indexWhere((s) => s.dal == kabuk.currentIndex).clamp(0, gorunen.length - 1);

    void git(int i) {
      final dal = gorunen[i].dal;
      // Aynı sekmeye tekrar dokununca o sekmenin başına dön.
      kabuk.goBranch(dal, initialLocation: dal == kabuk.currentIndex);
    }

    if (genisEkranMi(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: secili,
              onDestinationSelected: git,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Icon(Icons.menu_book_rounded, size: 32, color: Theme.of(context).colorScheme.primary),
              ),
              destinations: [
                for (final s in gorunen)
                  NavigationRailDestination(
                    icon: Icon(s.ikon, key: Key(s.anahtar)),
                    selectedIcon: Icon(s.seciliIkon, key: Key(s.anahtar)),
                    label: Text(s.ad),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: kabuk),
          ],
        ),
      );
    }
    return Scaffold(
      body: kabuk,
      bottomNavigationBar: NavigationBar(
        selectedIndex: secili,
        onDestinationSelected: git,
        destinations: [
          for (final s in gorunen)
            NavigationDestination(
              key: Key(s.anahtar),
              icon: Icon(s.ikon),
              selectedIcon: Icon(s.seciliIkon),
              label: s.ad,
            ),
        ],
      ),
    );
  }
}

/// Uygulama açılırken oturum denetlenirken görünen ekran (Android açılış ekranıyla aynı renk).
class YuklemeEkrani extends StatelessWidget {
  const YuklemeEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('yukleme_ekrani'),
      backgroundColor: Color(0xFF2E6B57),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 88, color: Colors.white),
            SizedBox(height: 12),
            Text('Kitaplığım', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600)),
            SizedBox(height: 24),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
          ],
        ),
      ),
    );
  }
}
