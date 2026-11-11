import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'state_card.dart';

/// Abertura do app enquanto a sessao salva e restaurada e conferida: o cartao
/// "Estado carregando" do Figma, centralizado.
class SessionLoadingPage extends StatelessWidget {
  const SessionLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Semantics(
                liveRegion: true,
                child: const StateCard.loading(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
