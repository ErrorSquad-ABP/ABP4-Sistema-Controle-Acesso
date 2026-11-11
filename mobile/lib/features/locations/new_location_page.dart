import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/feedback_banner.dart';
import 'http_location_gateway.dart';
import 'location_contract.dart';

/// Tela "Novo local" (frame Claro 82:2 / Escuro 82:60).
///
/// O formulário do Figma tem só nome e endereço; a API de geofence exige
/// latitude, longitude e raio (1..100 m), então esses campos entram com o
/// mesmo desenho do design system.
class NewLocationPage extends ConsumerStatefulWidget {
  const NewLocationPage({super.key});

  @override
  ConsumerState<NewLocationPage> createState() => _NewLocationPageState();
}

class _NewLocationPageState extends ConsumerState<NewLocationPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _radius = TextEditingController();

  bool _saving = false;
  (FeedbackTone, String)? _message;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _message = null);
    if (!_form.currentState!.validate()) return;

    final latitude = LocationValidation.parseDecimal(_latitude.text);
    final longitude = LocationValidation.parseDecimal(_longitude.text);
    final radiusMeters = int.tryParse(_radius.text.trim());
    if (latitude == null || longitude == null || radiusMeters == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(locationGatewayProvider).create(
        CreateLocationRequest(
          name: _name.text,
          description: _description.text,
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
        ),
      );
      if (!mounted) return;
      // A lista recarrega quando o formulário devolve sucesso.
      Navigator.of(context).pop(true);
    } on LocationFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = _failureMessage(failure.reason));
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = _failureMessage(LocationFailureReason.unexpected));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static (FeedbackTone, String) _failureMessage(
    LocationFailureReason reason,
  ) => switch (reason) {
    LocationFailureReason.invalidRequest => (
      FeedbackTone.error,
      'O servidor recusou os dados do local. Confira nome, endereço, '
          'coordenadas e raio.',
    ),
    LocationFailureReason.forbidden => (
      FeedbackTone.error,
      'Só administradores podem cadastrar locais.',
    ),
    LocationFailureReason.unauthorized => (
      FeedbackTone.error,
      'Sua sessão expirou. Entre novamente.',
    ),
    LocationFailureReason.unavailable => (
      FeedbackTone.warning,
      'O serviço de locais está fora do ar. Tente novamente em instantes.',
    ),
    LocationFailureReason.network => (
      FeedbackTone.warning,
      'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
    ),
    LocationFailureReason.timeout => (
      FeedbackTone.warning,
      'O servidor demorou para responder. Tente novamente em instantes.',
    ),
    LocationFailureReason.unexpected => (
      FeedbackTone.error,
      'Não foi possível salvar o local. Tente novamente.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final message = _message;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.xs,
                    AppSpacing.screen,
                    AppSpacing.md,
                  ),
                  children: [
                    _BackRow(
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Novo local',
                      style: text.displaySmall?.copyWith(
                        height: 1.35,
                        letterSpacing: -0.96,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Identifique o local e informe o endereço do ponto de '
                      'acesso.',
                      style: text.bodySmall?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FormField(
                      fieldKey: const Key('field-name'),
                      label: 'Nome do local',
                      hint: 'Edifício Aurora · Recepção',
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      validator: LocationValidation.name,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FormField(
                      fieldKey: const Key('field-description'),
                      label: 'Endereço',
                      hint: 'Av. Central, 1200',
                      controller: _description,
                      textCapitalization: TextCapitalization.words,
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      validator: LocationValidation.description,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _FormField(
                            fieldKey: const Key('field-latitude'),
                            label: 'Latitude',
                            hint: '-23,1857',
                            controller: _latitude,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  signed: true,
                                  decimal: true,
                                ),
                            inputFormatters: const [_DecimalInputFormatter()],
                            validator: LocationValidation.latitude,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _FormField(
                            fieldKey: const Key('field-longitude'),
                            label: 'Longitude',
                            hint: '-45,8846',
                            controller: _longitude,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  signed: true,
                                  decimal: true,
                                ),
                            inputFormatters: const [_DecimalInputFormatter()],
                            validator: LocationValidation.longitude,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FormField(
                      fieldKey: const Key('field-radius'),
                      label: 'Raio (metros)',
                      hint: '100',
                      controller: _radius,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: LocationValidation.radius,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Informe o endereço e o raio de acesso. O raio deve '
                      'ficar entre 1 e 100 metros.',
                      style: text.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  0,
                  AppSpacing.screen,
                  40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (message != null) ...[
                      FeedbackBanner(tone: message.$1, message: message.$2),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _SaveAction(saving: _saving, onPressed: _submit),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return SizedBox(
      key: const Key('back-to-locations'),
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onTap,
          child: Row(
            children: [
              Icon(Icons.arrow_back, size: 20, color: palette.text),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Locais de acesso',
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rótulo micro em caixa alta acima do campo, como no componente do Figma.
class _FormField extends StatelessWidget {
  const _FormField({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          label: label,
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            minLines: minLines,
            maxLines: maxLines,
            style: text.bodyLarge?.copyWith(height: 1.35),
            decoration: InputDecoration(hintText: hint),
          ),
        ),
      ],
    );
  }
}

class _SaveAction extends StatelessWidget {
  const _SaveAction({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      enabled: !saving,
      liveRegion: saving,
      label: saving ? 'Salvando local' : 'Salvar local',
      child: SizedBox(
        key: const Key('save-location-action'),
        height: AppSpacing.controlHeight,
        child: Material(
          color: palette.text,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: saving ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.xs,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      saving ? 'Salvando…' : 'Salvar local',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge?.copyWith(
                        color: palette.background,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.background,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: saving
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.text,
                              ),
                            )
                          : Icon(
                              Icons.arrow_forward,
                              size: 20,
                              color: palette.text,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Teclado decimal aceita vírgula e ponto, sem letras.
class _DecimalInputFormatter extends TextInputFormatter {
  const _DecimalInputFormatter();

  static final _allowed = RegExp(r'^-?\d*[,.]?\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _allowed.hasMatch(newValue.text) ? newValue : oldValue;
}
