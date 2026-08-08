import 'package:drawer_rail/drawer_rail.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DrawerBadge', () {
    test('text badge exposes its label and is not a count', () {
      const badge = DrawerBadge.text('New');
      expect(badge.label, 'New');
      expect(badge.isCount, isFalse);
    });

    test('count badge hides when zero and clamps above 99', () {
      expect(const DrawerBadge.count(0).label, isNull);
      expect(const DrawerBadge.count(4).label, '4');
      expect(const DrawerBadge.count(150).label, '99+');
      expect(const DrawerBadge.count(4).isCount, isTrue);
    });
  });

  group('DrawerRailController', () {
    test('notifies on collapse, selection and group toggles', () {
      final controller = DrawerRailController();
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.toggleCollapsed();
      expect(controller.collapsed, isTrue);

      controller.select('a');
      expect(controller.selectedId, 'a');

      controller.toggleGroup('g');
      expect(controller.isGroupExpanded('g'), isTrue);

      expect(notifications, 3);
    });

    test('does not notify when setting the same value', () {
      final controller = DrawerRailController(collapsed: true);
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.setCollapsed(true);

      expect(notifications, 0);
    });
  });

  group('DrawerRail widget', () {
    late DrawerRailController controller;

    setUp(() => controller = DrawerRailController());
    tearDown(() => controller.dispose());

    List<DrawerEntry> entries() => [
          const DrawerSection('Main'),
          DrawerLink(
            id: 'home',
            icon: Icons.home,
            label: 'Home',
            onTap: (_) {},
          ),
          DrawerLink(
            id: 'settings',
            icon: Icons.settings,
            label: 'Settings',
            onTap: (_) {},
          ),
        ];

    testWidgets('renders entries and selects on tap', (tester) async {
      await tester.pumpWidget(
        _wrap(DrawerRail(controller: controller, entries: entries())),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(controller.selectedId, 'settings');
    });

    testWidgets('collapses to the rail and hides labels', (tester) async {
      await tester.pumpWidget(
        _wrap(DrawerRail(controller: controller, entries: entries())),
      );

      controller.setCollapsed(true);
      await tester.pumpAndSettle();

      // Labels are replaced by tooltips in the rail.
      expect(find.text('Home'), findsNothing);
      expect(find.byIcon(Icons.home), findsOneWidget);
    });

    testWidgets('search filters entries', (tester) async {
      await tester.pumpWidget(
        _wrap(DrawerRail(controller: controller, entries: entries())),
      );

      await tester.enterText(find.byType(TextField), 'sett');
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('showSearch:false hides the search field and rail button',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DrawerRail(
            controller: controller,
            entries: entries(),
            showSearch: false,
          ),
        ),
      );

      // No search field in the expanded panel.
      expect(find.byType(TextField), findsNothing);

      // No search button in the collapsed rail either.
      controller.setCollapsed(true);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search_rounded), findsNothing);
    });

    // The unhovered card must never paint a shadow, whichever effect is set —
    // this guards against a shadow bleeding through as a colored haze.
    bool anyPressCardHasShadow(WidgetTester tester) {
      for (final c in tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(AnimatedPressCard),
          matching: find.byType(AnimatedContainer),
        ),
      )) {
        final deco = c.decoration;
        if (deco is BoxDecoration && (deco.boxShadow?.isNotEmpty ?? false)) {
          return true;
        }
      }
      return false;
    }

    testWidgets('hoverEffect.none never paints a hover shadow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DrawerRail(
            controller: controller,
            entries: entries(),
            theme: const DrawerRailTheme(hoverEffect: DrawerHoverEffect.none),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(anyPressCardHasShadow(tester), isFalse);
    });

    testWidgets('hoverEffect.highlight never paints a hover shadow',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DrawerRail(
            controller: controller,
            entries: entries(),
            theme: const DrawerRailTheme(
              hoverEffect: DrawerHoverEffect.highlight,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(anyPressCardHasShadow(tester), isFalse);
    });

    testWidgets('applies custom theme icons and section casing',
        (tester) async {
      controller.setCollapsed(true);
      await tester.pumpWidget(
        _wrap(
          DrawerRail(
            controller: controller,
            entries: entries(),
            theme: const DrawerRailTheme(
              expandIcon: Icons.arrow_forward,
              sectionUppercase: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Custom expand icon is used in the collapsed rail header.
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('keeps original section casing when uppercase is off',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DrawerRail(
            controller: controller,
            entries: entries(),
            theme: const DrawerRailTheme(sectionUppercase: false),
          ),
        ),
      );

      expect(find.text('Main'), findsOneWidget);
      expect(find.text('MAIN'), findsNothing);
    });

    testWidgets('supports app-owned link content and group trailing content',
        (tester) async {
      controller.toggleGroup('sources');
      var tailTaps = 0;
      await tester.pumpWidget(
        _wrap(
          DrawerRail(
            controller: controller,
            showSearch: false,
            showCollapseButton: false,
            entries: [
              DrawerGroup(
                id: 'sources',
                key: const ValueKey('sources-group'),
                label: 'Sources',
                arrowPlacement: DrawerGroupArrowPlacement.afterLabel,
                trailingBuilder: (_, __) => IconButton(
                  key: const ValueKey('add-source'),
                  onPressed: () => tailTaps++,
                  icon: const Icon(Icons.add),
                ),
                children: [
                  DrawerLink(
                    id: 'source-a',
                    icon: Icons.storage_outlined,
                    label: 'Source A',
                    onTap: (_) {},
                    expandedBuilder: (_, selected) => Text(
                      'Custom source: $selected',
                      key: const ValueKey('custom-source-row'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(const ValueKey('sources-group')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-source')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-source-row')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('add-source')));
      await tester.pump();

      expect(tailTaps, 1);
      expect(controller.isGroupExpanded('sources'), isTrue);
    });

    testWidgets('uses the same configured highlight for links and groups',
        (tester) async {
      const highlight = Colors.red;
      await tester.pumpWidget(
        _wrap(
          DrawerRail(
            controller: controller,
            showSearch: false,
            showCollapseButton: false,
            theme: const DrawerRailTheme(
              hoverEffect: DrawerHoverEffect.highlight,
              hoverHighlightColor: highlight,
              groupOuterPadding: EdgeInsets.symmetric(horizontal: 4),
              groupPadding: EdgeInsets.symmetric(horizontal: 12),
              groupHeight: 32,
              groupLabelTextStyle: TextStyle(fontSize: 15),
            ),
            entries: [
              DrawerLink(
                id: 'home',
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: (_) {},
              ),
              const DrawerGroup(
                id: 'sources',
                key: ValueKey('hoverable-group'),
                label: 'Sources',
                children: [],
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const ValueKey('hoverable-group'))).height,
        32,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(find.text('Home')));
      await tester.pump(const Duration(milliseconds: 220));
      expect(_hasAnimatedFill(tester, highlight), isTrue);

      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('hoverable-group'))),
      );
      await tester.pump(const Duration(milliseconds: 220));
      expect(_hasAnimatedFill(tester, highlight), isTrue);
    });

    testWidgets('can defer selection until app navigation succeeds',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DrawerRail(
            controller: controller,
            entries: [
              DrawerLink(
                id: 'remote',
                icon: Icons.cloud_outlined,
                label: 'Remote',
                selectOnTap: false,
                onTap: (_) {},
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Remote'));
      await tester.pumpAndSettle();

      expect(controller.selectedId, isNull);
    });

    // Finds the drawer's own outer container: the one whose border radius has
    // a single rounded side (the AnimatedPressCard containers round all sides).
    BorderRadius drawerEdgeRadius(WidgetTester tester) {
      for (final c in tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      )) {
        final deco = c.decoration;
        if (deco is BoxDecoration && deco.borderRadius is BorderRadius) {
          final br = deco.borderRadius! as BorderRadius;
          if (br.topLeft != br.topRight) return br;
        }
      }
      fail('drawer outer container not found');
    }

    testWidgets('rounds the right edge when positioned left', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DrawerRail(
            controller: controller,
            entries: entries(),
            theme: const DrawerRailTheme(borderRadius: 24),
          ),
        ),
      );

      final br = drawerEdgeRadius(tester);
      expect(br.topRight, const Radius.circular(24));
      expect(br.bottomRight, const Radius.circular(24));
      expect(br.topLeft, Radius.zero);
      expect(br.bottomLeft, Radius.zero);
    });

    testWidgets('rounds the left edge when positioned right', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DrawerRail(
            controller: controller,
            entries: entries(),
            theme: const DrawerRailTheme(
              borderRadius: 24,
              position: DrawerRailPosition.right,
            ),
          ),
        ),
      );

      final br = drawerEdgeRadius(tester);
      expect(br.topLeft, const Radius.circular(24));
      expect(br.bottomLeft, const Radius.circular(24));
      expect(br.topRight, Radius.zero);
      expect(br.bottomRight, Radius.zero);
    });
  });
}

bool _hasAnimatedFill(WidgetTester tester, Color color) => tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .any((container) {
      final decoration = container.decoration;
      return decoration is BoxDecoration && decoration.color == color;
    });
