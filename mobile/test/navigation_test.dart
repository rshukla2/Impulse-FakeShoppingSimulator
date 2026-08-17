import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/core/theme/app_colors.dart';
import 'package:impulse/core/theme/app_theme.dart';
import 'package:impulse/core/icons/app_icons.dart';
import 'package:impulse/providers/bootstrap_provider.dart';
import 'package:impulse/providers/user_provider.dart';
import 'package:impulse/screens/main_navigation_screen.dart';
import 'package:impulse/widgets/badge_icon.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the exact five fixed tabs and Home shortcuts reuse them',
      (tester) async {
    final prefs = await testPreferences({
      'impulse_user_name': 'Rishi',
      'impulse_is_onboarded': true,
    });
    final api = testApiClient((options, handler) {
      switch (options.path) {
        case '/bootstrap':
          resolveJson(options, handler, bootstrapJson());
        case '/categories':
          resolveJson(options, handler, {
            'shopping_categories': ['All', 'Electronics'],
            'grocery_categories': ['All', 'Pantry'],
            'food_cuisines': ['All', 'Italian'],
          });
        case '/restaurants':
          resolveJson(options, handler, {'items': [], 'total': 0});
        case '/food':
        case '/shopping':
        case '/groceries':
          resolveJson(options, handler, {
            'items': [],
            'page': 1,
            'total': 0,
            'has_more': false,
          });
        default:
          fail('Unexpected request: ${options.path}');
      }
    });
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainNavigationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(nav.items.map((item) => item.label).toList(), [
      'Home',
      'Food',
      'Groceries',
      'Shopping',
      'Orders',
    ]);
    expect(nav.currentIndex, 0);
    expect(nav.backgroundColor, AppColors.forestGreen);
    expect(nav.selectedItemColor, AppColors.warmBeige);
    expect(nav.showUnselectedLabels, isTrue);
    expect((nav.items[2].icon as Icon).icon, LucideIcons.groceries);
    expect(find.byKey(const Key('impulse-toolbar-logo')), findsOneWidget);
    expect(find.byIcon(LucideIcons.groceries), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(CartBadgeButton),
        matching: find.byIcon(LucideIcons.shoppingCart),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('General Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General Shopping'));
    await tester.pump();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      3,
    );
    expect(find.text('0 Catalog Items'), findsOneWidget);
  });

  testWidgets('navigation remains responsive on tablet and web canvases',
      (tester) async {
    final prefs = await testPreferences({
      'impulse_user_name': 'Rishi',
      'impulse_is_onboarded': true,
    });
    final api = testApiClient((options, handler) {
      if (options.path == '/bootstrap') {
        resolveJson(options, handler, bootstrapJson());
      } else if (options.path == '/categories') {
        resolveJson(options, handler, {
          'shopping_categories': ['All'],
          'grocery_categories': ['All'],
          'food_cuisines': ['All'],
        });
      } else if (options.path == '/restaurants') {
        resolveJson(options, handler, {'items': [], 'total': 0});
      } else {
        resolveJson(options, handler, {
          'items': [],
          'page': 1,
          'total': 0,
          'has_more': false,
        });
      }
    });
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;

    for (final size in const [Size(800, 1000), Size(1440, 900)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MainNavigationScreen(initialIndex: 4),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        4,
      );
    }
  });
}
