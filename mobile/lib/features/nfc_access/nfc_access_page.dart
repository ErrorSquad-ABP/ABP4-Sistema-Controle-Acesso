import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'nfc_bridge.dart';
import 'nfc_credential_gateway.dart';

class NfcAccessPage extends ConsumerStatefulWidget {
  const NfcAccessPage({super.key});

  @override
  ConsumerState<NfcAccessPage> createState() => _NfcAccessPageState();
}

class _NfcAccessPageState extends ConsumerState<NfcAccessPage> {
  late final _bridge = ref.read(nfcBridgeProvider);
  NfcCredential? _credential;
  String? _error;
  bool? _supported;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _activate();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refreshIfNeeded());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_supported == true) unawaited(_bridge.clearToken());
    super.dispose();
  }

  Future<void> _activate() async {
    try {
      final supported = await _bridge.isSupported();
      if (!mounted) return;
      setState(() => _supported = supported);
      if (!supported) return;
      final credential = await ref.read(nfcCredentialGatewayProvider).issue();
      if (!mounted) return;
      await _bridge.setToken(credential.token);
      if (!mounted) return;
      setState(() {
        _credential = credential;
        _error = null;
      });
    } on NfcCredentialFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = _message(failure.reason));
    } on Exception {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível ativar o NFC agora.');
    }
  }

  void _refreshIfNeeded() {
    final credential = _credential;
    if (credential == null || _error != null) return;
    final remaining = credential.expiresAt.difference(DateTime.now().toUtc());
    if (remaining.inSeconds <= 5) {
      setState(() => _credential = null);
      _activate();
    } else {
      setState(() {});
    }
  }

  String _message(NfcCredentialFailureReason reason) => switch (reason) {
    NfcCredentialFailureReason.timeout => 'O servidor demorou para emitir a prova.',
    NfcCredentialFailureReason.network => 'Sem conexão para emitir a prova de NFC.',
    NfcCredentialFailureReason.unauthorized => 'Sua sessão expirou. Entre de novo.',
    NfcCredentialFailureReason.unavailable => 'O serviço de NFC está indisponível.',
    NfcCredentialFailureReason.invalidResponse => 'Resposta inválida do servidor.',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final credential = _credential;
    final remaining = credential == null
        ? 0
        : credential.expiresAt.difference(DateTime.now().toUtc()).inSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text('Acesso por NFC')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Encoste o celular no leitor', style: text.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Mantenha esta tela aberta e o aparelho desbloqueado. '
              'A prova vale poucos segundos e é trocada automaticamente; '
              'cada leitura usa uma prova diferente.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_supported == false)
              Text('Este aparelho não suporta NFC por HCE.', style: TextStyle(color: palette.textSecondary))
            else if (_error != null) ...[
              Text(_error!, style: TextStyle(color: palette.error)),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(onPressed: _activate, child: const Text('Tentar novamente')),
            ] else if (credential != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: palette.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.nfc, color: palette.text),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Prova ativa', style: text.labelLarge),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Expira em ${remaining < 0 ? 0 : remaining}s', style: text.bodyMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'A prova não aparece na tela e não fica salva no aparelho.',
                      style: text.bodySmall?.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              )
            else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
