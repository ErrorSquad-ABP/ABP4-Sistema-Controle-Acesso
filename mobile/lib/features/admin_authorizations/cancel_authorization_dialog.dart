import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/feedback_banner.dart';
import '../authorizations/authorization_contract.dart';
import 'admin_authorization_contract.dart';
import 'http_admin_authorization_gateway.dart';

/// Pede o motivo e cancela a autorização. Devolve true quando o backend
/// confirmou o cancelamento.
Future<bool?> showCancelAuthorizationDialog(
  BuildContext context, {
  required Authorization authorization,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) =>
        _CancelAuthorizationDialog(authorization: authorization),
  );
}

class _CancelAuthorizationDialog extends ConsumerStatefulWidget {
  const _CancelAuthorizationDialog({required this.authorization});

  final Authorization authorization;

  @override
  ConsumerState<_CancelAuthorizationDialog> createState() =>
      _CancelAuthorizationDialogState();
}

class _CancelAuthorizationDialogState
    extends ConsumerState<_CancelAuthorizationDialog> {
  final _reason = TextEditingController();
  bool _saving = false;
  String? _reasonError;
  (FeedbackTone, String)? _message;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_saving) return;
    final reasonError = AdminAuthorizationValidation.cancelReason(_reason.text);
    setState(() {
      _reasonError = reasonError;
      _message = null;
    });
    if (reasonError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(adminAuthorizationGatewayProvider)
          .cancel(widget.authorization.id, _reason.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AdminFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = _failureMessage(failure.reason));
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = _failureMessage(AdminFailureReason.unexpected));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static (FeedbackTone, String) _failureMessage(AdminFailureReason reason) =>
      switch (reason) {
        AdminFailureReason.conflict => (
          FeedbackTone.warning,
          'Esta autorização já foi cancelada ou expirou. Feche e atualize a '
              'lista.',
        ),
        AdminFailureReason.forbidden => (
          FeedbackTone.error,
          'Só administradores podem cancelar autorizações.',
        ),
        AdminFailureReason.notFound => (
          FeedbackTone.warning,
          'Autorização não encontrada. Feche e atualize a lista.',
        ),
        AdminFailureReason.unauthorized => (
          FeedbackTone.error,
          'Sua sessão expirou. Entre novamente.',
        ),
        AdminFailureReason.invalidRequest => (
          FeedbackTone.error,
          'O servidor recusou o motivo do cancelamento.',
        ),
        AdminFailureReason.unprocessable => (
          FeedbackTone.error,
          'O servidor recusou o cancelamento desta autorização.',
        ),
        AdminFailureReason.unavailable => (
          FeedbackTone.warning,
          'O serviço de autorizações está fora do ar. Tente novamente em '
              'instantes.',
        ),
        AdminFailureReason.network => (
          FeedbackTone.warning,
          'Sem conexão com o servidor. Verifique sua internet e tente de novo.',
        ),
        AdminFailureReason.timeout => (
          FeedbackTone.warning,
          'O servidor demorou para responder. Tente novamente em instantes.',
        ),
        AdminFailureReason.unexpected => (
          FeedbackTone.error,
          'Não foi possível cancelar a autorização. Tente novamente.',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final message = _message;
    final authorization = widget.authorization;

    return AlertDialog(
      // Com a fonte ampliada o conteúdo rola em vez de estourar o diálogo.
      scrollable: true,
      title: const Text('Cancelar autorização'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${authorization.locationName} · ${authorization.person.display}',
            style: text.bodySmall?.copyWith(height: 1.35),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'MOTIVO',
            style: text.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label: 'Motivo',
            child: TextField(
              key: const Key('field-cancel-reason'),
              controller: _reason,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              maxLength: AdminAuthorizationValidation.maxReasonLength,
              style: text.bodyLarge?.copyWith(height: 1.35),
              decoration: InputDecoration(
                hintText: 'Ex.: visita remarcada',
                errorText: _reasonError,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FeedbackBanner(tone: message.$1, message: message.$2),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _confirm,
          child: Text(_saving ? 'Cancelando…' : 'Cancelar autorização'),
        ),
      ],
    );
  }
}
