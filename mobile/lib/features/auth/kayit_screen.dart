import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/dogrulama.dart';
import 'auth_controller.dart';
import 'auth_form_kabugu.dart';

class KayitScreen extends ConsumerStatefulWidget {
  const KayitScreen({super.key});

  @override
  ConsumerState<KayitScreen> createState() => _KayitScreenState();
}

class _KayitScreenState extends ConsumerState<KayitScreen> {
  final _form = GlobalKey<FormState>();
  final _ad = TextEditingController();
  final _email = TextEditingController();
  final _sifre = TextEditingController();
  final _sifreTekrar = TextEditingController();
  bool _sifreGizli = true;
  bool _bekliyor = false;
  String? _hata;

  @override
  void dispose() {
    _ad.dispose();
    _email.dispose();
    _sifre.dispose();
    _sifreTekrar.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).kayitOl(_ad.text, _email.text, _sifre.text);
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormKabugu(
      baslik: 'Kayıt ol',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                key: const Key('kayit_ad'),
                controller: _ad,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder()),
                validator: Dogrulama.ad,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('kayit_email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder()),
                validator: Dogrulama.eposta,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('kayit_sifre'),
                controller: _sifre,
                obscureText: _sifreGizli,
                decoration: InputDecoration(
                  labelText: 'Şifre (en az 8 karakter)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _sifreGizli ? 'Şifreyi göster' : 'Şifreyi gizle',
                    icon: Icon(_sifreGizli ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _sifreGizli = !_sifreGizli),
                  ),
                ),
                validator: Dogrulama.sifre,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('kayit_sifre_tekrar'),
                controller: _sifreTekrar,
                obscureText: _sifreGizli,
                decoration: const InputDecoration(labelText: 'Şifre (tekrar)', border: OutlineInputBorder()),
                validator: (v) => v == _sifre.text ? null : 'Şifreler aynı değil',
                onFieldSubmitted: (_) => _gonder(),
              ),
            ],
          ),
        ),
        if (_hata != null) ...[
          const SizedBox(height: 12),
          Text(_hata!, key: const Key('kayit_hata'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('kayit_buton'),
          onPressed: _bekliyor ? null : _gonder,
          child: _bekliyor
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kayıt ol'),
        ),
        TextButton(onPressed: () => context.go('/giris'), child: const Text('Zaten hesabın var mı? Giriş yap')),
      ],
    );
  }
}
