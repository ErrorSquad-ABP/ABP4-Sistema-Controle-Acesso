import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
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
        AuthFailureReason.timeout => (
          FeedbackTone.warning,
          'O servidor demorou para responder. Tente novamente em instantes.',
        ),
        AuthFailureReason.unexpected => (
          FeedbackTone.error,
          'Não foi possível entrar. Tente novamente.',
        ),
      };

  /// Campo do Figma: rotulo 11 acima, 8 de respiro e o campo de 56 com
  /// hairline, icone de 20 a 16 da borda e 12 ate o texto.
  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm, right: 12),
      child: Icon(icon, size: 20),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final palette = context.palette;
    // No claro o selo se funde ao fundo (#FAFAFA sobre #FAFAFA); no escuro e o
    // bloco claro com o icone escuro do frame.
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                // 64 acima e 40 abaixo como no frame; 24 nas laterais.
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  64,
                  AppSpacing.screen,
                  40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: dark ? palette.text : palette.background,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                            ),
                            child: Icon(
                              Icons.verified_user_outlined,
                              size: AppSpacing.lg,
                              color: dark ? palette.background : palette.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'CONTROLE DE ACESSO',
                          style: text.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('ACESSO CORPORATIVO', style: text.labelSmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Bem-vindo de volta', style: text.displaySmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Entre para ver suas liberações',
                          style: text.bodyMedium,
                        ),
                        const SizedBox(height: 40),
                        AutofillGroup(
                          child: Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // O rotulo visivel do Figma fica fora do
                                // campo; o leitor de tela o recebe pelo
                                // Semantics.
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
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    autocorrect: false,
                                    validator: LoginValidation.email,
                                    decoration: _decoration(
                                      hint: 'maria.souza@exemplo.com',
                                      icon: Icons.mail_outline,
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
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    validator: LoginValidation.password,
                                    decoration: _decoration(
                                      hint: 'Sua senha',
                                      icon: Icons.lock_outline,
                                      suffix: IconButton(
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
                                          size: 20,
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
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.only(
                                      left: AppSpacing.md,
                                      right: AppSpacing.xs,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _loading ? 'Entrando…' : 'Entrar',
                                        ),
                                      ),
                                      Container(
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.onPrimary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: _loading
                                            ? const SizedBox.square(
                                                dimension: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Icon(
                                                Icons.arrow_forward,
                                                size: 20,
                                                color:
                                                    theme.colorScheme.primary,
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
                                            title: const Text(
                                              'Recuperar acesso',
                                            ),
                                            content: const Text(
                                              'Entre em contato com a '
                                              'administração para recuperar '
                                              'seu acesso.',
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
                                  style: TextButton.styleFrom(
                                    foregroundColor: palette.text,
                                    minimumSize: const Size(0, AppSpacing.xl),
                                    textStyle: text.bodySmall,
                                  ),
                                  child: const Text('Esqueci minha senha'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'ERRORSQUAD · FATEC',
                      style: text.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
