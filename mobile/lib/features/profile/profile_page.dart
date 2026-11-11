import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/feedback_banner.dart';
import '../auth/auth_contract.dart';
import '../auth/session_controller.dart';
import 'profile_controller.dart';
import 'profile_name_dialog.dart';
import 'theme_selector.dart';

/// Aba Perfil (frames "Claro/Perfil e configurações" 77:2 e "Escuro/…" 10:14213).
///
/// Cabeçalho, cartão da pessoa, seletor de tema e atalhos de conta. O botão de
/// editar o nome não está no frame: é a saída para o `PATCH /me`.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  (FeedbackTone, String)? _notice;

  void _showNotice((FeedbackTone, String) notice) {
    if (!mounted) return;
    setState(() => _notice = notice);
  }

  Future<void> _refresh() async {
    setState(() => _notice = null);
    try {
      await ref.read(profileUserProvider.notifier).refresh();
    } on AuthFailure catch (failure) {
      // 401 já encerra a sessão: o redirect do router leva ao login.
      if (failure.reason == AuthFailureReason.unauthorized) return;
      _showNotice(_refreshFailure);
    } catch (_) {
      _showNotice(_refreshFailure);
    }
  }

  static const (FeedbackTone, String) _refreshFailure = (
    FeedbackTone.warning,
    'Não foi possível atualizar seus dados. Tente novamente.',
  );

  Future<void> _editName(AuthUser user) async {
    setState(() => _notice = null);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => ProfileNameDialog(initialName: user.name),
    );
    if (saved ?? false) {
      _showNotice((FeedbackTone.success, 'Nome atualizado.'));
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você vai precisar do e-mail e da senha para entrar de novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    // O redirect do router leva ao login quando a sessão é encerrada.
    if (confirmed ?? false) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileUserProvider);
    final palette = context.palette;

    // Sem usuário: sessão sendo restaurada ou já encerrada (o router assume).
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    final notice = _notice;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: palette.text,
          backgroundColor: palette.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              AppSpacing.md,
            ),
            children: [
              _Header(initials: _initials(user.name)),
              const SizedBox(height: AppSpacing.lg),
              _PersonCard(user: user),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: TextButton.icon(
                  onPressed: () => _editName(user),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar nome'),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.text,
                    minimumSize: const Size(0, AppSpacing.xl),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    textStyle: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (notice case (final tone, final message)) ...[
                const SizedBox(height: AppSpacing.xs),
                FeedbackBanner(tone: tone, message: message),
              ],
              const SizedBox(height: AppSpacing.lg),
              const _AppearanceSection(),
              const SizedBox(height: AppSpacing.lg),
              _Settings(
                onLogout: _confirmLogout,
                isAdmin: user.role == UserRole.admin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primeira e última inicial do nome, como no avatar do frame.
String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  final first = parts.first.substring(0, 1);
  final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
  return '$first$last'.toUpperCase();
}

class _Header extends StatelessWidget {
  const _Header({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUA CONTA',
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Meu perfil',
                style: text.displaySmall?.copyWith(
                  height: 1.35,
                  letterSpacing: -0.96,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _InitialsAvatar(
          initials: initials,
          size: 40,
          color: context.palette.background,
          border: Border.all(color: context.palette.hairline),
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    // No escuro o avatar usa a hairline; no claro, o fundo da tela.
    final avatarColor = Theme.of(context).brightness == Brightness.dark
        ? palette.hairline
        : palette.background;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        children: [
          _InitialsAvatar(
            initials: _initials(user.name),
            size: 64,
            color: avatarColor,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${user.name} · ${user.role.label}',
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(height: 1.35),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.initials,
    required this.size,
    required this.color,
    this.border,
  });

  final String initials;
  final double size;
  final Color color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isLarge = size > 48;

    // As iniciais repetem o nome que já está na tela: só decoração.
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: border,
        ),
        child: Text(
          initials,
          style: isLarge
              ? text.headlineSmall?.copyWith(height: 1.35, letterSpacing: -0.72)
              : text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
        ),
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'APARÊNCIA',
          style: text.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Seu app, no seu ritmo.',
          style: text.titleLarge?.copyWith(height: 1.35),
        ),
        const SizedBox(height: AppSpacing.sm),
        const ThemeSelector(),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${isDark ? 'Escuro' : 'Claro'} selecionado. Você pode alterar o '
          'tema a qualquer momento.',
          style: text.bodySmall?.copyWith(height: 1.35),
        ),
      ],
    );
  }
}

class _Settings extends StatelessWidget {
  const _Settings({required this.onLogout, required this.isAdmin});

  final VoidCallback onLogout;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Notificações e privacidade ainda não têm tela: o atalho fica sem ação.
        const _SettingsRow(
          icon: Icons.notifications_none,
          label: 'Notificações',
        ),
        // A API de locais é de administração (POST exige ADMIN); a lista também
        // só faz sentido para quem gerencia a unidade.
        if (isAdmin)
          _SettingsRow(
            icon: Icons.assignment_outlined,
            label: 'Autorizações',
            onTap: () => context.push(AppRoutes.adminAuthorizations),
          ),
        if (isAdmin)
          _SettingsRow(
            icon: Icons.people_outline,
            label: 'Usuários e histórico',
            onTap: () => context.push(AppRoutes.adminUsers),
          ),
        if (isAdmin)
          _SettingsRow(
            icon: Icons.place_outlined,
            label: 'Locais de acesso',
            onTap: () => context.push(AppRoutes.locations),
          ),
        const _SettingsRow(
          icon: Icons.shield_outlined,
          label: 'Privacidade e segurança',
        ),
        _SettingsRow(
          icon: Icons.logout,
          label: 'Sair da conta',
          onTap: onLogout,
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final onTap = this.onTap;

    final row = ConstrainedBox(
      // 56 do frame; cresce com a fonte do sistema em vez de estourar.
      constraints: const BoxConstraints(minHeight: AppSpacing.controlHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.text),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: text.bodyLarge?.copyWith(height: 1.35)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, size: 16, color: palette.textSecondary),
          ],
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: onTap == null
          ? row
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: row),
            ),
    );
  }
}
