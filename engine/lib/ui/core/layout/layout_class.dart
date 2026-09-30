import 'package:flutter/widgets.dart';

/// The four layout classes. Resolved from available width, never from device type —
/// the app runs in resizable windows and picture-in-picture, so hardware identity is
/// not a usable signal.
enum LayoutClass {
  /// < 600 — compact chrome, single column, bottom navigation, drawer sidebar.
  compact,

  /// 600–1023 — collapsible sidebar, single content column, 2-column cards.
  medium,

  /// 1024–1439 — full sidebar, 3-column cards, side-by-side panes.
  expanded,

  /// >= 1440 — the 1:1 reference layout.
  large;

  static const double mediumMin = 600;
  static const double expandedMin = 1024;
  static const double largeMin = 1440;

  /// Pure: the same width always yields the same class.
  static LayoutClass fromWidth(double width) {
    if (width >= largeMin) return LayoutClass.large;
    if (width >= expandedMin) return LayoutClass.expanded;
    if (width >= mediumMin) return LayoutClass.medium;
    return LayoutClass.compact;
  }

  bool get isCompact => this == LayoutClass.compact;
  bool get isStacked => this == LayoutClass.compact || this == LayoutClass.medium;
  bool get hasFullSidebar => this == LayoutClass.expanded || this == LayoutClass.large;
  bool get showsBottomNav => this == LayoutClass.compact;
  bool get showsIconRail => this != LayoutClass.compact;

  /// Columns for a card grid. `large` grows with available width instead of capping,
  /// which is why it reports null and the grid uses a max-extent delegate.
  int? get gridColumns => switch (this) {
        LayoutClass.compact => 1,
        LayoutClass.medium => 2,
        LayoutClass.expanded => 3,
        LayoutClass.large => null,
      };
}

/// Which chrome occupies which slot. Resolving the competition between the rail, the
/// sidebar and the bottom bar is the whole point — on a phone all three want the same
/// nine destinations, and only an explicit policy keeps them from colliding.
@immutable
class SlotPolicy {
  const SlotPolicy({
    required this.layoutClass,
    required this.showIconRail,
    required this.sidebarAsDrawer,
    required this.showBottomNav,
    required this.stackPanes,
  });

  final LayoutClass layoutClass;
  final bool showIconRail;
  final bool sidebarAsDrawer;
  final bool showBottomNav;
  final bool stackPanes;

  factory SlotPolicy.of(LayoutClass c) => SlotPolicy(
        layoutClass: c,
        showIconRail: c.showsIconRail,
        sidebarAsDrawer: c == LayoutClass.compact,
        showBottomNav: c.showsBottomNav,
        stackPanes: c.isStacked,
      );

  static SlotPolicy fromWidth(double width) => SlotPolicy.of(LayoutClass.fromWidth(width));
}
