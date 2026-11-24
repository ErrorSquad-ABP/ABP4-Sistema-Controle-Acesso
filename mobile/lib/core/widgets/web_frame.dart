import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Moldura da demo web (US-38): o app foi desenhado para celular, então no
/// navegador largo o conteúdo fica centralizado com largura de aparelho.
///
/// O [MediaQuery] repassado já traz a largura limitada, para as telas que se
/// medem pela largura se comportarem como no celular. Fora da web, devolve
/// [child] sem mudança.
class WebFrame extends StatelessWidget {
  const WebFrame({required this.child, this.isWeb = kIsWeb, super.key});

  static const maxWidth = 480.0;

  final Widget child;

  /// Plataforma atual; parâmetro para os testes, que rodam fora do navegador.
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    if (!isWeb) return child;
    final media = MediaQuery.of(context);
    final width = math.min(media.size.width, maxWidth);
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
