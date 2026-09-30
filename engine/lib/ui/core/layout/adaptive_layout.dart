import 'package:flutter/material.dart';

import '../theme/logos_colors.dart';
import 'layout_class.dart';

/// Resolves [LayoutClass] from the space actually available to the workspace, and
/// publishes it to descendants.
///
/// Built on [LayoutBuilder] rather than a top-level [MediaQuery] read, so a widget
/// that changes the available width — a split pane closing, a drawer opening — gets
/// the class for the space it really has. Descendants read the inherited value
/// instead of measuring the screen, so no widget can disagree about the class.
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({super.key, required this.builder});

  final Widget Function(BuildContext context, LayoutClass layoutClass) builder;

  static LayoutClass of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_LayoutScope>();
    assert(scope != null, 'No AdaptiveLayout found in context');
    return scope!.layoutClass;
  }

  /// Convenience for widgets that only need the class, without a rebuild.
  static LayoutClass read(BuildContext context) => of(context);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutClass = LayoutClass.fromWidth(constraints.maxWidth);
        return _LayoutScope(
          layoutClass: layoutClass,
          policy: SlotPolicy.of(layoutClass),
          child: Builder(builder: (context) => builder(context, layoutClass)),
        );
      },
    );
  }
}

class _LayoutScope extends InheritedWidget {
  const _LayoutScope({
    required this.layoutClass,
    required this.policy,
    required super.child,
  });

  final LayoutClass layoutClass;
  final SlotPolicy policy;

  @override
  bool updateShouldNotify(_LayoutScope old) =>
      old.layoutClass != layoutClass || old.policy != policy;
}

/// A grid whose column count follows the layout class.
///
/// `large` defers to a max-extent delegate so columns grow with the window instead of
/// capping at three and leaving a very wide screen mostly empty.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = LogosSpacing.md,
    this.maxColumnExtent = 340,
  });

  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double maxColumnExtent;

  @override
  Widget build(BuildContext context) {
    final layoutClass = AdaptiveLayout.of(context);
    final columns = layoutClass.gridColumns;

    if (columns == null) {
      return GridView.builder(
        padding: const EdgeInsets.all(LogosSpacing.lg),
        itemCount: itemCount,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxColumnExtent,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemBuilder: itemBuilder,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(LogosSpacing.lg),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemBuilder: itemBuilder,
    );
  }
}

/// Constrains long-form content to a readable measure and centres it, so text does
/// not stretch across an ultrawide window.
class ConstrainedReading extends StatelessWidget {
  const ConstrainedReading({
    super.key,
    required this.child,
    this.maxWidth = LogosMetrics.maxReadingMeasure,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
