import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../scanner/access_contract.dart' show AccessDecision;
import 'access_events_contract.dart';

/// Cartão de uma tentativa de acesso: decisão, método, pessoa, local, motivo
/// e horário. É leitura, não ação: o leitor de tela o anuncia como texto.
class AccessEventCard extends StatelessWidget {
  const AccessEventCard({super.key, required this.event, required this.now});

  final AdminAccessEvent event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final granted = event.decision == AccessDecision.granted;
    final reason = event.reason;

    return Semantics(
      container: true,
      label: event.accessibleLabel(now: now),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: palette.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: granted ? palette.successSoft : palette.errorSoft,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Center(
                    child: Icon(
                      granted ? Icons.check_circle : Icons.block,
                      size: 20,
                      color: granted ? palette.success : palette.error,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _Chip(
                            label: event.decisionLabel,
                            background: granted
                                ? palette.successSoft
                                : palette.errorSoft,
                            foreground: palette.onSoft,
                            dot: granted ? palette.success : palette.error,
                          ),
                          _Chip(
                            label: event.method.label,
                            background: palette.background,
                            foreground: palette.text,
                            border: palette.hairline,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        event.personLabel,
                        style: text.titleMedium?.copyWith(height: 1.35),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.locationLabel,
                        style: text.bodySmall?.copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Motivo: ${reason.label}',
                style: text.bodySmall?.copyWith(
                  height: 1.35,
                  color: palette.text,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              accessEventTimeLabel(occurredAt: event.occurredAt, now: now),
              style: text.bodySmall?.copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
    this.dot,
    this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? dot;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dot = this.dot;
    final border = this.border;

    return Container(
      // 12/8 do Figma: o horizontal não cai na grade de 8.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
