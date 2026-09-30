import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/layout/adaptive_layout.dart';
import 'core/layout/layout_class.dart';
import 'core/theme/logos_colors.dart';
import 'core/theme/logos_theme.dart';
import '../domain/models/workspace_destination.dart';
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
          drawer: layoutClass.isCompact
              ? _drawerBody(vm, state.sidebarCollapsed)
              : null,
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
                        ? LogosMetrics.sidebarCollapsedWidth
                        : LogosMetrics.sidebarExpandedWidth,
                    child: WorkspaceSidebar(
                      viewModel: vm,
                      collapsed: state.sidebarCollapsed,
                    ),
                  ),
                  const VerticalDivider(
                    width: LogosMetrics.sidebarDividerWidth,
                    color: LogosColors.border,
                  ),
                ],
                if (layoutClass.isCompact)
                  _drawerButton(),
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
    if (vm.state.tabs.isNotEmpty) return ResourceWorkspace(viewModel: vm);
    return _destinationSurface(vm);
  }

  Widget _destinationSurface(WorkspaceViewModel vm) {
    return switch (vm.state.destination) {
      WorkspaceDestination.home => const HomeDashboard(),
      _ => _PlaceholderSurface(destination: vm.state.destination),
    };
  }

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
          Text('Logos', style: LogosTypography.title.copyWith(color: LogosColors.primary)),
          if (!layoutClass.isCompact) ...[
            const SizedBox(width: LogosSpacing.md),
            Text('Logos Inicios', style: LogosTypography.body.copyWith(color: LogosColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  void _onPassageQuery(String query) {
    final vm = ref.read(workspaceViewModelProvider);
    // A reference opens the reader; anything else opens search. The distinction is the
    // documented behaviour of the `Pasaje o tema` field.
    final looksLikeReference = RegExp(r'^[1-3]?\s?[A-Za-záéíóúñ]+\.?\s*\d+').hasMatch(query);
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
