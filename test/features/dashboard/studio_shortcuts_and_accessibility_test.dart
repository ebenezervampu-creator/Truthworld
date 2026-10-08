import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/dashboard_app_bar_actions.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/dashboard_sidebar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/studio_shortcuts_modal.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('Studio Accessibility & Tooltips Tests', () {
    testWidgets('StudioShortcutsModal displays all global shortcuts and NLE controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StudioShortcutsModal(),
            ),
          ),
        ),
      );

      // Verify header
      expect(find.text('Creator Studio Keyboard Shortcuts'), findsOneWidget);
      expect(find.text('Navigation & Global Actions'), findsOneWidget);
      expect(find.text('Video Player & Timeline Scrubbing (NLE Standard)'), findsOneWidget);

      // Verify specific shortcuts
      expect(find.text('Focus Studio search'), findsOneWidget);
      expect(find.text('Save active draft or form metadata'), findsOneWidget);
      expect(find.text('Play / Pause preview'), findsOneWidget);
      expect(find.text('Rewind 10 seconds (tap repeatedly to scrub backward)'), findsOneWidget);
      expect(find.text('Fast-forward 10 seconds (tap repeatedly to scrub forward)'), findsOneWidget);
      expect(find.text('Seek backward / forward by 5 seconds'), findsOneWidget);
      expect(find.text('Toggle audio mute'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets('DashboardSidebarItem has accessibility semantics and tooltip when collapsed', (tester) async {
      // Expanded state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardSidebarItem(
              icon: Icons.video_library_rounded,
              label: 'Content',
              isSelected: true,
              isDrawerExpanded: true,
              isDarkMode: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Content' && w.properties.button == true,
        ),
        findsOneWidget,
      );
      expect(find.text('Content'), findsOneWidget);

      // Collapsed state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardSidebarItem(
              icon: Icons.video_library_rounded,
              label: 'Content',
              isSelected: false,
              isDrawerExpanded: false,
              isDarkMode: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Content' && w.properties.button == true,
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Content'), findsOneWidget);
    });

    testWidgets('DashboardSidebarHeader collapse button has tooltip and semantics', (tester) async {
      final controller = Get.put(DashboardController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardSidebarHeader(
              controller: controller,
              isDarkMode: true,
            ),
          ),
        ),
      );

      // Initially expanded
      expect(find.byTooltip('Collapse sidebar'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Collapse navigation sidebar' && w.properties.button == true,
        ),
        findsOneWidget,
      );

      // Toggle drawer
      controller.toggleDrawer();
      await tester.pumpAndSettle();

      // Now collapsed
      expect(find.byTooltip('Expand sidebar'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Expand navigation sidebar' && w.properties.button == true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('DashboardSearchField and action buttons have accessibility semantics and tooltips', (tester) async {
      final searchCtrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DashboardSearchField(
                  searchController: searchCtrl,
                  isDarkMode: true,
                ),
                DashboardActionButton(
                  icon: Icons.video_call_rounded,
                  label: 'Create',
                  tooltip: 'Create new content',
                  isPrimary: true,
                  isDarkMode: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Verify search semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Search studio content' && w.properties.textField == true,
        ),
        findsOneWidget,
      );

      // Verify action button semantics & tooltip
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Create new content' && w.properties.button == true,
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Create new content'), findsOneWidget);
    });
  });
}
