import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'feedback_banner.dart';

/// Limitações do navegador, declaradas na própria demo web (US-38).
///
/// Só aparece no build web; no Android não ocupa espaço.
class WebDemoNotice extends StatelessWidget {
  const WebDemoNotice({this.isWeb = kIsWeb, super.key});

  /// Plataforma atual; parâmetro para os testes, que rodam fora do navegador.
  final bool isWeb;

  static const message =
      'Versão de demonstração no navegador. A leitura de NFC só existe no '
      'terminal de acesso. Câmera e localização pedem sua permissão e só '
      'funcionam em endereço seguro (https).';

  @override
  Widget build(BuildContext context) {
    if (!isWeb) return const SizedBox.shrink();
    return const FeedbackBanner(tone: FeedbackTone.warning, message: message);
  }
}
