import 'package:flutter/material.dart';
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

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - AppSpacing.screen * 2).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Anunciado por leitores de tela assim que o resultado aparece.
                Semantics(
                  container: true,
                  liveRegion: true,
                  label: '$title. $subtitle',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: soft,
                          border: Border.all(color: tone, width: 2),
                        ),
                        child: Icon(
                          _granted ? Icons.check_rounded : Icons.close_rounded,
                          size: 56,
                          color: tone,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: text.displaySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_granted)
                  _GrantedCard(
                    locationName: result.locationName,
                    occurredAt: result.occurredAt,
                  )
                else
                  _InfoCard(message: reason.guidance),
                const SizedBox(height: AppSpacing.xl),
                if (_granted)
                  FilledButton(onPressed: onDone, child: const Text('Concluir'))
                else ...[
                  FilledButton(
                    onPressed: onScanAgain,
                    child: const Text('Escanear de novo'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton(
                    onPressed: onDone,
                    child: const Text('Voltar ao início'),
                  ),
                ],
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.hairline),
      ),
      child: child,
    );
  }
}

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
                Icon(Icons.apartment_outlined, color: palette.text),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(locationName!, style: text.titleMedium)),
              ],
            ),
            Divider(height: AppSpacing.md * 2, color: palette.hairline),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  sameDay
                      ? 'Entrada hoje'
                      : 'Entrada em ${DateFormat('dd/MM/yyyy').format(local)}',
                  style: text.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
              Text(time, style: text.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: text.bodyMedium?.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
