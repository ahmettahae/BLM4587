import 'package:flutter/material.dart';

/// Giriş ve kayıt ekranlarının ortak düzeni: ortada, en fazla 440 piksel genişlikte,
/// klavye açılınca ya da küçük ekranda kaydırılabilir (farklı ekran boyutları için).
class AuthFormKabugu extends StatelessWidget {
  const AuthFormKabugu({super.key, required this.baslik, required this.children});

  final String baslik;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.menu_book_rounded, size: 64, color: tema.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('Kitaplığım', textAlign: TextAlign.center, style: tema.textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  Text(baslik, style: tema.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
