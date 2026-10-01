import 'package:flutter/material.dart';

import '../../../core/components/working_indicator.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';
import '../../../../data/repositories/library_repository.dart';
import '../../../../domain/models/catalog.dart';
import '../../../../domain/models/library_query.dart';
import '../view_models/library_view_model.dart';
import 'resource_cover.dart';

/// The library: what is installed, what can be installed, and what is not yet available.
///
/// One flat list, not the three sections an earlier draft used. The reference's library is
/// a flat list, and the filters are what divide it — `Suyos` and `Tienda` are a partition of
/// the same rows. Keeping the sections *and* the filters would mean the same resource could
/// appear under two headings, which is the confusion the segmented control exists to remove.
///
/// What replaces the sections is the per-row state: a resource that cannot be installed
/// says why on its own row. That is strictly more information than a heading, because the
/// reason differs per resource — a blocked licence, a missing hash, a failed download — and
/// one heading cannot carry three of them.
class LibraryView extends StatefulWidget {
  const LibraryView({
    super.key,
    required this.viewModel,
    required this.onOpenResource,
  });

  final LibraryViewModel viewModel;

  /// Opens an installed resource in a workspace tab.
  final void Function(ResourceDescriptor resource) onOpenResource;

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.viewModel.query.text);
    widget.viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    _search.dispose();
    super.dispose();
  }

  /// Keeps the field in step when the query is changed from somewhere other than the
  /// field — a cleared search, or a restored preference.
  ///
  /// Guarded on inequality because assigning a controller's text from its own listener
  /// moves the caret to the end, which would make a user typing in the middle of the
  /// query jump to the end on every keystroke.
  void _onViewModelChanged() {
    if (!mounted) return;
    if (_search.text != widget.viewModel.query.text) {
      _search.value = TextEditingValue(
        text: widget.viewModel.query.text,
        selection: TextSelection.collapsed(offset: widget.viewModel.query.text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) => _body(),
    );
  }

  Widget _body() {
    final vm = widget.viewModel;
    final state = vm.state;

    // The read never completed, or is in flight. Distinguished from "loaded and empty"
    // because only one of those is a reason to wait.
    if (vm.status == LibraryStatus.loading && !state.loaded) {
      return const WorkingIndicator(label: 'Abriendo la biblioteca…');
    }

    // The installed tree could not be read. There is nothing to fall back to, so this is
    // the one failure that replaces the screen rather than a row.
    if (vm.status == LibraryStatus.failed) {
      return _LoadFailed(error: vm.error!, onRetry: () => vm.retry());
    }

    final visible = vm.visible;

    return Column(
      children: [
        _Toolbar(
          viewModel: vm,
          controller: _search,
          count: visible.length,
        ),
        const Divider(height: 1, color: LogosColors.border),
        Expanded(
          child: visible.isEmpty
              ? _EmptyLibrary(
                  query: vm.query,
                  catalogKnown: state.catalogVersion != null,
                  installedCount: state.installed.length,
                  storeCount: state.available.length + state.unverifiable.length,
                  onClearSearch: () => vm.setSearchText(''),
                  onShowStore: () => vm.setScope(LibraryScope.store),
                )
              : vm.query.viewMode == LibraryViewMode.grid
                  ? _Grid(
                      entries: visible,
                      viewModel: vm,
                      onOpenResource: widget.onOpenResource,
                    )
                  : _List(
                      entries: visible,
                      viewModel: vm,
                      onOpenResource: widget.onOpenResource,
                    ),
        ),
      ],
    );
  }
}

/// The search field, the count, the scope control, the sort, and the view toggle.
///
/// The count sits inside the field's trailing edge because that is where the reference puts
/// it, and because it is the one number a user is looking for while typing: a search that
/// silently returns nothing looks broken, and a count that updates as they type is the
/// feedback that says it is working.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.viewModel,
    required this.controller,
    required this.count,
  });

  final LibraryViewModel viewModel;
  final TextEditingController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final query = viewModel.query;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LogosSpacing.md,
        LogosSpacing.sm,
        LogosSpacing.md,
        LogosSpacing.sm,
      ),
      child: Column(
        children: [
          ConstrainedReading(
            maxWidth: 1100,
            child: TextField(
              controller: controller,
              onChanged: viewModel.setSearchText,
              textInputAction: TextInputAction.search,
              style: LogosTypography.navItem,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Buscar',
                hintStyle: LogosTypography.navItem
                    .copyWith(color: LogosColors.textMuted),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: LogosColors.textMuted),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: const OutlineInputBorder(),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: LogosSpacing.md),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '$count',
                      style: LogosTypography.sectionLabel,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: LogosSpacing.sm),
          ConstrainedReading(
            maxWidth: 1100,
            child: Row(
              children: [
                // The scope control, the sort and — when the window is too narrow for
                // them on one line — a second line, all inside the space the view toggle
                // leaves. Measured at 360px the three controls are about 370 wide against
                // 336 available, so a single Row overflows by a wide margin; the Wrap
                // gives the sort its own line instead of clipping the segmented control.
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: LogosSpacing.sm,
                    runSpacing: LogosSpacing.xs,
                    children: [
                      _ScopeControl(
                        scope: query.scope,
                        onChanged: viewModel.setScope,
                      ),
                      _SortControl(
                        sort: query.sort,
                        onChanged: viewModel.setSort,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: LogosSpacing.sm),
                _ViewToggle(
                  mode: query.viewMode,
                  onChanged: viewModel.setViewMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `Suyos` / `Tienda`, as a segmented control.
class _ScopeControl extends StatelessWidget {
  const _ScopeControl({required this.scope, required this.onChanged});

  final LibraryScope scope;
  final ValueChanged<LibraryScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: LogosColors.border),
        borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in LibraryScope.values) ...[
            if (s != LibraryScope.values.first)
              Container(width: 1, height: 28, color: LogosColors.border),
            _ScopeSegment(
              scope: s,
              selected: s == scope,
              onTap: () => onChanged(s),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScopeSegment extends StatelessWidget {
  const _ScopeSegment({
    required this.scope,
    required this.selected,
    required this.onTap,
  });

  final LibraryScope scope;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: scope.label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // 44dp tall rather than the 28dp the reference's control is, because this
          // application ships to touch platforms and the control is a target, not a label.
          constraints: const BoxConstraints(minHeight: LogosMeasured.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.md),
          alignment: Alignment.center,
          color: selected ? LogosColors.primary : null,
          child: Text(
            scope.label,
            style: LogosTypography.navItem.copyWith(
              color: selected ? LogosColors.surface : LogosColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// The sort dropdown. `por Título` is the reference's own wording.
class _SortControl extends StatelessWidget {
  const _SortControl({required this.sort, required this.onChanged});

  final LibrarySort sort;
  final ValueChanged<LibrarySort> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: LogosMeasured.minTouchTarget),
      child: PopupMenuButton<LibrarySort>(
        initialValue: sort,
        onSelected: onChanged,
        tooltip: 'Ordenar',
        padding: EdgeInsets.zero,
        itemBuilder: (context) => [
          for (final s in LibrarySort.values)
            PopupMenuItem(value: s, child: Text(s.label)),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: LogosColors.border),
            borderRadius:
                BorderRadius.circular(LogosDimensions.borderRadiusButton),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sort.label,
                style: LogosTypography.navItem
                    .copyWith(color: LogosColors.textSecondary),
              ),
              const SizedBox(width: LogosSpacing.xs),
              const Icon(Icons.arrow_drop_down,
                  size: 18, color: LogosColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid or list. Persisted by the caller, not here.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.mode, required this.onChanged});

  final LibraryViewMode mode;
  final ValueChanged<LibraryViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in LibraryViewMode.values)
          Tooltip(
            message: m.label,
            child: Semantics(
              button: true,
              selected: m == mode,
              label: m.label,
              child: InkWell(
                onTap: () => onChanged(m),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: LogosMeasured.minTouchTarget,
                    minHeight: LogosMeasured.minTouchTarget,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    m == LibraryViewMode.list ? Icons.view_list : Icons.grid_view,
                    size: 18,
                    color: m == mode
                        ? LogosColors.primary
                        : LogosColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One column of rows, as the reference shows them.
class _List extends StatelessWidget {
  const _List({
    required this.entries,
    required this.viewModel,
    required this.onOpenResource,
  });

  final List<LibraryEntry> entries;
  final LibraryViewModel viewModel;
  final void Function(ResourceDescriptor) onOpenResource;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: LogosSpacing.xl),
      itemCount: entries.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: LogosColors.border),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: _Row(
              entry: entry,
              viewModel: viewModel,
              onOpen: entry.installed
                  ? () => onOpenResource(entry.resource)
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// A responsive cover grid: one column on compact, two on medium, three or more beyond.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.entries,
    required this.viewModel,
    required this.onOpenResource,
  });

  final List<LibraryEntry> entries;
  final LibraryViewModel viewModel;
  final void Function(ResourceDescriptor) onOpenResource;

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      builder: (context, layoutClass) {
        final fixedColumns = layoutClass.gridColumns;

        Widget gridFor(double width, int columns) {
          const spacing = LogosSpacing.md;
          final cardWidth = (width - spacing * (columns - 1)) / columns;
          return GridView.builder(
            padding: const EdgeInsets.all(LogosSpacing.md),
            itemCount: entries.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              // The card is a cover plus two lines of text, so its height is derived from
              // its width rather than fixed: a fixed aspect ratio stretches the cover on a
              // narrow column and cramps it on a wide one.
              childAspectRatio: cardWidth / (cardWidth * 0.75 + 78),
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _Card(
                entry: entry,
                viewModel: viewModel,
                onOpen: entry.installed
                    ? () => onOpenResource(entry.resource)
                    : null,
              );
            },
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            if (fixedColumns != null) return gridFor(constraints.maxWidth, fixedColumns);

            // `LayoutClass.large` reports a null column count, meaning "grow with the
            // window". A max-extent delegate is how that is expressed — the same
            // arrangement `AdaptiveGrid` uses — rather than a count computed here, which
            // would freeze the decision at whatever width this happened to be.
            const spacing = LogosSpacing.md;
            return GridView.builder(
              padding: const EdgeInsets.all(LogosSpacing.md),
              itemCount: entries.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                // Same derivation as above, expressed for a width the delegate will
                // choose: an average card is about 320 wide, so the ratio is the ratio
                // for a card of that size.
                childAspectRatio: 320 / (320 * 0.75 + 78),
              ),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _Card(
                  entry: entry,
                  viewModel: viewModel,
                  onOpen: entry.installed
                      ? () => onOpenResource(entry.resource)
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// A library row: cover, title, subtitle, and what can be done with it.
class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.viewModel,
    this.onOpen,
  });

  final LibraryEntry entry;
  final LibraryViewModel viewModel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final resource = entry.resource;
    final progress = viewModel.state.inProgress[resource.id];
    final failure = viewModel.state.failures[resource.id];

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LogosSpacing.md,
          vertical: LogosSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ResourceCover(resource: resource, size: 56),
            const SizedBox(width: LogosSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resourceTitle(resource),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: LogosTypography.navItem
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resourceSubtitle(resource),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: LogosTypography.body.copyWith(
                      fontSize: 12,
                      color: LogosColors.textSecondary,
                    ),
                  ),
                  if (_notice(entry) != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _notice(entry)!,
                      style: LogosTypography.body.copyWith(
                        fontSize: 12,
                        color: LogosColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: LogosSpacing.sm),
            _Action(
              entry: entry,
              progress: progress,
              failure: failure,
              onOpen: onOpen,
              viewModel: viewModel,
            ),
          ],
        ),
      ),
    );
  }
}

/// The same information as [_Row], as a cover card.
class _Card extends StatelessWidget {
  const _Card({
    required this.entry,
    required this.viewModel,
    this.onOpen,
  });

  final LibraryEntry entry;
  final LibraryViewModel viewModel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final resource = entry.resource;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(LogosSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: ResourceCover(resource: resource, size: 108)),
              const SizedBox(height: LogosSpacing.sm),
              Text(
                resourceTitle(resource),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LogosTypography.navItem
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                resourceSubtitle(resource),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LogosTypography.body.copyWith(
                  fontSize: 12,
                  color: LogosColors.textSecondary,
                ),
              ),
              const Spacer(),
              _Action(
                entry: entry,
                progress: viewModel.state.inProgress[resource.id],
                failure: viewModel.state.failures[resource.id],
                onOpen: onOpen,
                viewModel: viewModel,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one-line reason a resource cannot be installed, when there is one.
///
/// Returns null when the row is installable or already installed, so the common case adds
/// no line at all rather than a line saying nothing.
String? _notice(LibraryEntry entry) {
  if (entry.installed) return null;
  final release = entry.releaseDate;
  if (release != null) {
    final date = release.toIso8601String().substring(0, 10);
    return 'Disponible a partir del $date: la obra sigue bajo derechos de autor.';
  }
  if (!entry.hasVerifiableSource) {
    return 'El catálogo aún no publica una suma de verificación para este recurso.';
  }
  return null;
}

/// The action for a row: open it, install it, or say why neither is possible.
class _Action extends StatelessWidget {
  const _Action({
    required this.entry,
    required this.progress,
    required this.failure,
    required this.onOpen,
    required this.viewModel,
    this.compact = false,
  });

  final LibraryEntry entry;
  final InstallProgress? progress;
  final String? failure;
  final VoidCallback? onOpen;
  final LibraryViewModel viewModel;

  /// Grid variant: the label is dropped so the card's fixed height holds.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (progress != null) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (entry.installed) {
      return compact
          ? IconButton(
              tooltip: 'Abrir',
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: onOpen,
            )
          : OutlinedButton(onPressed: onOpen, child: const Text('Abrir'));
    }

    if (!entry.isInstallable) {
      // A disabled control with the reason beside it, rather than no control at all: a
      // missing button is ambiguous between "not for sale", "coming soon" and "broken",
      // and this is a case where the user is owed the difference.
      return Tooltip(
        message: _notice(entry) ?? 'No se puede instalar',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failure != null)
              const Icon(Icons.error_outline, size: 16, color: LogosColors.danger),
            if (failure != null) const SizedBox(width: LogosSpacing.xs),
            Text(
              failure == null ? 'No disponible' : 'Falló',
              style: LogosTypography.body.copyWith(
                fontSize: 12,
                color: failure == null
                    ? LogosColors.textDisabled
                    : LogosColors.danger,
              ),
            ),
          ],
        ),
      );
    }

    return compact
        ? IconButton(
            tooltip: 'Instalar',
            icon: const Icon(Icons.download, size: 18),
            onPressed: () => viewModel.install(entry.resource.id),
          )
        : OutlinedButton(
            onPressed: () => viewModel.install(entry.resource.id),
            child: const Text('Instalar'),
          );
  }
}

/// The library could not be read, and retrying is the only way forward.
///
/// The whole screen rather than a bar, because the failure is in reading the installed
/// tree and there is no partial list to show alongside it.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedReading(
        child: Padding(
          padding: const EdgeInsets.all(LogosSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 40, color: LogosColors.danger),
              const SizedBox(height: LogosSpacing.md),
              const Text('No se pudo abrir la biblioteca',
                  style: LogosTypography.title),
              const SizedBox(height: LogosSpacing.sm),
              Text(
                error,
                textAlign: TextAlign.center,
                style:
                    LogosTypography.body.copyWith(color: LogosColors.textSecondary),
              ),
              const SizedBox(height: LogosSpacing.lg),
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nothing matched, for two quite different reasons.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.query,
    required this.catalogKnown,
    required this.installedCount,
    required this.storeCount,
    required this.onClearSearch,
    required this.onShowStore,
  });

  final LibraryQuery query;
  final bool catalogKnown;
  final int installedCount;

  /// How many resources the store holds, which is what decides whether there is anywhere
  /// to send a user whose own library is empty.
  final int storeCount;
  final VoidCallback onClearSearch;
  final VoidCallback onShowStore;

  @override
  Widget build(BuildContext context) {
    // A search that matched nothing is the common case and the actionable one, so it leads
    // with the way out rather than with an apology.
    final searching = query.hasText;

    return Center(
      child: ConstrainedReading(
        child: Padding(
          padding: const EdgeInsets.all(LogosSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                searching ? Icons.search_off : Icons.library_books_outlined,
                size: 40,
                color: LogosColors.textDisabled,
              ),
              const SizedBox(height: LogosSpacing.md),
              Text(
                searching ? 'Sin resultados' : 'Biblioteca vacía',
                style: LogosTypography.title,
              ),
              const SizedBox(height: LogosSpacing.sm),
              Text(
                _message(),
                textAlign: TextAlign.center,
                style:
                    LogosTypography.body.copyWith(color: LogosColors.textSecondary),
              ),
              if (searching) ...[
                const SizedBox(height: LogosSpacing.lg),
                OutlinedButton(
                  onPressed: onClearSearch,
                  child: const Text('Limpiar la búsqueda'),
                ),
              ],
              // The library opens on `Suyos`, which is what the reference does and which is
              // right for a user with content. For a user with none, that is a dead end
              // with a catalogue full behind it, so the empty state says where to go
              // rather than only reporting that there is nothing here.
              if (!searching &&
                  query.scope == LibraryScope.mine &&
                  storeCount > 0) ...[
                const SizedBox(height: LogosSpacing.lg),
                FilledButton(
                  onPressed: onShowStore,
                  child: Text('Ver los $storeCount recursos disponibles'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _message() {
    if (query.hasText) {
      return 'Ningún recurso de esta biblioteca coincide con «${query.text}». '
          'La búsqueda mira el título y el tipo del recurso.';
    }
    if (!catalogKnown) {
      return 'No hay contenido instalado. Sin un catálogo no hay nada que instalar, '
          'pero los módulos que ya estén en disco siguen disponibles.';
    }
    if (query.scope == LibraryScope.store && installedCount == 0) {
      return 'El catálogo no ofrece ningún recurso instalable. Eso puede ser correcto: '
          'esta compilación solo distribuye obras de dominio público, y de las que '
          'declara ninguna se puede verificar todavía.';
    }
    return 'El catálogo no ofrece ningún recurso. Eso puede ser correcto: esta compilación '
        'solo distribuye obras de dominio público.';
  }
}
