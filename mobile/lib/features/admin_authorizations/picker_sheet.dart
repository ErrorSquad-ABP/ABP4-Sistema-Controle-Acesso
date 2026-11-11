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

/// Uma página de opções e se o servidor ainda tem mais.
class PickerPage {
  const PickerPage({required this.options, required this.hasMore});

  final List<PickerOption> options;
  final bool hasMore;
}

/// Folha de seleção com busca, usada pelos campos Pessoa e Local do
/// formulário de autorização.
///
/// Quem chama decide onde a busca acontece: `GET /users` aceita `search` e
/// filtra no servidor; `GET /locations` não aceita, então o filtro é local
/// sobre as páginas já carregadas. As páginas seguintes vêm sob demanda pelo
/// botão "Mostrar mais".
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

  /// Página [page] (a partir de 1) das opções para [query].
  final Future<PickerPage> Function(String query, int page) load;

  /// Abre a folha e devolve a opção escolhida, ou null se fechar.
  static Future<PickerOption?> show(
    BuildContext context, {
    required String title,
    required String searchHint,
    required String emptyLabel,
    required String errorLabel,
    required Future<PickerPage> Function(String query, int page) load,
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

  final List<PickerOption> _options = [];
  String _query = '';
  int _page = 0;
  int _request = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;
  bool _moreFailed = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _start('');
  }

  @override
  void dispose() {
    _disposed = true;
    _search.dispose();
    super.dispose();
  }

  /// Nova busca: descarta as páginas anteriores e volta para a página 1.
  Future<void> _start(String query) async {
    _query = query;
    final request = ++_request;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _failed = false;
      _moreFailed = false;
    });
    await _fetch(request, page: 1, reset: true);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    await _fetch(_request, page: _page + 1, reset: false);
  }

  Future<void> _fetch(
    int request, {
    required int page,
    required bool reset,
  }) async {
    try {
      final result = await widget.load(_query, page);
      // Uma busca nova enquanto esta respondia não pode misturar páginas.
      if (_disposed || request != _request) return;
      final seen = reset
          ? <String>{}
          : {for (final option in _options) option.id};
      setState(() {
        if (reset) _options.clear();
        _options.addAll([
          for (final option in result.options)
            if (seen.add(option.id)) option,
        ]);
        _page = page;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (_disposed || request != _request) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (reset) {
          _failed = true;
        } else {
          _moreFailed = true;
        }
      });
    }
  }

  void _searchNow() {
    FocusScope.of(context).unfocus();
    _start(_search.text.trim());
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
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }
    if (_failed) {
      return _SheetNote(
        message: widget.errorLabel,
        onRetry: () => _start(_query),
      );
    }
    // A última linha é o "Mostrar mais" (ou o aviso de que ele falhou), mesmo
    // com a busca sem resultados na página carregada: o que falta pode estar
    // na página seguinte.
    final trailing = _hasMore || _moreFailed;
    if (_options.isEmpty && !trailing) {
      return _SheetNote(message: widget.emptyLabel);
    }
    final emptyNote = _options.isEmpty ? 1 : 0;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.sm,
      ),
      itemCount: emptyNote + _options.length + (trailing ? 1 : 0),
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        if (index < emptyNote) {
          return _SheetNote(message: widget.emptyLabel);
        }
        final position = index - emptyNote;
        if (position == _options.length) {
          return _moreFailed
              ? _SheetNote(
                  message: widget.errorLabel,
                  onRetry: _loadMore,
                )
              : _LoadMoreTile(
                  loading: _loadingMore,
                  onPressed: _loadMore,
                );
        }
        return _OptionTile(
          option: _options[position],
          onTap: () => Navigator.of(context).pop(_options[position]),
        );
      },
    );
  }
}

/// Busca a próxima página sem fechar a folha.
class _LoadMoreTile extends StatelessWidget {
  const _LoadMoreTile({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.controlHeight),
      child: Center(
        child: OutlinedButton(
          key: const Key('picker-load-more'),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Mostrar mais'),
        ),
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
