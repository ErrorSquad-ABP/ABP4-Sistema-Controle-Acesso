import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/feedback_banner.dart';
import '../auth/auth_contract.dart';
import 'admin_form.dart';
import 'admin_users_contract.dart';
import 'http_admin_users_gateway.dart';

/// Formulário "Novo usuário": nome, e-mail, senha e perfil de acesso.
///
/// A API exige senha no cadastro (`POST /users`); ela entra uma única vez e a
/// pessoa pode trocá-la depois pelo próprio perfil.
class NewAdminUserPage extends ConsumerStatefulWidget {
  const NewAdminUserPage({super.key});

  @override
  ConsumerState<NewAdminUserPage> createState() => _NewAdminUserPageState();
}

class _NewAdminUserPageState extends ConsumerState<NewAdminUserPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  // Condômino é o perfil mais comum; administrador exige uma escolha explícita.
  UserRole _role = UserRole.resident;
  bool _showPassword = false;
  bool _saving = false;
  (FeedbackTone, String)? _message;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _message = null);
    if (!_form.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(adminUsersGatewayProvider)
          .create(
            CreateAdminUserRequest(
              name: _name.text,
              email: _email.text,
              password: _password.text,
              role: _role,
            ),
          );
      if (!mounted) return;
      // A lista recarrega quando o formulário devolve sucesso.
      Navigator.of(context).pop(true);
    } on AdminUsersFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = _failureMessage(failure.reason));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message = (
          FeedbackTone.error,
          'Não foi possível criar a conta. Tente novamente.',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static (FeedbackTone, String) _failureMessage(
    AdminUsersFailureReason reason,
  ) => switch (reason) {
    AdminUsersFailureReason.unauthorized => (
      FeedbackTone.error,
      'Sua sessão expirou. Entre novamente.',
    ),
    AdminUsersFailureReason.forbidden => (
      FeedbackTone.error,
      'Só administradores podem criar contas.',
    ),
    AdminUsersFailureReason.conflict => (
      FeedbackTone.error,
      'Já existe uma conta com este e-mail. Use outro e-mail.',
    ),
    AdminUsersFailureReason.invalidRequest => (
      FeedbackTone.error,
      'O servidor recusou os dados. Confira nome, e-mail, senha e perfil.',
    ),
    AdminUsersFailureReason.notFound => (
      FeedbackTone.error,
      'Não foi possível criar a conta. Tente novamente.',
    ),
    AdminUsersFailureReason.unavailable => (
      FeedbackTone.warning,
      'O serviço de usuários está fora do ar. Tente novamente em instantes.',
    ),
    AdminUsersFailureReason.network => (
      FeedbackTone.warning,
      'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
    ),
    AdminUsersFailureReason.timeout => (
      FeedbackTone.warning,
      'O servidor demorou para responder. Tente novamente em instantes.',
    ),
    AdminUsersFailureReason.unexpected => (
      FeedbackTone.error,
      'Não foi possível criar a conta. Tente novamente.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final message = _message;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.xs,
                    AppSpacing.screen,
                    AppSpacing.md,
                  ),
                  children: [
                    _BackRow(onTap: () => Navigator.of(context).maybePop()),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Novo usuário',
                      style: text.displaySmall?.copyWith(
                        height: 1.35,
                        letterSpacing: -0.96,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Crie a conta e escolha o perfil de acesso. A pessoa '
                      'entra no app com o e-mail e a senha informados aqui.',
                      style: text.bodySmall?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AdminSectionLabel('DADOS DA CONTA'),
                    const SizedBox(height: AppSpacing.xs),
                    AdminFormField(
                      fieldKey: const Key('field-new-user-name'),
                      label: 'Nome',
                      hint: 'Nome completo',
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: AdminUserValidation.name,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AdminFormField(
                      fieldKey: const Key('field-new-user-email'),
                      label: 'E-mail',
                      hint: 'nome@exemplo.com',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: AdminUserValidation.email,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AdminFormField(
                      fieldKey: const Key('field-new-user-password'),
                      label: 'Senha',
                      hint: 'Pelo menos 8 caracteres',
                      controller: _password,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      validator: AdminUserValidation.password,
                      suffixIcon: IconButton(
                        key: const Key('toggle-password-visibility'),
                        tooltip: _showPassword
                            ? 'Ocultar senha'
                            : 'Mostrar senha',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Pelo menos 8 caracteres. Combine letras e números.',
                      style: text.bodySmall?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AdminSectionLabel('PERFIL DE ACESSO'),
                    const SizedBox(height: AppSpacing.xs),
                    AdminRoleSelector(
                      selected: _role,
                      onSelected: (role) => setState(() => _role = role),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  0,
                  AppSpacing.screen,
                  40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (message case (final tone, final notice)) ...[
                      FeedbackBanner(tone: tone, message: notice),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    AdminPrimaryAction(
                      key: const Key('create-user-action'),
                      label: 'Criar usuário',
                      icon: Icons.person_add_alt_1,
                      busy: _saving,
                      onPressed: _submit,
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

class _BackRow extends StatelessWidget {
  const _BackRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return SizedBox(
      key: const Key('back-to-users-from-create'),
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onTap,
          child: Row(
            children: [
              Icon(Icons.arrow_back, size: 20, color: palette.text),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Usuários',
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    height: 1.35,
                    color: palette.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
