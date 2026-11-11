import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/clock.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'access_contract.dart';
import 'access_messages.dart';

/// Resultado do pedido de acesso em tela cheia (Figma: "Acesso liberado" e
/// "Acesso negado"). Rola quando a fonte do sistema está ampliada (RNF04).
class AccessResultView extends ConsumerWidget {
  const AccessResultView({
    required this.result,
    required this.onDone,
    required this.onScanAgain,
    super.key,
  });

  final AccessResult result;

  /// "Concluir" (liberado) e "Voltar ao início" (negado).
  final VoidCallback onDone;

  /// "Escanear de novo" (negado).
  final VoidCallback onScanAgain;

  bool get _granted => result.decision == AccessDecision.granted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final reason = result.reason ?? DenialReason.unknown;
    final tone = _granted ? palette.success : palette.error;
    final soft = _granted ? palette.successSoft : palette.errorSoft;
    final title = _granted ? 'Acesso liberado' : 'Acesso negado';
    final subtitle = _granted
        ? 'Tudo certo. Sua entrada foi autorizada.'
        : reason.summary;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // O frame posiciona o bloco a 136 dp do topo e a ação no rodapé.
            final top = (constraints.maxHeight * 0.16).clamp(48.0, 136.0);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                top,
                AppSpacing.screen,
                40,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - top - 40).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Anunciado por leitores de tela assim que aparece.
                        Semantics(
                          container: true,
                          liveRegion: true,
                          label: '$title. $subtitle',
                          excludeSemantics: true,
                          child: Column(
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: soft,
                                  border: Border.all(
                                    color: tone.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  _granted
                                      ? Icons.check_rounded
                                      : Icons.close_rounded,
                                  size: 48,
                                  color: tone,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: text.displaySmall?.copyWith(
                                  height: 1.35,
                                  letterSpacing: -0.96,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                style: text.bodyMedium?.copyWith(height: 1.35),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        if (_granted)
                          _GrantedCard(
                            locationName: result.locationName,
                            occurredAt: result.occurredAt,
                          )
                        else
                          _GuidanceCard(message: reason.guidance),
                        const SizedBox(height: 40),
                      ],
                    ),
                    if (_granted)
                      _PrimaryAction(onPressed: onDone)
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppSpacing.controlHeight,
                            ),
                            child: OutlinedButton(
                              onPressed: onScanAgain,
                              child: const Text('Escanear de novo'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextButton(
                            onPressed: onDone,
                            child: const Text('Voltar ao início'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Ação primária do Figma: pílula com o rótulo à esquerda e o ícone em um
/// círculo invertido à direita.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    // Com a fonte muito ampliada o rótulo não cabe ao lado do ícone; o ícone
    // é decorativo e sai de cena para o texto continuar legível.
    final showIcon = MediaQuery.textScalerOf(context).scale(16) <= 24;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.controlHeight),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.xs,
          ),
          minimumSize: const Size(64, AppSpacing.controlHeight),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Concluir',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge?.copyWith(color: palette.background),
              ),
            ),
            if (showIcon) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.background,
                ),
                child: Icon(Icons.check, size: 20, color: palette.text),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Registro do acesso liberado (Figma: "Registro de acesso").
class _GrantedCard extends ConsumerWidget {
  const _GrantedCard({required this.locationName, required this.occurredAt});

  final String? locationName;
  final DateTime occurredAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final local = occurredAt.toLocal();
    final now = ref.watch(clockProvider)().toLocal();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final time = DateFormat('HH:mm').format(local);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (locationName != null) ...[
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(
                    Icons.apartment_outlined,
                    size: 24,
                    color: palette.text,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    locationName!,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: palette.hairline),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  sameDay
                      ? 'Entrada hoje'
                      : 'Entrada em ${DateFormat('dd/MM/yyyy').format(local)}',
                  style: text.bodySmall?.copyWith(height: 1.35),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                time,
                style: text.bodySmall?.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Orientação do acesso negado (Figma: "Orientação").
class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 24, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: text.bodySmall?.copyWith(height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.hairline),
      ),
      child: child,
    );
  }
}
