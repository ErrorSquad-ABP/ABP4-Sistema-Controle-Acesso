import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/feedback_banner.dart';
import '../auth/auth_contract.dart';
import '../auth/session_controller.dart';
import 'admin_form.dart';
import 'admin_state_view.dart';
import 'admin_users_contract.dart';
import 'admin_users_controller.dart';
import 'http_admin_users_gateway.dart';

/// Conta de uma pessoa: resumo, edição de nome/perfil/situação e exclusão.
///
/// O detalhe é a tela de edição: não existe um frame separado e o cartão da
/// lista já mostra tudo o que é leitura, então duplicar uma tela só de
/// consulta obrigaria a pessoa a um toque extra.
class AdminUserDetailPage extends ConsumerWidget {
  const AdminUserDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminUserDetailProvider(id));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.xs,
            AppSpacing.screen,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BackRow(onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(height: AppSpacing.sm),
              switch (detail) {
                AsyncData(:final value) => _EditForm(
                  key: ValueKey(value.id),
                  user: value,
                ),
                AsyncError(:final error) => _errorState(ref, error),
                _ => const AdminStateView.loading(title: 'Carregando a conta…'),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState(WidgetRef ref, Object error) {
    if (error is AdminUsersFailure) {
      switch (error.reason) {
        case AdminUsersFailureReason.notFound:
          return const AdminStateView.empty(
            icon: Icons.person_off_outlined,
            title: 'Conta não encontrada',
            message:
                'Esta conta não existe mais. Volte para a lista e atualize '
                'para ver as contas atuais.',
          );
        case AdminUsersFailureReason.forbidden:
          return const AdminStateView.empty(
            icon: Icons.lock_outline,
            title: 'Sem permissão',
            message:
                'Seu perfil não pode abrir esta conta. Peça a um '
                'administrador para ver os usuários.',
          );
        default:
          break;
      }
    }
    return AdminStateView.error(
      message: 'Não foi possível carregar a conta. Tente novamente.',
      onRetry: () => ref.invalidate(adminUserDetailProvider(id)),
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
      key: const Key('back-to-users'),
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

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.user, super.key});

  final AdminUser user;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late UserRole _role = widget.user.role;
  late bool _active = widget.user.active;

  /// Última versão devolvida pelo `PATCH`: o resumo do topo acompanha o que
  /// acabou de ser salvo sem precisar recarregar a conta.
  late AdminUser _user = widget.user;

  bool _saving = false;
  bool _deleting = false;
  (FeedbackTone, String)? _message;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _deleting) return;
    setState(() => _message = null);
    if (!_form.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(adminUsersGatewayProvider)
          .update(
            widget.user.id,
            UpdateAdminUserRequest(
              name: _name.text,
              role: _role,
              active: _active,
            ),
          );
      // A lista é a tela anterior: mantém em dia mesmo que a pessoa volte.
      await ref.read(adminUsersProvider.notifier).refresh();
      if (!mounted) return;
      setState(() {
        _user = updated;
        _message = (FeedbackTone.success, 'Alterações salvas.');
      });
    } on AdminUsersFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = _saveFailureMessage(failure.reason));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message = (
          FeedbackTone.error,
          'Não foi possível salvar as alterações. Tente novamente.',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Excluir esta conta?'),
        content: Text(
          'A conta de ${_user.name} fica inativa e não poderá entrar no '
          'app. O histórico de acessos é mantido. Você pode reativá-la depois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir conta'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;

    setState(() {
      _deleting = true;
      _message = null;
    });
    try {
      await ref.read(adminUsersGatewayProvider).delete(widget.user.id);
      await ref.read(adminUsersProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } on AdminUsersFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = _deleteFailureMessage(failure.reason));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message = (
          FeedbackTone.error,
          'Não foi possível excluir a conta. Tente novamente.',
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final user = _user;
    final isSelf = ref.watch(currentSessionProvider)?.user.id == user.id;
    final message = _message;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: palette.hairline),
            ),
            child: Column(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.hairline),
                    ),
                    child: Text(
                      user.initials,
                      style: text.headlineSmall?.copyWith(
                        height: 1.35,
                        letterSpacing: -0.72,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(height: 1.35),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(height: 1.35),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${user.role.label} · '
                  '${user.active ? 'conta ativa' : 'conta inativa'}',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const AdminSectionLabel('DADOS DA CONTA'),
          const SizedBox(height: AppSpacing.xs),
          AdminFormField(
            fieldKey: const Key('field-user-name'),
            label: 'Nome',
            hint: 'Nome completo',
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            validator: AdminUserValidation.name,
          ),
          const SizedBox(height: AppSpacing.md),
          const AdminSectionLabel('PERFIL DE ACESSO'),
          const SizedBox(height: AppSpacing.xs),
          AdminRoleSelector(
            selected: _role,
            onSelected: (role) => setState(() => _role = role),
          ),
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              side: BorderSide(color: palette.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              key: const Key('switch-active'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              title: Text(
                'Conta ativa',
                style: text.bodyLarge?.copyWith(
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Contas inativas não entram no app nem acessam o condomínio.',
                style: text.bodySmall?.copyWith(height: 1.35),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (message case (final tone, final notice)) ...[
            FeedbackBanner(tone: tone, message: notice),
            const SizedBox(height: AppSpacing.sm),
          ],
          AdminPrimaryAction(
            key: const Key('save-user-action'),
            label: 'Salvar alterações',
            icon: Icons.check,
            busy: _saving,
            onPressed: _save,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isSelf)
            const _SelfNote()
          else ...[
            const AdminSectionLabel('EXCLUIR CONTA'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'A conta fica inativa e não poderá entrar no app. '
              'O histórico de acessos é mantido.',
              style: text.bodySmall?.copyWith(height: 1.35),
            ),
            const SizedBox(height: AppSpacing.sm),
            AdminDestructiveAction(
              key: const Key('delete-user-action'),
              label: 'Excluir usuário',
              busy: _deleting,
              onPressed: _delete,
            ),
          ],
        ],
      ),
    );
  }
}

/// O próprio administrador não exclui a própria conta por aqui: sem outra
/// pessoa com acesso, o condomínio ficaria sem quem gerencia as contas.
class _SelfNote extends StatelessWidget {
  const _SelfNote();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.info_outline,
              size: 20,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Esta é a sua conta. Outro administrador pode excluí-la ou '
              'mudar o seu perfil.',
              style: text.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

(FeedbackTone, String) _saveFailureMessage(AdminUsersFailureReason reason) =>
    switch (reason) {
      AdminUsersFailureReason.unauthorized => (
        FeedbackTone.error,
        'Sua sessão expirou. Entre novamente.',
      ),
      AdminUsersFailureReason.forbidden => (
        FeedbackTone.error,
        'Só administradores podem alterar contas.',
      ),
      AdminUsersFailureReason.notFound => (
        FeedbackTone.warning,
        'Esta conta não existe mais. Volte para a lista.',
      ),
      AdminUsersFailureReason.conflict => (
        FeedbackTone.error,
        'Não foi possível salvar. O sistema precisa de pelo menos um '
            'administrador ativo: promova outra pessoa antes de mudar este '
            'perfil.',
      ),
      AdminUsersFailureReason.invalidRequest => (
        FeedbackTone.error,
        'Confira o nome e o perfil informados.',
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
        'Não foi possível salvar as alterações. Tente novamente.',
      ),
    };

(FeedbackTone, String) _deleteFailureMessage(AdminUsersFailureReason reason) =>
    switch (reason) {
      AdminUsersFailureReason.unauthorized => (
        FeedbackTone.error,
        'Sua sessão expirou. Entre novamente.',
      ),
      AdminUsersFailureReason.forbidden => (
        FeedbackTone.error,
        'Só administradores podem excluir contas.',
      ),
      AdminUsersFailureReason.notFound => (
        FeedbackTone.warning,
        'Esta conta não existe mais. Volte para a lista.',
      ),
      AdminUsersFailureReason.conflict => (
        FeedbackTone.error,
        'Não é possível excluir o último administrador ativo. Promova outra '
            'pessoa a administrador antes de excluir esta conta.',
      ),
      AdminUsersFailureReason.invalidRequest => (
        FeedbackTone.error,
        'O servidor recusou a exclusão. Tente novamente.',
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
        'Não foi possível excluir a conta. Tente novamente.',
      ),
    };
