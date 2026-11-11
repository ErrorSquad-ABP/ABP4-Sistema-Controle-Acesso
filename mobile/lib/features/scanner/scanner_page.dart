import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback_banner.dart';
import 'access_result_view.dart';
import 'scanner_controller.dart';
import 'scanner_gateways.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  /// Tema da leitura: o Figma desenha a câmera sobre o fundo escuro nos dois
  /// temas, então a tela usa os tokens escuros do design system.
  static final ThemeData _theme = AppTheme.dark();

  /// Não exibe resultado antes de iniciar a tentativa da página atual.
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Reinicia o estado de forma síncrona e só então libera a tela.
      ref.read(scannerControllerProvider.notifier).requestPermission();
      setState(() => _started = true);
    });
  }

  void _leave() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(scannerControllerProvider);
    final ScannerState state = _started
        ? current
        : const ScannerRequestingPermission();

    // Resultado em tela cheia (Figma), sem a barra de título do scanner.
    if (state case ScannerAccessResult(:final result)) {
      return Scaffold(
        body: AccessResultView(
          result: result,
          onDone: () => context.go(AppRoutes.home),
          onScanAgain: ref.read(scannerControllerProvider.notifier).retry,
        ),
      );
    }

    return Theme(
      data: _theme,
      child: Builder(
        builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
          // Fundo escuro fixo: os ícones do sistema precisam ser claros.
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            body: SafeArea(
              // Com a fonte do sistema ampliada (RNF04) a tela rola; o espaço
              // extra do frame de 844 dp fica entre as três seções.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const padding = EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.xs,
                    AppSpacing.screen,
                    40,
                  );
                  return SingleChildScrollView(
                    padding: padding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - padding.vertical)
                            .clamp(0, double.infinity),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Instructions(onBack: _leave),
                          _ReadingArea(state),
                          _Support(state, onCancel: _leave),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Instructions extends StatelessWidget {
  const _Instructions({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: SizedBox(
              // Alvo de toque de 48 dp; o frame usa 40 dp de altura.
              height: AppSpacing.xl,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 20, color: palette.text),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Voltar',
                    style: text.bodySmall?.copyWith(color: palette.text),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Escanear QR Code',
          style: text.displaySmall?.copyWith(
            height: 1.35,
            letterSpacing: -0.96,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Aponte a câmera para o QR Code exibido no terminal',
          style: text.bodyMedium?.copyWith(height: 1.35),
        ),
      ],
    );
  }
}

class _ReadingArea extends ConsumerWidget {
  const _ReadingArea(this.state);

  final ScannerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final controller = ref.read(scannerControllerProvider.notifier);
    // A câmera segue aberta enquanto a posição e o pedido andam; o controller
    // ignora novas leituras fora do estado `Scanning`.
    final scanning =
        state is ScannerScanning ||
        state is ScannerLocating ||
        state is ScannerSending;

    return SizedBox(
      height: 280,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(280.0, constraints.maxWidth);
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: scanning
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        child: ref
                            .watch(qrScannerGatewayProvider)
                            .preview(
                              onDetected: controller.onQrDetected,
                              onError: controller.onCameraError,
                            ),
                      )
                    : Center(
                        child: Icon(
                          Icons.qr_code_scanner,
                          size: AppSpacing.xl,
                          color: palette.textSecondary,
                        ),
                      ),
              ),
              // Cantos do enquadramento do Figma, sobre a câmera.
              IgnorePointer(
                child: CustomPaint(
                  size: Size.square(side),
                  painter: _FramePainter(color: palette.text),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Support extends ConsumerWidget {
  const _Support(this.state, {required this.onCancel});

  final ScannerState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(scannerControllerProvider.notifier);

    return switch (state) {
      ScannerRequestingPermission() => _SupportBody(
        card: const _StatusCard.busy(
          label: 'Solicitando permissão de localização…',
        ),
        action: _GhostAction(label: 'Cancelar', onPressed: onCancel),
      ),
      ScannerScanning() => _SupportBody(
        card: const _StatusCard.proximity(),
        action: _GhostAction(label: 'Cancelar', onPressed: onCancel),
      ),
      ScannerLocating() => _SupportBody(
        card: const _StatusCard.busy(label: 'Lendo posição…'),
        action: _GhostAction(label: 'Cancelar', onPressed: onCancel),
      ),
      ScannerSending() => _SupportBody(
        card: const _StatusCard.busy(label: 'Verificando seu acesso…'),
        action: _GhostAction(label: 'Cancelar', onPressed: onCancel),
      ),
      ScannerPermissionDenied(:final message) => _ErrorSupport(
        message: message,
        action: 'Permitir novamente',
        onAction: controller.retry,
      ),
      ScannerFailure(:final message) => _ErrorSupport(
        message: message,
        action: 'Tentar novamente',
        onAction: controller.retry,
      ),
      ScannerSendFailed(:final message, :final retryable) => _ErrorSupport(
        message: message,
        action: retryable ? 'Tentar novamente' : 'Escanear de novo',
        onAction: retryable ? controller.retrySend : controller.retry,
      ),
      // O resultado ocupa a tela inteira e é tratado no `build`.
      ScannerAccessResult() => const SizedBox.shrink(),
    };
  }
}

/// Card de apoio no rodapé com a ação única do estado (Figma: "Apoio e
/// cancelamento").
class _SupportBody extends StatelessWidget {
  const _SupportBody({required this.card, required this.action});

  final Widget card;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        const SizedBox(height: AppSpacing.md),
        action,
      ],
    );
  }
}

class _ErrorSupport extends StatelessWidget {
  const _ErrorSupport({
    required this.message,
    required this.action,
    required this.onAction,
  });

  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _SupportBody(
      card: FeedbackBanner(tone: FeedbackTone.error, message: message),
      action: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.controlHeight),
        child: FilledButton(onPressed: onAction, child: Text(action)),
      ),
    );
  }
}

/// Card de apoio: proximidade exigida ou etapa em andamento.
class _StatusCard extends StatelessWidget {
  const _StatusCard.proximity()
    : label = 'Sua localização deve estar a até 100 m do terminal',
      icon = Icons.location_on_outlined,
      busy = false;

  const _StatusCard.busy({required this.label}) : icon = null, busy = true;

  final String label;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      liveRegion: busy,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (busy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 20, color: palette.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: text.bodySmall?.copyWith(height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ação secundária do rodapé, sem preenchimento (Figma: "Cancelar").
class _GhostAction extends StatelessWidget {
  const _GhostAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.controlHeight),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: palette.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          textStyle: text.labelLarge,
        ),
        child: Text(label),
      ),
    );
  }
}

/// Cantos do enquadramento (Figma: 280 × 280, traço de 3 dp).
class _FramePainter extends CustomPainter {
  const _FramePainter({required this.color});

  final Color color;

  static const double _arm = 44;
  static const double _radius = 12;
  static const double _stroke = 3;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = _stroke / 2;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Superior esquerdo.
    path
      ..moveTo(inset, inset + _arm)
      ..lineTo(inset, inset + _radius)
      ..quadraticBezierTo(inset, inset, inset + _radius, inset)
      ..lineTo(inset + _arm, inset);
    // Superior direito.
    path
      ..moveTo(right - _arm, inset)
      ..lineTo(right - _radius, inset)
      ..quadraticBezierTo(right, inset, right, inset + _radius)
      ..lineTo(right, inset + _arm);
    // Inferior direito.
    path
      ..moveTo(right, bottom - _arm)
      ..lineTo(right, bottom - _radius)
      ..quadraticBezierTo(right, bottom, right - _radius, bottom)
      ..lineTo(right - _arm, bottom);
    // Inferior esquerdo.
    path
      ..moveTo(inset + _arm, bottom)
      ..lineTo(inset + _radius, bottom)
      ..quadraticBezierTo(inset, bottom, inset, bottom - _radius)
      ..lineTo(inset, bottom - _arm);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => oldDelegate.color != color;
}
