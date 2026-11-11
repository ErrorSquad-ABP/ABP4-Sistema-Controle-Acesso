import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/auth_contract.dart';

/// Rótulo micro em caixa alta acima dos campos, como no design system.
class AdminSectionLabel extends StatelessWidget {
  const AdminSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(fontWeight: FontWeight.w600, height: 1.4),
    );
  }
}

/// Campo de texto com rótulo sempre visível: o idoso não depende do
/// placeholder para saber o que o campo pede.
class AdminFormField extends StatelessWidget {
  const AdminFormField({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.validator,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
    super.key,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          label: label,
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            validator: validator,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            minLines: minLines,
            maxLines: maxLines,
            style: text.bodyLarge?.copyWith(height: 1.35),
            decoration: InputDecoration(hintText: hint, suffixIcon: suffixIcon),
          ),
        ),
      ],
    );
  }
}

/// Ação primária pill do design system: texto à esquerda e ícone no círculo
/// à direita. Cresce com a fonte do sistema em vez de cortar o rótulo.
class AdminPrimaryAction extends StatelessWidget {
  const AdminPrimaryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      container: true,
      enabled: !busy,
      liveRegion: busy,
      label: busy ? '$label, salvando' : label,
      excludeSemantics: true,
      child: Material(
        color: palette.text,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.controlHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      busy ? '$label…' : label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge?.copyWith(
                        color: palette.background,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.background,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: busy
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.text,
                              ),
                            )
                          : Icon(icon, size: 20, color: palette.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ação destrutiva no tom suave de erro: texto escuro sobre `errorSoft` passa
/// AA nos dois temas, sem depender da cor de erro como texto.
class AdminDestructiveAction extends StatelessWidget {
  const AdminDestructiveAction({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      container: true,
      enabled: !busy,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: palette.errorSoft,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.controlHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge?.copyWith(
                        color: palette.onSoft,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: palette.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Perfil da conta em linhas de 56 dp: alvo de toque grande e uma frase
/// explicando o que cada perfil pode fazer.
class AdminRoleSelector extends StatelessWidget {
  const AdminRoleSelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final UserRole selected;
  final ValueChanged<UserRole> onSelected;

  static String descriptionOf(UserRole role) => switch (role) {
    UserRole.admin => 'Gerencia pessoas, locais e acessos.',
    UserRole.resident => 'Mora no condomínio e recebe autorizações.',
    UserRole.visitor => 'Acesso temporário liberado por um morador.',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, role) in UserRole.values.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xs),
          _RoleOption(
            role: role,
            selected: role == selected,
            onTap: () => onSelected(role),
          ),
        ],
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final description = AdminRoleSelector.descriptionOf(role);

    return Semantics(
      button: true,
      container: true,
      selected: selected,
      label: '${role.label}. $description',
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(
            color: selected ? palette.text : palette.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.label,
                          style: text.bodyLarge?.copyWith(
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: text.bodySmall?.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 24,
                    color: selected ? palette.text : palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
