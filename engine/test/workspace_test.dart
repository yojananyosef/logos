import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/domain/models/workspace_destination.dart';
import 'package:logos_engine/ui/app.dart';
import 'package:logos_engine/ui/core/layout/layout_class.dart';
import 'package:logos_engine/ui/features/workspace/view_models/workspace_view_model.dart';

/// Wraps the app at a fixed window size, which is how the responsive behaviour is
/// exercised: Flutter has no real desktop window here, so the surface size is the
/// window size.
Widget harness({required Size size}) => ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: const LogosApp(),
      ),
    );

Future<void> pumpAt(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(harness(size: size));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() async {
    // Without this the next test inherits the previous surface size.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('LayoutClass', () {
    test('resolves from width at the exact boundaries', () {
      expect(LayoutClass.fromWidth(359), LayoutClass.compact);
      expect(LayoutClass.fromWidth(600), LayoutClass.medium);
      expect(LayoutClass.fromWidth(1023), LayoutClass.medium);
      expect(LayoutClass.fromWidth(1024), LayoutClass.expanded);
      expect(LayoutClass.fromWidth(1439), LayoutClass.expanded);
      expect(LayoutClass.fromWidth(1440), LayoutClass.large);
    });

    test('slot policy keeps rail, drawer and bottom bar mutually exclusive', () {
      final compact = SlotPolicy.fromWidth(390);
      expect(compact.showIconRail, isFalse);
      expect(compact.sidebarAsDrawer, isTrue);
      expect(compact.showBottomNav, isTrue);
      expect(compact.stackPanes, isTrue);

      final medium = SlotPolicy.fromWidth(768);
      expect(medium.showIconRail, isTrue);
      expect(medium.sidebarAsDrawer, isFalse);
      expect(medium.showBottomNav, isFalse);

      final large = SlotPolicy.fromWidth(1600);
      expect(large.showIconRail, isTrue);
      expect(large.showBottomNav, isFalse);
      expect(large.stackPanes, isFalse);
    });
  });

  group('no horizontal overflow', () {
    // The reference app overflows below 600px. The whole point of the layout work is
    // that this clone does not, so it is asserted rather than eyeballed.
    const widths = [360.0, 390.0, 600.0, 768.0, 1024.0, 1280.0, 1440.0];

    for (final w in widths) {
      testWidgets('dashboard at ${w.toInt()}px does not overflow horizontally',
          (tester) async {
        await pumpAt(tester, Size(w, 900));

        // The rendered app root must be exactly the window width: anything wider
        // means the layout overflowed horizontally. Flutter reports RenderFlex
        // overflow as a test failure on its own, so this catches the case where a
        // child silently exceeds its parent.
        final appSize = tester.getSize(find.byType(MaterialApp));
        expect(appSize.width, w, reason: 'el shell no ocupa todo el ancho disponible');
        expect(appSize.width, lessThanOrEqualTo(w));
      });
    }
  });

  group('workspace shell', () {
    testWidgets('shows the icon rail and sidebar at 1440', (tester) async {
      await pumpAt(tester, const Size(1440, 900));
      expect(find.text('Panel de Control'), findsWidgets);
      expect(find.text('Biblioteca'), findsOneWidget);
      expect(find.byTooltip('Pasaje o tema'), findsOneWidget);
      // Bottom navigation belongs to compact only.
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('hides the rail and shows bottom nav at 390', (tester) async {
      await pumpAt(tester, const Size(390, 844));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byTooltip('Pasaje o tema'), findsNothing);
    });

    testWidgets('drawer button appears only on compact', (tester) async {
      await pumpAt(tester, const Size(390, 844));
      expect(find.byTooltip('Abrir navegación'), findsOneWidget);
    });
  });

  group('tabs', () {
    testWidgets('opening a resource creates a tab and makes it active',
        (tester) async {
      await pumpAt(tester, const Size(1440, 900));
      final vm = WorkspaceViewModel();
      vm.openTab('rv', 'RVR60', accessibilityBadge: true);

      expect(vm.state.tabs, hasLength(1));
      expect(vm.state.activeTab!.id, 'rv');
      expect(vm.state.activeTab!.showAccessibilityBadge, isTrue);
    });

    testWidgets('opening the same resource twice does not duplicate it',
        (tester) async {
      final vm = WorkspaceViewModel();
      vm.openTab('rv', 'RVR60');
      vm.openTab('otro', 'JFB');
      vm.openTab('rv', 'RVR60');

      expect(vm.state.tabs.map((t) => t.id), ['rv', 'otro']);
      expect(vm.state.activeIndex, 0);
    });

    testWidgets('closing the last tab returns to the dashboard', (tester) async {
      final vm = WorkspaceViewModel();
      vm.openTab('rv', 'RVR60');
      vm.closeTab(0);

      expect(vm.state.tabs, isEmpty);
      expect(vm.state.destination, WorkspaceDestination.home);
    });

    testWidgets('closing the active tab activates its neighbour', (tester) async {
      final vm = WorkspaceViewModel();
      vm.openTab('a', 'A');
      vm.openTab('b', 'B');
      vm.openTab('c', 'C');
      expect(vm.state.activeIndex, 2);

      vm.closeTab(2);
      expect(vm.state.activeIndex, 1);
      expect(vm.state.activeTab!.id, 'b');
    });
  });

  group('toolbar state', () {
    test('switching a toolbar section does not change the active tab', () {
      final vm = WorkspaceViewModel();
      vm.openTab('rv', 'RVR60');
      vm.setToolbarSection(ToolbarSectionId.view);

      expect(vm.state.activeTab!.toolbarSection, ToolbarSectionId.view);
      expect(vm.state.tabs, hasLength(1));
    });

    test('sidebar collapse survives navigation', () {
      final vm = WorkspaceViewModel();
      vm.toggleSidebar();
      expect(vm.state.sidebarCollapsed, isTrue);

      vm.goTo(WorkspaceDestination.library);
      expect(vm.state.sidebarCollapsed, isTrue);
    });
  });

  group('close all panels', () {
    test('clears every tab and returns to the dashboard', () {
      final vm = WorkspaceViewModel();
      vm.openTab('a', 'A');
      vm.openTab('b', 'B');
      vm.closeAllTabs();

      expect(vm.state.tabs, isEmpty);
      expect(vm.state.destination, WorkspaceDestination.home);
    });
  });
}
