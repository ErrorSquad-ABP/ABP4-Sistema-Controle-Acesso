import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Abertura do app enquanto a sessão salva é restaurada e conferida
/// (estado "carregando" do Figma: indicador + texto).
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
