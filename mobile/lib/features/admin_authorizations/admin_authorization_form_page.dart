import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/feedback_banner.dart';
import '../locations/http_location_gateway.dart';
import 'admin_authorization_contract.dart';
import 'http_admin_authorization_gateway.dart';
import 'picker_sheet.dart';

/// Formulário "Nova autorização" (US-30). Não existe frame no Figma: segue o
/// desenho do formulário de local, com seletores no lugar dos campos livres.
class AdminAuthorizationFormPage extends ConsumerStatefulWidget {
  const AdminAuthorizationFormPage({super.key});

  @override
  ConsumerState<AdminAuthorizationFormPage> createState() =>
      _AdminAuthorizationFormPageState();
}

class _AdminAuthorizationFormPageState
    extends ConsumerState<AdminAuthorizationFormPage> {
  final _form = GlobalKey<FormState>();
  final _maxUses = TextEditingController(text: '1');

  PickerOption? _person;
  PickerOption? _place;
  late DateTime _startsAt;
  late DateTime _endsAt;
  bool _saving = false;
  (FeedbackTone, String)? _message;

  @override
  void initState() {
    super.initState();
    // Janela padrão: agora até daqui a 2 h. O administrador ajusta nos campos.
    final now = ref.read(clockProvider)();
    _startsAt = now;
    _endsAt = now.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _maxUses.dispose();
    super.dispose();
  }

  /// Busca pessoas no servidor: `GET /users` aceita `search` por nome ou
  /// e-mail. Só ativas entram, porque desativadas não acessam o condomínio.
  Future<List<PickerOption>> _loadPeople(String query) async {
    final page = await ref
        .read(adminUserGatewayProvider)
        .list(search: query, active: true);
    return [
      for (final user in page.items)
        PickerOption(id: user.id, title: user.name, subtitle: user.display),
    ];
  }

  /// `GET /locations` não tem busca: a folha carrega os ativos e filtra aqui.
  Future<List<PickerOption>> _loadPlaces(String query) async {
    final page = await ref.read(locationGatewayProvider).listActive();
    final folded = searchFold(query.trim());
    return [
      for (final place in page.items)
        if (folded.isEmpty ||
            searchFold(place.name).contains(folded) ||
            searchFold(place.description ?? '').contains(folded))
          PickerOption(
            id: place.id,
            title: place.name,
            subtitle: place.description,
          ),
    ];
  }

  Future<PickerOption?> _choose({
    required String title,
    required String searchHint,
    required String emptyLabel,
    required String errorLabel,
    required Future<List<PickerOption>> Function(String query) load,
  }) => PickerSheet.show(
    context,
    title: title,
    searchHint: searchHint,
    emptyLabel: emptyLabel,
    errorLabel: errorLabel,
    load: load,
  );

  Future<DateTime?> _pickDateTime(DateTime current) async {
    final local = current.toLocal();
    final now = ref.read(clockProvider)().toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Data da janela',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
      helpText: 'Hora da janela',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _message = null);
    if (!_form.currentState!.validate()) return;

    final person = _person;
    final place = _place;
    final maxUses = AdminAuthorizationValidation.parseMaxUses(_maxUses.text);
    if (person == null || place == null || maxUses == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(adminAuthorizationGatewayProvider)
          .create(
            CreateAuthorizationRequest(
              userId: person.id,
              locationId: place.id,
              startsAt: _startsAt,
              endsAt: _endsAt,
              maxUses: maxUses,
            ),
          );
      if (!mounted) return;
      // A lista recarrega quando o formulário devolve sucesso.
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
        AdminFailureReason.invalidRequest => (
          FeedbackTone.error,
          'O servidor recusou os dados da autorização. Confira a janela e o '
              'máximo de usos.',
        ),
        AdminFailureReason.unprocessable => (
          FeedbackTone.error,
          'A pessoa ou o local escolhidos não existem mais. Escolha de novo.',
        ),
        AdminFailureReason.forbidden => (
          FeedbackTone.error,
          'Só administradores criam autorizações.',
        ),
        AdminFailureReason.unauthorized => (
          FeedbackTone.error,
          'Sua sessão expirou. Entre novamente.',
        ),
        AdminFailureReason.notFound => (
          FeedbackTone.warning,
          'A pessoa ou o local escolhidos não foram encontrados.',
        ),
        AdminFailureReason.conflict => (
          FeedbackTone.warning,
          'O servidor recusou a criação por conflito. Tente novamente.',
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
          'Não foi possível criar a autorização. Tente novamente.',
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
                // Depois da primeira interação o erro some ao escolher a
                // pessoa, o local ou a janela, sem esperar o próximo toque.
                autovalidateMode: AutovalidateMode.onUserInteraction,
                // Column dentro do scroll (e não ListView): o botão de criar
                // fica fixo no rodapé, então todo campo precisa estar montado
                // para a validação rodar mesmo fora da área visível.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.xs,
                    AppSpacing.screen,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BackRow(onTap: () => Navigator.of(context).maybePop()),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Nova autorização',
                        style: text.displaySmall?.copyWith(
                          height: 1.35,
                          letterSpacing: -0.96,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Escolha a pessoa, o local e a janela em que o acesso '
                        'estará liberado.',
                        style: text.bodySmall?.copyWith(height: 1.35),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FormField<PickerOption>(
                        key: const Key('field-person'),
                        validator: (value) =>
                            AdminAuthorizationValidation.person(value),
                        builder: (field) => _PickerField(
                          label: 'Pessoa',
                          value: field.value?.title,
                          placeholder: 'Selecionar pessoa',
                          errorText: field.errorText,
                          onTap: () async {
                            final option = await _choose(
                              title: 'Escolher pessoa',
                              searchHint: 'Buscar por nome ou e-mail',
                              emptyLabel: 'Nenhuma pessoa ativa encontrada.',
                              errorLabel:
                                  'Não foi possível carregar as pessoas.',
                              load: _loadPeople,
                            );
                            if (option == null) return;
                            field.didChange(option);
                            setState(() => _person = option);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FormField<PickerOption>(
                        key: const Key('field-place'),
                        validator: (value) =>
                            AdminAuthorizationValidation.location(value),
                        builder: (field) => _PickerField(
                          label: 'Local',
                          value: field.value?.title,
                          placeholder: 'Selecionar local',
                          errorText: field.errorText,
                          onTap: () async {
                            final option = await _choose(
                              title: 'Escolher local',
                              searchHint: 'Buscar por nome ou endereço',
                              emptyLabel: 'Nenhum local ativo encontrado.',
                              errorLabel:
                                  'Não foi possível carregar os locais.',
                              load: _loadPlaces,
                            );
                            if (option == null) return;
                            field.didChange(option);
                            setState(() => _place = option);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FormField<({DateTime startsAt, DateTime endsAt})>(
                        key: const Key('field-window'),
                        initialValue: (startsAt: _startsAt, endsAt: _endsAt),
                        validator: (value) =>
                            AdminAuthorizationValidation.window(
                              value?.startsAt,
                              value?.endsAt,
                            ),
                        builder: (field) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PickerField(
                              key: const Key('field-window-start'),
                              label: 'Início da janela',
                              value: _dateTimeLabel(_startsAt),
                              placeholder: 'Escolher início',
                              onTap: () async {
                                final picked = await _pickDateTime(_startsAt);
                                if (picked == null) return;
                                setState(() => _startsAt = picked);
                                field.didChange((
                                  startsAt: picked,
                                  endsAt: _endsAt,
                                ));
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _PickerField(
                              key: const Key('field-window-end'),
                              label: 'Fim da janela',
                              value: _dateTimeLabel(_endsAt),
                              placeholder: 'Escolher fim',
                              // O erro da janela fica sob o último campo: é
                              // nele que o fim precisa ser corrigido.
                              errorText: field.errorText,
                              onTap: () async {
                                final picked = await _pickDateTime(_endsAt);
                                if (picked == null) return;
                                setState(() => _endsAt = picked);
                                field.didChange((
                                  startsAt: _startsAt,
                                  endsAt: picked,
                                ));
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'MÁXIMO DE USOS',
                        style: text.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Semantics(
                        label: 'Máximo de usos',
                        child: TextFormField(
                          key: const Key('field-max-uses'),
                          controller: _maxUses,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: text.bodyLarge?.copyWith(height: 1.35),
                          validator: AdminAuthorizationValidation.maxUses,
                          decoration: const InputDecoration(hintText: '5'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'A janela precisa terminar depois de começar e o máximo '
                        'de usos vai de 1 a 1000.',
                        style: text.bodySmall?.copyWith(height: 1.35),
                      ),
                    ],
                  ),
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

/// `11/11/2026 · 14:00` no fuso do aparelho.
String _dateTimeLabel(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · '
      '${two(local.hour)}:${two(local.minute)}';
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return SizedBox(
      key: const Key('back-to-admin-authorizations'),
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
                  'Autorizações',
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

/// Campo de seleção: mostra o valor escolhido e abre a folha de busca.
class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final value = this.value;
    final error = errorText;
    final radius = BorderRadius.circular(AppRadius.control);
    // Mesmo tom de erro do tema (o #DC2626 puro reprova AA no tema escuro).
    final errorColor =
        Theme.of(context).inputDecorationTheme.errorStyle?.color ??
        palette.error;

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
          button: true,
          label: label,
          value: value ?? placeholder,
          excludeSemantics: true,
          child: Material(
            color: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: error == null ? palette.hairline : errorColor,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.controlHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value ?? placeholder,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge?.copyWith(
                            height: 1.35,
                            color: value == null
                                ? palette.textSecondary
                                : palette.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.expand_more,
                        size: 20,
                        color: palette.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            error,
            style: text.bodySmall?.copyWith(height: 1.35, color: errorColor),
          ),
        ],
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
      label: saving ? 'Criando autorização' : 'Criar autorização',
      child: SizedBox(
        key: const Key('save-admin-authorization-action'),
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
                      saving ? 'Criando…' : 'Criar autorização',
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
