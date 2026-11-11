import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'authorization_contract.dart';
import 'authorization_format.dart';
import 'authorization_state_view.dart';
import 'authorization_status.dart';
import 'authorization_usage_bar.dart';
import 'authorizations_controller.dart';
import 'scan_action.dart';

/// Detalhe de uma autorização (frame "Detalhe da autorização").
class AuthorizationDetailPage extends ConsumerWidget {
  const AuthorizationDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(authorizationDetailProvider(id));
    final now = ref.watch(clockProvider)();

    void back() {
      if (context.canPop()) {
        context.pop();
      } else {
        // Link direto: não há pilha para voltar.
        context.go(AppRoutes.home);
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.xs,
                    AppSpacing.screen,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BackRow(onTap: back),
                      const SizedBox(height: AppSpacing.sm),
                      switch (detail) {
                        AsyncData(:final value) => _DetailContent(
                          authorization: value,
                          now: now,
                        ),
                        AsyncError(:final error) => _failureState(ref, error),
                        _ => const AuthorizationStateView.loadingDetail(),
                      },
                    ],
                  ),
                ),
              ),
              if (detail.hasValue)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screen,
                  ),
                  child: ScanAction(
                    label: 'Escanear agora',
                    onPressed: () => context.push(AppRoutes.scan),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _failureState(WidgetRef ref, Object error) {
    if (error is AuthorizationFailure &&
        error.reason == AuthorizationFailureReason.notFound) {
      return const AuthorizationStateView.notFound();
    }
    return AuthorizationStateView.error(
      onRetry: () => ref.invalidate(authorizationDetailProvider(id)),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              Icon(Icons.arrow_back, size: 20, color: palette.text),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Detalhe da autorização',
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

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.authorization, required this.now});

  final Authorization authorization;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final tone = authorizationStatusTone(palette, authorization.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final neutral = authorization.status == AuthorizationStatus.canceled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: neutral ? palette.hairline : tone.background,
                shape: BoxShape.circle,
                // O tema escuro contorna o círculo para destacá-lo do fundo.
                border: isDark && !neutral
                    ? Border.all(
                        color: tone.dot.withValues(alpha: 0.5),
                        width: 2,
                      )
                    : null,
              ),
              child: Center(
                child: Icon(
                  Icons.verified_user_outlined,
                  size: isDark ? 48 : 40,
                  color: tone.dot,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AuthorizationStatusChip(status: authorization.status),
            const SizedBox(height: AppSpacing.sm),
            Text(
              authorization.locationName,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(
                height: 1.35,
                letterSpacing: -0.72,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: palette.hairline),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.place_outlined,
                label: 'Local',
                child: _Value(authorization.locationName),
              ),
              const _InfoDivider(),
              _InfoRow(
                icon: Icons.schedule,
                label: 'Período',
                child: _Value(
                  authorizationWindowLabel(
                    startsAt: authorization.startsAt,
                    endsAt: authorization.endsAt,
                    now: now,
                  ),
                ),
              ),
              const _InfoDivider(),
              _InfoRow(
                icon: Icons.confirmation_number_outlined,
                label: 'Usos restantes',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthorizationUsageBar(
                      fraction: authorization.remainingFraction,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      remainingUsesLabel(
                        remaining: authorization.remainingUses,
                        max: authorization.maxUses,
                      ),
                      style: text.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
              const _InfoDivider(),
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Pessoa',
                child: _Value(authorization.person.display),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(icon, size: 24, color: palette.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall?.copyWith(height: 1.35)),
                const SizedBox(height: AppSpacing.xs),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(height: 1.35, fontWeight: FontWeight.w500),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: context.palette.hairline);
  }
}
