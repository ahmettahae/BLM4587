import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/giris_screen.dart';
import '../features/auth/kayit_screen.dart';
import '../features/books/kitap_detay_screen.dart';
import '../features/books/kitap_form_screen.dart';
import '../features/home/home_screen.dart';

const _herkeseAcik = {'/giris', '/kayit'};

/// Oturum durumuna göre ekranları yönlendirir:
/// bilinmiyor -> yükleniyor, giriş yok -> giriş/kayıt, giriş var -> ana sayfa.
final routerProvider = Provider<GoRouter>((ref) {
  final durum = ValueNotifier<OturumDurumu>(ref.read(authControllerProvider).durum);
  ref.listen(authControllerProvider, (_, yeni) => durum.value = yeni.durum);
  ref.onDispose(durum.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: durum,
    redirect: (context, state) {
      final yol = state.matchedLocation;
      switch (durum.value) {
        case OturumDurumu.bilinmiyor:
          return yol == '/yukleniyor' ? null : '/yukleniyor';
        case OturumDurumu.girisYok:
          return _herkeseAcik.contains(yol) ? null : '/giris';
        case OturumDurumu.girisVar:
          return (_herkeseAcik.contains(yol) || yol == '/yukleniyor') ? '/' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const HomeScreen(),
        routes: [
          GoRoute(path: 'kitap/yeni', builder: (_, _) => const KitapFormScreen()),
          GoRoute(
            path: 'kitap/:id',
            builder: (_, state) => KitapDetayScreen(kitapId: int.parse(state.pathParameters['id']!)),
            routes: [
              GoRoute(
                path: 'duzenle',
                builder: (_, state) => KitapFormScreen(kitapId: int.parse(state.pathParameters['id']!)),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/giris', builder: (_, _) => const GirisScreen()),
      GoRoute(path: '/kayit', builder: (_, _) => const KayitScreen()),
      GoRoute(
        path: '/yukleniyor',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    ],
  );
});
