import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/feedback_banner.dart';
import 'auth_contract.dart';
import 'session_controller.dart';

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
  (FeedbackTone, String)? _message;

  @override
  void initState() {
    super.initState();
    // Sessão encerrada sem o usuário pedir: explica o motivo e já traz o
    // e-mail preenchido.
    final ended = ref.read(sessionControllerProvider).value?.ended;
    if (ended != null) _applyEnded(ended);
    // O cofre pode recusar a exclusão depois de a tela já estar aberta.
    ref.listenManual(sessionControllerProvider, (_, next) {
      final late = next.value?.ended;
      if (late == null || !mounted) return;
      setState(() => _applyEnded(late));
    });
  }

  void _applyEnded(SessionEnd ended) {
    _email.text = ended.email;
    _message = _endedMessage(ended);
  }

  static (FeedbackTone, String) _endedMessage(SessionEnd ended) => (
    ended.reason == SessionEndReason.notErased
        ? FeedbackTone.error
        : FeedbackTone.warning,
    switch (ended.reason) {
      SessionEndReason.expired => 'Sua sessão expirou. Entre novamente.',
      SessionEndReason.revoked => 'Sua sessão foi encerrada. Entre novamente.',
      SessionEndReason.notErased =>
        'Sua sessão foi encerrada, mas o aparelho não confirmou a exclusão. '
            'Se o app abrir conectado, saia novamente.',
    },
  );

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _message = null);
    ref.read(sessionControllerProvider.notifier).dismissNotice();
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      // Sucesso muda a sessão e o redirect do router leva à Home.
      await ref
          .read(sessionControllerProvider.notifier)
          .login(LoginRequest(email: _email.text, password: _password.text));
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = _failureMessage(failure.reason));
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = _failureMessage(AuthFailureReason.unexpected));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static (FeedbackTone, String) _failureMessage(AuthFailureReason reason) =>
      switch (reason) {
        AuthFailureReason.unauthorized => (
          FeedbackTone.error,
          'E-mail ou senha incorretos. Se o problema continuar, procure a '
              'administração.',
        ),
        AuthFailureReason.invalidRequest => (
          FeedbackTone.error,
          'Confira o e-mail e a senha informados.',
        ),
        AuthFailureReason.tooManyRequests => (
          FeedbackTone.warning,
          'Muitas tentativas seguidas. Aguarde alguns minutos e tente '
              'novamente.',
        ),
        AuthFailureReason.unavailable => (
          FeedbackTone.warning,
          'O serviço de acesso está fora do ar. Tente novamente em instantes.',
        ),
        AuthFailureReason.network => (
          FeedbackTone.warning,
          'Sem conexão com o servidor. Verifique sua internet e tente '
              'novamente.',
        ),
        AuthFailureReason.unexpected => (
          FeedbackTone.error,
          'Não foi possível entrar. Tente novamente.',
        ),
      };

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
                              // O rótulo visível do Figma fica fora do campo;
                              // o leitor de tela o recebe pelo Semantics.
                              ExcludeSemantics(
                                child: Text('E-MAIL', style: text.labelSmall),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Semantics(
                                label: 'E-mail',
                                child: TextFormField(
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
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ExcludeSemantics(
                                child: Text('SENHA', style: text.labelSmall),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Semantics(
                                label: 'Senha',
                                child: TextFormField(
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
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (_message != null) ...[
                                FeedbackBanner(
                                  tone: _message!.$1,
                                  message: _message!.$2,
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
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'ERRORSQUAD · FATEC',
                        style: text.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
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
