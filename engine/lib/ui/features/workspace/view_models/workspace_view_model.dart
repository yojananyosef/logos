import 'package:flutter/foundation.dart';

import '../../../../domain/models/workspace_destination.dart';

/// One open resource tab.
@immutable
class WorkspaceTab {
  const WorkspaceTab({
    required this.id,
    required this.title,
    this.showAccessibilityBadge = false,
    this.toolbarSection = ToolbarSectionId.home,
    this.subSection,
  });

  final String id;
  final String title;

  /// The reference shows an `A` badge for resources in limited view mode.
  final bool showAccessibilityBadge;
  final ToolbarSectionId toolbarSection;
  final SubToolbarSectionId? subSection;

  WorkspaceTab copyWith({
    String? title,
    ToolbarSectionId? toolbarSection,
    SubToolbarSectionId? subSection,
  }) =>
      WorkspaceTab(
        id: id,
        title: title ?? this.title,
        showAccessibilityBadge: showAccessibilityBadge,
        toolbarSection: toolbarSection ?? this.toolbarSection,
        subSection: subSection ?? this.subSection,
      );

  @override
  bool operator ==(Object other) =>
      other is WorkspaceTab &&
      other.id == id &&
      other.title == title &&
      other.toolbarSection == toolbarSection &&
      other.subSection == subSection;

  @override
  int get hashCode => Object.hash(id, title, toolbarSection, subSection);
}

/// The single source of truth for the workspace: which tabs are open, which is
/// active, and how the panes are split.
///
/// This lives in one place rather than in the route tree because the reference's URLs
/// carry the whole arrangement, and a back gesture has to move through it. [snapshot]
/// exists for exactly that serialisation.
@immutable
class WorkspaceState {
  const WorkspaceState({
    this.tabs = const [],
    this.activeIndex = 0,
    this.destination = WorkspaceDestination.home,
    this.sidebarCollapsed = false,
    this.splitFractions = const [0.5, 0.5],
    this.splitActive = 0,
  });

  final List<WorkspaceTab> tabs;
  final int activeIndex;
  final WorkspaceDestination destination;
  final bool sidebarCollapsed;

  /// Fractions of the content width per pane. One entry means unsplit.
  final List<double> splitFractions;
  final int splitActive;

  bool get isEmpty => tabs.isEmpty;
  WorkspaceTab? get activeTab =>
      tabs.isEmpty || activeIndex >= tabs.length ? null : tabs[activeIndex];

  WorkspaceState copyWith({
    List<WorkspaceTab>? tabs,
    int? activeIndex,
    WorkspaceDestination? destination,
    bool? sidebarCollapsed,
    List<double>? splitFractions,
    int? splitActive,
  }) =>
      WorkspaceState(
        tabs: tabs ?? this.tabs,
        activeIndex: activeIndex ?? this.activeIndex,
        destination: destination ?? this.destination,
        sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
        splitFractions: splitFractions ?? this.splitFractions,
        splitActive: splitActive ?? this.splitActive,
      );

  /// A compact, URL-safe encoding of the arrangement.
  ///
  /// Kept short on purpose: an over-long query string breaks navigation on some
  /// platforms, and the fallback is to load defaults rather than to fail.
  String snapshot() {
    final tabIds = tabs.map((t) => t.id).join(',');
    return '${destination.name}|$activeIndex|$tabIds|'
        '${splitFractions.map((f) => f.toStringAsFixed(2)).join('-')}';
  }
}

/// ViewModel for the workspace shell.
///
/// Follows the architecture skill: a `ChangeNotifier` that owns presentation state and
/// commands, with no widget logic and no data access. Riverpod supplies it as the
/// dependency-injection container.
class WorkspaceViewModel extends ChangeNotifier {
  WorkspaceViewModel();

  WorkspaceState _state = const WorkspaceState();
  WorkspaceState get state => _state;

  // --- navigation ---

  void goTo(WorkspaceDestination destination) {
    if (_state.destination == destination) return;
    _state = _state.copyWith(destination: destination);
    notifyListeners();
  }

  // --- tabs ---

  /// Opens [id], or activates it when already open. The reference never shows the same
  /// resource twice, and duplicating it would desynchronise the two readers.
  void openTab(String id, String title, {bool accessibilityBadge = false}) {
    final existing = _state.tabs.indexWhere((t) => t.id == id);
    if (existing >= 0) {
      _state = _state.copyWith(activeIndex: existing);
      notifyListeners();
      return;
    }
    final tabs = [
      ..._state.tabs,
      WorkspaceTab(id: id, title: title, showAccessibilityBadge: accessibilityBadge)
    ];
    _state = _state.copyWith(tabs: tabs, activeIndex: tabs.length - 1);
    notifyListeners();
  }

  void closeTab(int index) {
    if (index < 0 || index >= _state.tabs.length) return;
    final tabs = [..._state.tabs]..removeAt(index);
    // Closing the last tab returns to the dashboard, as the reference does.
    final active = tabs.isEmpty
        ? 0
        : (index < _state.activeIndex ? _state.activeIndex - 1 : _state.activeIndex)
            .clamp(0, tabs.length - 1);
    _state = _state.copyWith(
      tabs: tabs,
      activeIndex: active,
      destination: tabs.isEmpty ? WorkspaceDestination.home : _state.destination,
    );
    notifyListeners();
  }

  void activateTab(int index) {
    if (index == _state.activeIndex) return;
    if (index < 0 || index >= _state.tabs.length) return;
    _state = _state.copyWith(activeIndex: index);
    notifyListeners();
  }

  void closeAllTabs() {
    if (_state.tabs.isEmpty) return;
    _state = _state.copyWith(
      tabs: const [],
      activeIndex: 0,
      destination: WorkspaceDestination.home,
      splitFractions: const [0.5, 0.5],
    );
    notifyListeners();
  }

  // --- toolbar ---

  void setToolbarSection(ToolbarSectionId section) {
    final tab = _state.activeTab;
    if (tab == null || tab.toolbarSection == section) return;
    final tabs = [..._state.tabs];
    tabs[_state.activeIndex] = tab.copyWith(toolbarSection: section);
    _state = _state.copyWith(tabs: tabs);
    notifyListeners();
  }

  void setSubSection(SubToolbarSectionId section) {
    final tab = _state.activeTab;
    if (tab == null) return;
    final tabs = [..._state.tabs];
    tabs[_state.activeIndex] = tab.copyWith(subSection: section);
    _state = _state.copyWith(tabs: tabs);
    notifyListeners();
  }

  // --- layout ---

  /// Collapsed state persists for the session: the reference does not forget it when
  /// the user navigates, and neither do we.
  void toggleSidebar() {
    _state = _state.copyWith(sidebarCollapsed: !_state.sidebarCollapsed);
    notifyListeners();
  }

  void setSplitFractions(List<double> fractions) {
    if (fractions.length != _state.splitFractions.length) return;
    _state = _state.copyWith(splitFractions: fractions);
    notifyListeners();
  }

  void setSplitActive(int index) {
    if (index == _state.splitActive) return;
    _state = _state.copyWith(splitActive: index);
    notifyListeners();
  }
}
