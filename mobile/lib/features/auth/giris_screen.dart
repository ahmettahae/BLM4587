import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _sifreOdak = FocusNode();
  bool _sifreGizli = true;
  bool _bekliyor = false;
  bool _beniHatirla = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _tercihleriYukle();
  }

  /// Son seçilen "beni hatırla" tercihi ve hatırlanan e-posta forma gelir.
  Future<void> _tercihleriYukle() async {
    final depo = ref.read(tokenStoreProvider);
    final tercih = await depo.beniHatirlaTercihi();
    final eposta = await depo.hatirlananEposta();
    if (!mounted) return;
    setState(() {
      _beniHatirla = tercih;
      if (eposta != null && _email.text.isEmpty) _email.text = eposta;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _sifre.dispose();
    _sifreOdak.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).girisYap(_email.text, _sifre.text, beniHatirla: _beniHatirla);
      // Parola yöneticisine "bu bilgileri kaydet" fırsatı ver.
      TextInput.finishAutofillContext();
      // Başarılıysa yönlendirme (router) otomatik ana sayfaya götürür.
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bilgi = ref.watch(authControllerProvider.select((s) => s.bilgi));
    final renkler = Theme.of(context).colorScheme;
    return AuthFormKabugu(
      baslik: 'Giriş yap',
      children: [
        if (bilgi != null && _hata == null) ...[
          Card(
            key: const Key('giris_bilgi'),
            color: renkler.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(bilgi),
            ),
          ),
          const SizedBox(height: 12),
        ],
        AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  key: const Key('giris_email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: Icon(Icons.alternate_email),
                    border: OutlineInputBorder(),
                  ),
                  validator: Dogrulama.eposta,
                  onFieldSubmitted: (_) => _sifreOdak.requestFocus(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('giris_sifre'),
                  controller: _sifre,
                  focusNode: _sifreOdak,
                  obscureText: _sifreGizli,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline),
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
        ),
        const SizedBox(height: 4),
        CheckboxListTile(
          key: const Key('beni_hatirla'),
          value: _beniHatirla,
          onChanged: _bekliyor ? null : (v) => setState(() => _beniHatirla = v ?? false),
          title: const Text('Beni hatırla'),
          subtitle: const Text('Bu cihazda 30 gün oturum açık kalsın'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_hata != null) ...[
          const SizedBox(height: 8),
          Text(_hata!, key: const Key('giris_hata'), style: TextStyle(color: renkler.error)),
        ],
        const SizedBox(height: 16),
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
