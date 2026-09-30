import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import 'core/layout/adaptive_layout.dart';
import 'core/layout/layout_class.dart';
import 'core/theme/logos_colors.dart';
import 'core/theme/logos_spacing.dart';
import 'core/theme/logos_theme.dart';
import '../domain/models/catalog.dart';
import '../domain/models/workspace_destination.dart';
import '../domain/search/search_results.dart';
import 'features/library/views/library_view.dart';
import 'features/reader/views/bible_reader_view.dart';
import 'features/search/views/search_view.dart';
import 'features/workspace/view_models/workspace_view_model.dart';
import 'features/workspace/views/home_dashboard.dart';
import 'features/workspace/views/resource_workspace.dart';
import 'features/workspace/views/workspace_sidebar.dart';

/// Riverpod supplies the ViewModel, which satisfies the architecture skill's
/// requirement that ViewModels be registered in a DI container while keeping the
/// `ChangeNotifier` + `ListenableBuilder` pattern the skill prescribes.
final workspaceViewModelProvider =
    ChangeNotifierProvider<WorkspaceViewModel>((ref) => WorkspaceViewModel());

class LogosApp extends ConsumerWidget {
  const LogosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Logos',
      debugShowCheckedModeBanner: false,
      theme: buildLogosTheme(),
      home: const WorkspaceShell(),
    );
  }
}

/// The workspace shell.
///
/// One tree for every layout class. The class decides which slots are occupied, not
/// which widget tree is built, so a phone and a desktop cannot drift apart.
class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({super.key});

  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  final _drawerKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(workspaceViewModelProvider);
    final state = vm.state;

    return AdaptiveLayout(
      builder: (context, layoutClass) {
        return Scaffold(
          key: _drawerKey,
          drawer: layoutClass.isCompact ? _drawerBody(vm, state.sidebarCollapsed) : null,
          appBar: _topBar(layoutClass),
          body: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (layoutClass.showsIconRail)
                  IconRail(onPassageSubmitted: _onPassageQuery),
                if (!layoutClass.isCompact) ...[
                  SizedBox(
                    width: state.sidebarCollapsed
                        ? LogosMeasured.sidebarCollapsedWidth
                        : LogosMeasured.sidebarExpandedWidth,
                    child: WorkspaceSidebar(
                      viewModel: vm,
                      collapsed: state.sidebarCollapsed,
                    ),
                  ),
                  const VerticalDivider(
                    width: LogosMeasured.sidebarDividerWidth,
                    color: LogosColors.border,
                  ),
                ],
                if (layoutClass.isCompact) _drawerButton(),
                Expanded(child: _body(vm)),
              ],
            ),
          ),
          bottomNavigationBar:
              layoutClass.showsBottomNav ? WorkspaceBottomNav(viewModel: vm) : null,
        );
      },
    );
  }

  Widget _drawerBody(WorkspaceViewModel vm, bool collapsed) {
    return Drawer(
      backgroundColor: LogosColors.surface,
      child: SafeArea(
        child: WorkspaceSidebar(viewModel: vm, collapsed: collapsed),
      ),
    );
  }

  Widget _drawerButton() {
    return Padding(
      padding: const EdgeInsets.only(left: LogosSpacing.xs, right: LogosSpacing.xs),
      child: IconButton(
        tooltip: 'Abrir navegación',
        icon: const Icon(Icons.menu, color: LogosColors.textSecondary),
        onPressed: () => _drawerKey.currentState?.openDrawer(),
      ),
    );
  }

  Widget _body(WorkspaceViewModel vm) {
    // The workspace occupies the content area; the destinations that are not resource
    // panels render their own surfaces inside it.
    final reader = _readerModuleId;
    if (vm.state.tabs.isNotEmpty) {
      // Checked inside the tabs branch, like the resource path below it: a reader is only
      // shown because a tab is open, so navigating to a destination must take it away
      // again rather than leave the reader covering the screen.
      if (reader != null) {
        return _ReaderPanel(
          moduleId: reader,
          osisCode: _readerPassage?.osisCode,
          chapter: _readerPassage?.chapter,
        );
      }
      final resource = _panelResource;
      if (resource != null && resource.type == ResourceType.bible) {
        return _ReaderPanel(moduleId: resource.id);
      }
      return ResourceWorkspace(viewModel: vm);
    }
    return _destinationSurface(vm);
  }

  Widget _destinationSurface(WorkspaceViewModel vm) {
    return switch (vm.state.destination) {
      WorkspaceDestination.home => const HomeDashboard(),
      WorkspaceDestination.library => LibraryView(
          viewModel: ref.watch(libraryViewModelProvider),
          onOpenResource: _openResource,
        ),
      // Watched rather than read, so the pane rebuilds when the search finishes. The
      // search runs off a keystroke and the ViewModel only announces it by notifying, so
      // a `read` here would leave the user typing into a pane that never answers.
      WorkspaceDestination.search => SearchView(
          viewModel: ref.watch(searchViewModelProvider),
          onOpenResult: _openSearchResult,
        ),
      _ => _PlaceholderSurface(destination: vm.state.destination),
    };
  }

  /// Opens a search result in the reader, at the chapter it names.
  ///
  /// The reader addresses a chapter, not a single verse, so the result lands at the top of
  /// its chapter rather than scrolled to the line. That limit belongs to the reader; the
  /// result knows the exact verse and passes what the reader can act on.
  void _openSearchResult(SearchResult result) {
    final position = result.reference;
    final vm = ref.read(workspaceViewModelProvider);
    vm.openTab(result.moduleId, result.moduleName.isEmpty ? result.label : result.moduleName);
    setState(() {
      _readerModuleId = result.moduleId;
      _readerPassage = (osisCode: position.bookOsis, chapter: position.chapter);
    });
  }

  /// Opens a resource in a tab, choosing the surface that can actually read it.
  ///
  /// A bible goes to the reader because that is the one resource type the reader
  /// implements. Anything else gets the generic panel rather than a reader that would
  /// fail to find the tables it needs — a wrong-but-plausible empty panel is harder to
  /// diagnose than an unimplemented one.
  void _openResource(ResourceDescriptor resource) {
    final vm = ref.read(workspaceViewModelProvider);
    vm.openTab(
        resource.id, resource.shortName.isEmpty ? resource.name : resource.shortName);
    setState(() {
      _panelResource = resource;
      // A search result opened a reader directly; clearing it lets the library own the
      // content area again, which is otherwise left showing the wrong module.
      _readerModuleId = null;
      _readerPassage = null;
    });
  }

  ResourceDescriptor? _panelResource;

  /// The module a search result opened, which takes precedence over [panelResource].
  String? _readerModuleId;

  /// Where in that module the reader should open, when the search named a passage.
  ({String osisCode, int chapter})? _readerPassage;

  PreferredSizeWidget _topBar(LayoutClass layoutClass) {
    return AppBar(
      toolbarHeight: 52,
      backgroundColor: LogosColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: LogosColors.border),
      ),
      titleSpacing: layoutClass.isCompact ? 0 : LogosSpacing.lg,
      title: Row(
        children: [
          Text('Logos',
              style: LogosTypography.title.copyWith(color: LogosColors.primary)),
          if (!layoutClass.isCompact) ...[
            const SizedBox(width: LogosSpacing.md),
            Text('Logos Inicios',
                style: LogosTypography.body.copyWith(color: LogosColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  void _onPassageQuery(String query) {
    final vm = ref.read(workspaceViewModelProvider);
    // A reference opens the reader; anything else opens search. The distinction is the
    // documented behaviour of the `Pasaje o tema` field.
    final looksLikeReference =
        RegExp(r'^[1-3]?\s?[A-Za-záéíóúñ]+\.?\s*\d+').hasMatch(query);
    if (looksLikeReference) {
      vm.openTab('passage-$query', query, accessibilityBadge: true);
    } else {
      vm.goTo(WorkspaceDestination.search);
    }
  }
}

class _PlaceholderSurface extends StatelessWidget {
  const _PlaceholderSurface({required this.destination});

  final WorkspaceDestination destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedReading(
        child: Padding(
          padding: const EdgeInsets.all(LogosSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icon, size: 40, color: LogosColors.textDisabled),
              const SizedBox(height: LogosSpacing.md),
              Text(
                destination.label,
                style: LogosTypography.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LogosSpacing.sm),
              Text(
                'Esta superficie se construye en una fase posterior. '
                'El catálogo aún no está instalado, así que no hay contenido que mostrar.',
                textAlign: TextAlign.center,
                style: LogosTypography.body.copyWith(color: LogosColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hosts the reader for one module.
///
/// Separate from the resource workspace because it replaces the whole content area: a
/// reader needs the full width, and squeezing it beside the tab chrome would leave a
/// column too narrow to read scripture in.
class _ReaderPanel extends ConsumerStatefulWidget {
  const _ReaderPanel({required this.moduleId, this.osisCode, this.chapter});

  final String moduleId;

  /// Where to open, when the caller named a passage rather than just a module.
  final String? osisCode;
  final int? chapter;

  @override
  ConsumerState<_ReaderPanel> createState() => _ReaderPanelState();
}

class _ReaderPanelState extends ConsumerState<_ReaderPanel> {
  @override
  void initState() {
    super.initState();
    // Opening after the first frame, because it notifies listeners and the provider has
    // to be read from a mounted widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(readerViewModelProvider(widget.moduleId).notifier).open(
            widget.moduleId,
            osisCode: widget.osisCode,
            chapter: widget.chapter ?? 1,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(readerViewModelProvider(widget.moduleId));
    return BibleReaderView(viewModel: vm);
  }
}
