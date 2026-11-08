import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/dogrulama.dart';
import 'auth_controller.dart';
import 'auth_form_kabugu.dart';

class GirisScreen extends ConsumerStatefulWidget {
  const GirisScreen({super.key});

  @override
  ConsumerState<GirisScreen> createState() => _GirisScreenState();
}

class _GirisScreenState extends ConsumerState<GirisScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _sifre = TextEditingController();
  bool _sifreGizli = true;
  bool _bekliyor = false;
  String? _hata;

  @override
  void dispose() {
    _email.dispose();
    _sifre.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).girisYap(_email.text, _sifre.text);
      // Başarılıysa yönlendirme (router) otomatik ana sayfaya götürür.
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormKabugu(
      baslik: 'Giriş yap',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                key: const Key('giris_email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder()),
                validator: Dogrulama.eposta,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('giris_sifre'),
                controller: _sifre,
                obscureText: _sifreGizli,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _sifreGizli ? 'Şifreyi göster' : 'Şifreyi gizle',
                    icon: Icon(_sifreGizli ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _sifreGizli = !_sifreGizli),
                  ),
                ),
                validator: Dogrulama.sifre,
                onFieldSubmitted: (_) => _gonder(),
              ),
            ],
          ),
        ),
        if (_hata != null) ...[
          const SizedBox(height: 12),
          Text(_hata!, key: const Key('giris_hata'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('giris_buton'),
          onPressed: _bekliyor ? null : _gonder,
          child: _bekliyor
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Giriş yap'),
        ),
        TextButton(onPressed: () => context.go('/kayit'), child: const Text('Hesabın yok mu? Kayıt ol')),
      ],
    );
  }
}
