import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Opção de um seletor: pessoa ou local.
class PickerOption {
  const PickerOption({required this.id, required this.title, this.subtitle});

  final String id;
  final String title;
  final String? subtitle;
}

/// Folha de seleção com busca, usada pelos campos Pessoa e Local do
/// formulário de autorização.
///
/// Quem chama decide onde a busca acontece: `GET /users` aceita `search` e
/// filtra no servidor; `GET /locations` não aceita, então o filtro é local
/// sobre a página carregada.
class PickerSheet extends StatefulWidget {
  const PickerSheet({
    super.key,
    required this.title,
    required this.searchHint,
    required this.emptyLabel,
    required this.errorLabel,
    required this.load,
  });

  final String title;
  final String searchHint;
  final String emptyLabel;
  final String errorLabel;

  /// Devolve as opções já filtradas para [query].
  final Future<List<PickerOption>> Function(String query) load;

  /// Abre a folha e devolve a opção escolhida, ou null se fechar.
  static Future<PickerOption?> show(
    BuildContext context, {
    required String title,
    required String searchHint,
    required String emptyLabel,
    required String errorLabel,
    required Future<List<PickerOption>> Function(String query) load,
  }) {
    return showModalBottomSheet<PickerOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.palette.background,
      builder: (context) => PickerSheet(
        title: title,
        searchHint: searchHint,
        emptyLabel: emptyLabel,
        errorLabel: errorLabel,
        load: load,
      ),
    );
  }

  @override
  State<PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<PickerSheet> {
  final _search = TextEditingController();
  late Future<List<PickerOption>> _options;

  @override
  void initState() {
    super.initState();
    _options = widget.load('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _searchNow() {
    FocusScope.of(context).unfocus();
    final options = widget.load(_search.text.trim());
    setState(() {
      _options = options;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return SizedBox(
      // 72% da tela: a busca e o título ficam visíveis e a lista rola por
      // dentro, inclusive com a fonte do sistema ampliada.
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.hairline,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: Text(widget.title, style: text.titleLarge),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: TextField(
              key: const Key('picker-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchNow(),
              style: text.bodyLarge?.copyWith(height: 1.35),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.arrow_forward, size: 20),
                  onPressed: _searchNow,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: FutureBuilder<List<PickerOption>>(
              future: _options,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: SizedBox.square(
                      dimension: 32,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _SheetNote(
                    message: widget.errorLabel,
                    onRetry: _searchNow,
                  );
                }
                final options = snapshot.data ?? const <PickerOption>[];
                if (options.isEmpty) {
                  return _SheetNote(message: widget.emptyLabel);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    0,
                    AppSpacing.screen,
                    AppSpacing.sm,
                  ),
                  itemCount: options.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) => _OptionTile(
                    option: options[index],
                    onTap: () => Navigator.of(context).pop(options[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.onTap});

  final PickerOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final subtitle = option.subtitle;
    final radius = BorderRadius.circular(AppRadius.control);

    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.controlHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: text.bodyLarge?.copyWith(
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: text.bodySmall?.copyWith(height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: palette.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetNote extends StatelessWidget {
  const _SheetNote({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final retry = onRetry;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(height: 1.35),
            ),
            if (retry != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: retry,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Tentar novamente'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
