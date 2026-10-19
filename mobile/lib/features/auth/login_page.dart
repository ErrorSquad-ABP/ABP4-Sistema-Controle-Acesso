import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'login_contract.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _message = null);
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref
          .read(loginGatewayProvider)
          .login(LoginRequest(email: _email.text, password: _password.text));
    } on LoginUnavailable {
      if (!mounted) return;
      setState(() {
        _message =
            'O login ainda não está disponível. Tente novamente após '
            'a liberação do serviço de autenticação.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Não foi possível entrar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - AppSpacing.xl).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      const Icon(
                        Icons.verified_user_outlined,
                        size: AppSpacing.lg,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'CONTROLE DE ACESSO',
                        style: text.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('ACESSO CORPORATIVO', style: text.labelSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Bem-vindo de volta', style: text.displaySmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Entre para ver suas liberações',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AutofillGroup(
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('E-MAIL', style: text.labelSmall),
                              const SizedBox(height: AppSpacing.xs),
                              TextFormField(
                                controller: _email,
                                enabled: !_loading,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                autocorrect: false,
                                validator: LoginValidation.email,
                                decoration: const InputDecoration(
                                  hintText: 'maria.souza@exemplo.com',
                                  prefixIcon: Icon(Icons.mail_outline),
                                  semanticCounterText: 'E-mail',
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text('SENHA', style: text.labelSmall),
                              const SizedBox(height: AppSpacing.xs),
                              TextFormField(
                                controller: _password,
                                enabled: !_loading,
                                obscureText: _obscure,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                validator: LoginValidation.password,
                                decoration: InputDecoration(
                                  hintText: 'Sua senha',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure
                                        ? 'Mostrar senha'
                                        : 'Ocultar senha',
                                    onPressed: _loading
                                        ? null
                                        : () => setState(
                                            () => _obscure = !_obscure,
                                          ),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (_message != null) ...[
                                Semantics(
                                  liveRegion: true,
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.palette.warningSoft,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.control,
                                      ),
                                    ),
                                    child: Text(
                                      _message!,
                                      style: text.bodySmall?.copyWith(
                                        color: context.palette.onSoft,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _loading ? 'Entrando…' : 'Entrar',
                                      ),
                                    ),
                                    if (_loading)
                                      const SizedBox.square(
                                        dimension: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.onPrimary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward,
                                          size: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => showDialog<void>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Recuperar acesso'),
                                          content: const Text(
                                            'Entre em contato com a administração para recuperar seu acesso.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: const Text('Entendi'),
                                            ),
                                          ],
                                        ),
                                      ),
                                child: const Text('Esqueci minha senha'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
