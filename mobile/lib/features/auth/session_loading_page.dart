import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Abertura do app enquanto a sessão salva é restaurada e conferida.
class SessionLoadingPage extends StatelessWidget {
  const SessionLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user_outlined, size: AppSpacing.lg),
              const SizedBox(height: AppSpacing.md),
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text('Verificando sua sessão…', style: text.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
