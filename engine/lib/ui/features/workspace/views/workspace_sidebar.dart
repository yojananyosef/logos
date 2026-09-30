import 'package:flutter/material.dart';

import '../../../core/components/nav_item.dart';
import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';
import '../../../../domain/models/workspace_destination.dart';
import '../view_models/workspace_view_model.dart';

/// The sidebar: nine destinations, the quick-actions section, and the footer.
///
/// On compact layouts the same content is hosted in an overlay drawer rather than
/// being replaced, so there is one implementation and no drift between the two.
class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.viewModel,
    required this.collapsed,
  });

  final WorkspaceViewModel viewModel;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Navegación principal',
      child: Material(
        color: LogosColors.surface,
        // Scrollable rather than a fixed Column: nine destinations plus five quick
        // actions plus the footer exceed a 900px-tall window, and a sidebar that
        // overflows makes the footer controls unreachable.
        child: ListView(
          padding: const EdgeInsets.only(bottom: LogosSpacing.sm),
          children: [
            _destinations(),
            if (!collapsed) ...[
              const _SectionDivider(),
              _quickActions(),
            ],
            const _SidebarDivider(),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _destinations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in WorkspaceDestination.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.xs, vertical: 1),
            child: NavItem(
              label: d.label,
              icon: d.icon,
              collapsed: collapsed,
              active: viewModel.state.destination == d,
              onTap: () => viewModel.goTo(d),
            ),
          ),
      ],
    );
  }

  Widget _quickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
              LogosSpacing.lg, LogosSpacing.md, LogosSpacing.lg, LogosSpacing.sm),
          child: Text('ACCIONES RÁPIDAS', style: LogosTypography.sectionLabel),
        ),
        for (final a in QuickAction.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.xs, vertical: 1),
            child: NavItem(
              label: a.label,
              icon: a.icon,
              collapsed: collapsed,
              active: false,
              onTap: () => _runQuickAction(a),
            ),
          ),
      ],
    );
  }

  /// Quick actions open a resource. Until real catalogs are installed, the shell still
  /// exercises the tab mechanics so the interaction is verifiable.
  void _runQuickAction(QuickAction action) {
    switch (action) {
      case QuickAction.compareVersions:
        viewModel.openTab('compare', 'Comparar versiones');
      case QuickAction.openDevotional:
        viewModel.openTab('devotional', 'Devocional de hoy');
      default:
        viewModel.openTab(action.name, action.label);
    }
  }

  Widget _footer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in const [
          ('Centro de ayuda', Icons.help_outline),
          ('Entornos', Icons.vertical_split_outlined),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.xs, vertical: 1),
            child: NavItem(
              label: entry.$1,
              icon: entry.$2,
              collapsed: collapsed,
              active: false,
              onTap: () {},
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.xs, vertical: 1),
          child: NavItem(
            label: 'Cerrar todos los paneles',
            icon: Icons.close_fullscreen_outlined,
            collapsed: collapsed,
            active: false,
            onTap: viewModel.closeAllTabs,
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: LogosSpacing.sm),
        child: Divider(height: 1, color: LogosColors.border),
      );
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: LogosMeasured.sidebarDividerWidth,
        color: LogosColors.border,
      );
}

/// The 48dp icon rail carrying the global `Pasaje o tema` field.
class IconRail extends StatelessWidget {
  const IconRail({super.key, required this.onPassageSubmitted});

  final void Function(String query) onPassageSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: LogosMeasured.iconRailWidth,
      color: LogosColors.surface,
      child: Column(
        children: [
          const SizedBox(height: LogosSpacing.sm),
          const Icon(Icons.church, color: LogosColors.primary, size: 22),
          const SizedBox(height: LogosSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.zero,
              // A 48dp rail cannot host a readable text field, so the field is a
              // button that opens a dialog. Reporting the constraint beats rendering
              // an unusable input.
              child: IconButton(
                tooltip: 'Pasaje o tema',
                icon: const Icon(Icons.search, color: LogosColors.textSecondary),
                onPressed: () => _prompt(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _prompt(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pasaje o tema'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Jn 3:16  ·  o un tema',
            helperText: 'Una referencia abre el lector; un tema abre la búsqueda.',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Abrir')),
        ],
      ),
    );
    if (value != null && value.trim().isNotEmpty) onPassageSubmitted(value.trim());
  }
}

/// Compact bottom navigation. The rail and the expanded sidebar are absent at this
/// class, so the nine destinations need somewhere else to live.
class WorkspaceBottomNav extends StatelessWidget {
  const WorkspaceBottomNav({super.key, required this.viewModel});

  final WorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final current = viewModel.state.destination;
    return NavigationBar(
      selectedIndex: current.index,
      onDestinationSelected: (i) => viewModel.goTo(WorkspaceDestination.values[i]),
      backgroundColor: LogosColors.surface,
      indicatorColor: LogosColors.surfaceHover,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: [
        for (final d in WorkspaceDestination.values)
          NavigationDestination(
            icon: Icon(d.icon),
            label: _shortLabel(d),
            tooltip: d.label,
          ),
      ],
    );
  }

  /// Full labels do not fit nine destinations on a narrow bar; the tooltip and the
  /// semantics label keep the full name available.
  static String _shortLabel(WorkspaceDestination d) => switch (d) {
        WorkspaceDestination.home => 'Inicio',
        WorkspaceDestination.library => 'Biblioteca',
        WorkspaceDestination.search => 'Buscar',
        WorkspaceDestination.bible => 'Biblia',
        WorkspaceDestination.studyAssistant => 'Asistente',
        WorkspaceDestination.encyclopedia => 'Enciclopedia',
        WorkspaceDestination.guides => 'Guías',
        WorkspaceDestination.notes => 'Notas',
        WorkspaceDestination.tools => 'Herramientas',
      };
}
