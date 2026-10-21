import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/feedback_banner.dart';
import 'scanner_controller.dart';
import 'scanner_gateways.dart';

final _coordinateFormat = NumberFormat('0.000000', 'pt_BR');

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(scannerControllerProvider.notifier).requestPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerControllerProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nenhum acesso é liberado por esta leitura: o QR e a posição '
                'são apenas exibidos.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _previewArea(state)),
              const SizedBox(height: AppSpacing.sm),
              _status(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewArea(ScannerState state) {
    final palette = context.palette;
    final controller = ref.read(scannerControllerProvider.notifier);
    final scanning = state is ScannerScanning || state is ScannerLocating;

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
      ScannerResult(:final qrValue, :final latitude, :final longitude) =>
        _Feedback(
          tone: FeedbackTone.success,
          message:
              'QR lido: $qrValue\n'
              'Latitude: ${_coordinateFormat.format(latitude)} · '
              'Longitude: ${_coordinateFormat.format(longitude)}',
          action: 'Escanear outro',
          onAction: controller.retry,
        ),
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
