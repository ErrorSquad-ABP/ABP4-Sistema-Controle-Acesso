import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/session_controller.dart';

/// Tela inicial, acessada após o login (US-27). As autorizações do usuário
/// entram na US-28 e o acesso por leitura de QR na US-29.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(sessionControllerProvider).value?.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
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
              Text(
                user == null ? 'Controle de acesso' : 'Olá, ${user.firstName}',
                style: textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                user == null
                    ? 'Acesso simples. Segurança em cada detalhe.'
                    : '${user.role.label} · ${user.email}',
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
