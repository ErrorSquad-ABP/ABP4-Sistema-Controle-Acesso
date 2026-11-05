import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
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
  /// O controller é global e guarda o último estado (um resultado, um erro).
  /// Até a página reiniciá-lo, no primeiro quadro, ela mostra "pedindo
  /// permissão" em vez do estado da leitura anterior.
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

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(scannerControllerProvider);
    final ScannerState state = _started
        ? current
        : const ScannerRequestingPermission();
    final text = Theme.of(context).textTheme;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR')),
      body: SafeArea(
        // Com a fonte do sistema ampliada (RNF04), o texto e o aviso não cabem
        // ao lado de uma câmera que ocupa a altura toda: a câmera ganha uma
        // altura proporcional e o restante da tela rola.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final previewHeight = (constraints.maxHeight * 0.5).clamp(
              220.0,
              480.0,
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Aponte a câmera para o QR exibido no terminal. Sua posição '
                    'é enviada para conferir que você está a até 100 m dele.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(height: previewHeight, child: _previewArea(state)),
                  const SizedBox(height: AppSpacing.sm),
                  _status(state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _previewArea(ScannerState state) {
    final palette = context.palette;
    final controller = ref.read(scannerControllerProvider.notifier);
    // A câmera segue aberta enquanto a posição e o pedido andam; o controller
    // ignora novas leituras fora do estado `Scanning`.
    final scanning =
        state is ScannerScanning ||
        state is ScannerLocating ||
        state is ScannerSending;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: ColoredBox(
        color: palette.surface,
        child: scanning
            ? ref
                  .watch(qrScannerGatewayProvider)
                  .preview(
                    onDetected: controller.onQrDetected,
                    onError: controller.onCameraError,
                  )
            : Center(
                child: Icon(
                  Icons.qr_code_scanner,
                  size: AppSpacing.xl,
                  color: palette.textSecondary,
                ),
              ),
      ),
    );
  }

  Widget _status(ScannerState state) {
    final text = Theme.of(context).textTheme;
    final controller = ref.read(scannerControllerProvider.notifier);

    return switch (state) {
      ScannerRequestingPermission() => const _Busy(
        label: 'Solicitando permissão de localização…',
      ),
      ScannerScanning() => Text(
        'Aponte a câmera para o QR',
        style: text.titleMedium,
      ),
      ScannerLocating() => const _Busy(label: 'Lendo posição…'),
      ScannerSending() => const _Busy(label: 'Verificando seu acesso…'),
      ScannerPermissionDenied(:final message) => _Feedback(
        tone: FeedbackTone.error,
        message: message,
        action: 'Permitir novamente',
        onAction: controller.retry,
      ),
      ScannerFailure(:final message) => _Feedback(
        tone: FeedbackTone.error,
        message: message,
        action: 'Tentar novamente',
        onAction: controller.retry,
      ),
      ScannerSendFailed(:final message, :final retryable) => _Feedback(
        tone: FeedbackTone.error,
        message: message,
        action: retryable ? 'Tentar novamente' : 'Escanear de novo',
        onAction: retryable ? controller.retrySend : controller.retry,
      ),
      // O resultado ocupa a tela inteira e é tratado no `build`.
      ScannerAccessResult() => const SizedBox.shrink(),
    };
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.tone,
    required this.message,
    required this.action,
    required this.onAction,
  });

  final FeedbackTone tone;
  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeedbackBanner(tone: tone, message: message),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(onPressed: onAction, child: Text(action)),
      ],
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
