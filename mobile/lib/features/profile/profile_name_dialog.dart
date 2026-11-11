import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/feedback_banner.dart';
import '../auth/auth_contract.dart';
import 'profile_controller.dart';

/// Regras do `PATCH /me`: o nome vai de 2 a 120 caracteres.
abstract final class ProfileNameValidation {
  static const int minLength = 2;
  static const int maxLength = 120;

  static String? validate(String? value) {
    final name = (value ?? '').trim();
    if (name.length < minLength) {
      return 'Informe seu nome (ao menos $minLength caracteres).';
    }
    if (name.length > maxLength) {
      return 'O nome deve ter até $maxLength caracteres.';
    }
    return null;
  }
}

/// Diálogo de edição do nome. Fica aberto enquanto o `PATCH /me` não confirma,
/// para um erro do servidor não perder o que foi digitado.
class ProfileNameDialog extends ConsumerStatefulWidget {
  const ProfileNameDialog({required this.initialName, super.key});

  final String initialName;

  @override
  ConsumerState<ProfileNameDialog> createState() => _ProfileNameDialogState();
}

class _ProfileNameDialogState extends ConsumerState<ProfileNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  bool _saving = false;
  (FeedbackTone, String)? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(profileUserProvider.notifier).rename(_name.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = _failureMessage(failure.reason));
    } catch (_) {
      if (mounted) {
        setState(() => _error = _failureMessage(AuthFailureReason.unexpected));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static (FeedbackTone, String) _failureMessage(AuthFailureReason reason) =>
      switch (reason) {
        AuthFailureReason.invalidRequest => (
          FeedbackTone.error,
          'Confira o nome informado e tente de novo.',
        ),
        AuthFailureReason.unauthorized => (
          FeedbackTone.error,
          'Sua sessão foi encerrada. Entre novamente.',
        ),
        AuthFailureReason.tooManyRequests => (
          FeedbackTone.warning,
          'Muitas tentativas seguidas. Aguarde um instante.',
        ),
        AuthFailureReason.unavailable => (
          FeedbackTone.warning,
          'O serviço está fora do ar. Tente novamente em instantes.',
        ),
        AuthFailureReason.network => (
          FeedbackTone.warning,
          'Sem conexão com o servidor. Verifique sua internet.',
        ),
        AuthFailureReason.timeout => (
          FeedbackTone.warning,
          'O servidor demorou para responder. Tente novamente.',
        ),
        AuthFailureReason.unexpected => (
          FeedbackTone.error,
          'Não foi possível salvar o nome. Tente novamente.',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Editar nome'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Seu nome aparece para a administração e no seu perfil.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                label: 'Novo nome',
                child: TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: ProfileNameValidation.validate,
                  decoration: const InputDecoration(
                    hintText: 'Seu nome completo',
                  ),
                ),
              ),
              if (_error case (final tone, final message)) ...[
                const SizedBox(height: AppSpacing.sm),
                FeedbackBanner(tone: tone, message: message),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
