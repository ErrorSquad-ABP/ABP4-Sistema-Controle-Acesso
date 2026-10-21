import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';

/// Tela inicial do esqueleto, acessada após o login (US-10). As autorizações
/// do usuário entram na US-28 e o acesso por leitura de QR na US-29.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Início')),
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
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.scan),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear QR'),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Lê o QR e registra a posição. A liberação do acesso entra na '
                'US-29.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
