import 'package:flutter/material.dart';

import '../../../core/components/nav_item.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_theme.dart';
import '../../../../domain/models/workspace_destination.dart';
import '../view_models/workspace_view_model.dart';

/// The tab strip, the per-tab toolbar, the sub-toolbar and the resource header.
///
/// The four are one widget because they are one object in the reference: a tab and
/// everything that hangs off it. Splitting them would let the header outlive its tab.
class ResourceWorkspace extends StatelessWidget {
  const ResourceWorkspace({super.key, required this.viewModel});

  final WorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final tab = state.activeTab;

    if (tab == null) return const _NoTabSelected();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TabStrip(viewModel: viewModel),
        const Divider(height: 1, color: LogosColors.border),
        _Toolbar(viewModel: viewModel, tab: tab),
        const Divider(height: 1, color: LogosColors.border),
        _SubToolbar(viewModel: viewModel, tab: tab),
        const Divider(height: 1, color: LogosColors.border),
        Expanded(
          child: AdaptiveLayout(
            builder: (context, layoutClass) {
              return _ResourceBody(
                viewModel: viewModel,
                stacked: layoutClass.isStacked,
                splitFractions: state.splitFractions,
                onSplitChanged: viewModel.setSplitFractions,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NoTabSelected extends StatelessWidget {
  const _NoTabSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedReading(
        child: Padding(
          padding: const EdgeInsets.all(LogosSpacing.xl),
          child: Text(
            'Abra un recurso para comenzar.',
            textAlign: TextAlign.center,
            style: LogosTypography.body.copyWith(color: LogosColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.viewModel});

  final WorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final tabs = viewModel.state.tabs;
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final active = index == viewModel.state.activeIndex;
          return _Tab(
            tab: tab,
            active: active,
            onTap: () => viewModel.activateTab(index),
            onClose: () => viewModel.closeTab(index),
          );
        },
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final WorkspaceTab tab;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      label: '${tab.title}${tab.showAccessibilityBadge ? ', vista limitada' : ''}',
      child: Material(
        color: active ? LogosColors.surface : LogosColors.surfaceSunken,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: LogosColors.minTouchTarget),
            padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.md),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? LogosColors.primary : LogosColors.border,
                  width: LogosMetrics.activeIndicatorHeight,
                ),
                right: const BorderSide(color: LogosColors.border),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tab.title,
                  style: LogosTypography.navItem.copyWith(
                    color: active ? LogosColors.primary : LogosColors.textSecondary,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (tab.showAccessibilityBadge) ...[
                  const SizedBox(width: LogosSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: LogosColors.infoPill,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text('A', style: LogosTypography.verseNumber),
                  ),
                ],
                const SizedBox(width: LogosSpacing.xs),
                // 44dp close target even though the glyph is small.
                SizedBox(
                  width: LogosColors.minTouchTarget,
                  height: LogosColors.minTouchTarget,
                  child: IconButton(
                    tooltip: 'Cerrar ${tab.title}',
                    padding: EdgeInsets.zero,
                    iconSize: 14,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, color: LogosColors.textMuted),
                    onPressed: onClose,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.viewModel, required this.tab});

  final WorkspaceViewModel viewModel;
  final WorkspaceTab tab;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.sm),
        children: [
          for (final s in ToolbarSectionId.values)
            ToolbarSection(
              label: s.label,
              active: tab.toolbarSection == s,
              onTap: () => viewModel.setToolbarSection(s),
            ),
        ],
      ),
    );
  }
}

class _SubToolbar extends StatelessWidget {
  const _SubToolbar({required this.viewModel, required this.tab});

  final WorkspaceViewModel viewModel;
  final WorkspaceTab tab;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.sm),
        children: [
          for (final s in SubToolbarSectionId.values)
            ToolbarSection(
              label: s.label,
              active: tab.subSection == s,
              onTap: () => viewModel.setSubSection(s),
            ),
        ],
      ),
    );
  }
}

/// The resource body. Stacked on compact and medium, side by side above that.
///
/// The drag handle exists only when the panes are actually side by side: a horizontal
/// handle between two vertically stacked panes would be a lie about what it does.
class _ResourceBody extends StatefulWidget {
  const _ResourceBody({
    required this.viewModel,
    required this.stacked,
    required this.splitFractions,
    required this.onSplitChanged,
  });

  final WorkspaceViewModel viewModel;
  final bool stacked;
  final List<double> splitFractions;
  final void Function(List<double>) onSplitChanged;

  @override
  State<_ResourceBody> createState() => _ResourceBodyState();
}

class _ResourceBodyState extends State<_ResourceBody> {
  @override
  Widget build(BuildContext context) {
    final panes = [
      for (var i = 0; i < widget.splitFractions.length; i++)
        Expanded(flex: (widget.splitFractions[i] * 1000).round(), child: _Pane(index: i)),
    ];

    final children = <Widget>[];
    for (var i = 0; i < panes.length; i++) {
      children.add(panes[i]);
      if (!widget.stacked && i < panes.length - 1) {
        children.add(_DragHandle(onChanged: widget.onSplitChanged));
      }
    }

    if (widget.stacked) {
      return Column(children: children);
    }
    return Row(children: children);
  }
}

class _DragHandle extends StatefulWidget {
  const _DragHandle({required this.onChanged});

  final void Function(List<double>) onChanged;

  @override
  State<_DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<_DragHandle> {
  double _startFraction = 0.5;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() {}),
        onHorizontalDragUpdate: (d) {
          final width = context.size?.width ?? 1;
          final delta = (d.delta.dx / width).clamp(-0.25, 0.25);
          final next = (_startFraction + delta).clamp(0.2, 0.8);
          _startFraction = next;
          widget.onChanged([next, 1 - next]);
        },
        child: const SizedBox(
          width: 5,
          child: ColoredBox(color: LogosColors.border),
        ),
      ),
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: Text(
          'Panel ${index + 1}',
          style: LogosTypography.body.copyWith(color: LogosColors.textTertiary),
        ),
      ),
    );
  }
}
