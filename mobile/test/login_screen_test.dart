import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/providers/user_provider.dart';
import 'package:impulse/screens/login/login_screen.dart';
import 'package:impulse/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> preferences(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  Widget appWithPreferences(SharedPreferences prefs) {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        home: LoginScreen(
          destinationBuilder: (_) =>
              const Scaffold(body: Text('Dashboard test destination')),
        ),
      ),
    );
  }

  testWidgets('shows a name-only Login screen', (tester) async {
    final prefs = await preferences({});
    await tester.pumpWidget(appWithPreferences(prefs));

    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.textContaining('No account, password, email, or phone number'),
        findsOneWidget);
  });

  testWidgets('rejects a blank name', (tester) async {
    final prefs = await preferences({});
    await tester.pumpWidget(appWithPreferences(prefs));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(prefs.getBool('impulse_is_onboarded'), isNot(true));
  });

  testWidgets('trims and stores the name only on device', (tester) async {
    final prefs = await preferences({});
    await tester.pumpWidget(appWithPreferences(prefs));

    await tester.enterText(find.byType(TextFormField), '  Rishi  ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(prefs.getString('impulse_user_name'), 'Rishi');
    expect(prefs.getBool('impulse_is_onboarded'), isTrue);
    expect(find.text('Dashboard test destination'), findsOneWidget);
  });

  test('existing local profile bypass state remains compatible', () async {
    final prefs = await preferences({
      'impulse_user_name': 'Rishi',
      'impulse_is_onboarded': true,
    });

    final state = UserNotifier(LocalStorageService(prefs)).state;
    expect(state.name, 'Rishi');
    expect(state.isOnboarded, isTrue);
  });
}
