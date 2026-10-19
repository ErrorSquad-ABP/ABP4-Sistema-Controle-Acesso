import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Tela inicial provisoria do esqueleto. Sera substituida pelo fluxo de
/// login (US-10) e pelas autorizacoes do usuario (US-28).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, size: AppSpacing.lg),
              const SizedBox(height: AppSpacing.md),
              Text('CONTROLE DE ACESSO', style: textTheme.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              Text('Controle de acesso', style: textTheme.displaySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Acesso simples. Segurança em cada detalhe.',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
