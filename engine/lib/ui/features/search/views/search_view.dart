import 'package:flutter/material.dart';

import '../../../core/components/working_indicator.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';
import '../../../../data/repositories/search_repository.dart';
import '../../../../domain/search/logos_text.dart';
import '../../../../domain/search/search_query.dart';
import '../../../../domain/search/search_results.dart';
import '../view_models/search_view_model.dart';
import 'search_query_field.dart';
import 'syntax_help_view.dart';

/// The search destination: scope tabs, a query field, and either the syntax help or results.
///
/// The help panel is shown *instead of* results while the field is empty, which is what
/// the reference does — an empty result area next to an explanation would be a dead
/// region, and the explanation is more useful there.
class SearchView extends StatelessWidget {
  const SearchView({
    super.key,
    required this.viewModel,
    this.onOpenResult,
  });

  final SearchViewModel viewModel;

  /// Opens a result in the reader.
  final void Function(SearchResult result)? onOpenResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScopeTabs(viewModel: viewModel),
        const Divider(height: 1, color: LogosColors.border),
        SearchQueryField(viewModel: viewModel),
        if (viewModel.error != null)
          _ErrorBar(error: viewModel.error!, operator: viewModel.errorOperator),
        const Divider(height: 1, color: LogosColors.border),
        Expanded(
          child: viewModel.showsHelp
              ? SyntaxHelpView(onExample: viewModel.runExample)
              : _Results(viewModel: viewModel, onOpenResult: onOpenResult),
        ),
      ],
    );
  }
}

/// The `Todo` / `Biblia` / `Libros` tabs.
class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({required this.viewModel});

  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LogosSpacing.md,
          vertical: LogosSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final scope in SearchScope.values)
              _ScopeTab(
                scope: scope,
                selected: scope == viewModel.scope,
                onTap: () => viewModel.setScope(scope),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.scope,
    required this.selected,
    required this.onTap,
  });

  final SearchScope scope;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Buscar en ${scope.label}',
      child: InkWell(
        onTap: onTap,
        // 44dp so the target meets the touch minimum even though the label is short.
        child: Container(
          constraints: const BoxConstraints(minHeight: LogosMeasured.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // An underline rather than a filled tab, which is what the reference uses for
            // these three, and it keeps the row visually light.
            border: Border(
              bottom: BorderSide(
                width: selected ? 2 : 0,
                color: LogosColors.searchSelectedBorder,
              ),
            ),
          ),
          child: Text(
            scope.label,
            style: LogosTypography.navItem.copyWith(
              color: selected ? LogosColors.primary : LogosColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// A syntax error, with the offending operator named.
class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.error, required this.operator});

  final String error;
  final String? operator;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: LogosColors.dangerSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: LogosSpacing.md,
        vertical: LogosSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: LogosColors.danger),
          const SizedBox(width: LogosSpacing.sm),
          Expanded(
            child: Text(
              error,
              style:
                  LogosTypography.body.copyWith(fontSize: 13, color: LogosColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Results, or the empty state.
class _Results extends StatelessWidget {
  const _Results({required this.viewModel, this.onOpenResult});

  final SearchViewModel viewModel;
  final void Function(SearchResult result)? onOpenResult;

  @override
  Widget build(BuildContext context) {
    final run = viewModel.run;

    if (viewModel.status == SearchStatus.running && run == null) {
      // The settling indicator rather than an infinite spinner: the search field is
      // rebuilt on every keystroke, and a spinner that never settles schedules a frame for
      // as long as the user is typing.
      return const WorkingIndicator(label: 'Buscando…');
    }

    if (run == null || run.isEmpty) {
      return _EmptyState(viewModel: viewModel);
    }

    return AdaptiveLayout(
      builder: (context, layoutClass) => ListView.separated(
        padding: const EdgeInsets.all(LogosSpacing.md),
        itemCount: run.results.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: LogosSpacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) return _ResultCount(run: run);
          final result = run.results[index - 1];
          return _ResultRow(result: result, onOpen: onOpenResult);
        },
      ),
    );
  }
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.run});

  final SearchRun run;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LogosSpacing.sm),
      child: Text(
        run.truncated
            ? 'Mostrando ${run.results.length} de ${run.totalFound} resultados '
                'en ${run.moduleCount} módulos'
            : '${run.totalFound} resultados en ${run.moduleCount} módulos',
        style: LogosTypography.sectionLabel,
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, this.onOpen});

  final SearchResult result;
  final void Function(SearchResult result)? onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onOpen == null ? null : () => onOpen!(result),
        child: Padding(
          padding: const EdgeInsets.all(LogosSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(result.label, style: LogosTypography.navItem),
                  const SizedBox(width: LogosSpacing.sm),
                  Text(
                    result.moduleName,
                    style: LogosTypography.body.copyWith(
                      fontSize: 12,
                      color: LogosColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: LogosSpacing.xs),
              ConstrainedReading(
                child: _HighlightedText(segments: result.segments),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders result text with the matched runs marked.
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({required this.segments});

  final List<SearchSegment> segments;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          for (final s in segments)
            if (s.isRenderable)
              TextSpan(
                text: s.text,
                style: s.matched
                    ? LogosTypography.body.copyWith(
                        // The reference's own hit background is orange, not the brand
                        // blue: a mark inside body text has to read as a highlight and not
                        // as a link.
                        backgroundColor: LogosColors.searchHitBackground,
                        color: LogosColors.searchHitText,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
        ],
      ),
      style: LogosTypography.body,
    );
  }
}

/// Shown when a query matches nothing.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.viewModel});

  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedReading(
        child: Padding(
          padding: const EdgeInsets.all(LogosSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 36, color: LogosColors.textDisabled),
              const SizedBox(height: LogosSpacing.md),
              const Text('Sin resultados', style: LogosTypography.title),
              const SizedBox(height: LogosSpacing.sm),
              Text(
                _suggestion(),
                textAlign: TextAlign.center,
                style: LogosTypography.body.copyWith(color: LogosColors.textSecondary),
              ),
              const SizedBox(height: LogosSpacing.md),
              OutlinedButton(
                onPressed: () => viewModel.runExample(_broadenedQuery()),
                child: const Text('Pruebe con una búsqueda más amplia'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Why the search found nothing, in terms the user can act on.
  String _suggestion() {
    final run = viewModel.run;
    if (run == null || run.moduleCount == 0) {
      return 'No hay contenido instalado que buscar. Abra la biblioteca e instale un '
          'recurso para buscar en él.';
    }
    return 'Pruebe con menos términos, con un comodín como Crist*, o cambie el ámbito de '
        'la búsqueda.';
  }

  /// A weaker query to offer, derived from what the user typed.
  ///
  /// A wildcard that matched nothing is the usual cause, so the term is offered with the
  /// wildcard removed — `crist*` becomes `crist` — which finds the stem's occurrences
  /// rather than every word extending it. Falls back to a plain conjunction of the
  /// literal terms, and to a fixed example when the query has no terms to work from.
  String _broadenedQuery() {
    final parsed = viewModel.parsed;
    if (parsed == null) return 'Cristo O Jesús';

    final literals = <String>[];
    void visit(SearchNode n) {
      if (n is SearchTerm) {
        literals.add(n.hasWildcard
            ? LogosText.fold(
                n.raw.replaceAll(RegExp(r'[*?]'), ''),
              )
            : n.raw);
      } else if (n is SearchPhrase) {
        literals.add('"${n.text}"');
      } else if (n is SearchGroup) {
        visit(n.inner);
      } else if (n is SearchBinary) {
        visit(n.left);
        visit(n.right);
      }
    }

    visit(parsed);
    final terms = [
      for (final t in literals)
        if (t.isNotEmpty) t
    ];
    if (terms.isEmpty) return 'Cristo O Jesús';
    // Two adjacent terms already mean "both", so joining with a space produces a valid
    // query without reintroducing an operator the user may have got wrong.
    return terms.join(' ');
  }
}
