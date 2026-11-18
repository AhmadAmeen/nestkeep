import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/billing.dart';
import 'package:nestkeep/db.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/pro_test_unlock.dart';
import 'package:nestkeep/screens/paywall.dart';
import 'package:nestkeep/screens/settings.dart';
import 'package:nestkeep/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// PRO-TEST-UNLOCK (build 22): the temporary test unlock. The flag is
// local-only by construction: SyncService syncs data tables only and
// the backup export in Settings writes data tables only — the
// settings table (where this flag lives) is in neither list, so no
// export/sync assertion is possible or needed here; these tests cover
// the toggle behaviour itself.
void main() {
  group('proTestCodeMatches', () {
    test('accepts the code, forgiving case and stray spaces', () {
      expect(proTestCodeMatches('nestkeep-pro-test'), isTrue);
      expect(proTestCodeMatches('  NestKeep-Pro-Test '), isTrue);
      expect(proTestCodeMatches('NESTKEEP-PRO-TEST'), isTrue);
    });

    test('rejects everything else', () {
      expect(proTestCodeMatches(''), isFalse);
      expect(proTestCodeMatches('nestkeep-pro'), isFalse);
      expect(proTestCodeMatches('nestkeep-pro-test!'), isFalse);
      expect(proTestCodeMatches('pro-test'), isFalse);
    });
  });

  testWidgets('the paywall shows its Pro-active state in test mode',
      (tester) async {
    final state = AppState()..proTestMode = true;
    expect(state.entitlement.isPro, isFalse);
    expect(state.isPro, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(body: PaywallScreen(state: state, billing: Billing())),
      ),
    );
    // The active state prints it twice (hero chip and heading).
    expect(find.text('Pro is active'), findsWidgets);
  });

  group('the 7-tap unlock flow', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    Future<AppState> seeded() async {
      await AppDb.wipeAll();
      await AppDb.insertHome(Home(
        name: 'Test home',
        addressLine: '',
        type: 'house',
        yearBuilt: 2000,
        updatedAt: DateTime(2026, 1, 1),
      ));
      final state = AppState();
      await state.init();
      return state;
    }

    Future<void> pumpSettings(WidgetTester tester, AppState state) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: nkLightTheme(state.accent),
          home: Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: SettingsScreen(state: state, onOpenPaywall: () {}),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('Version'), 120);
    }

    /// Taps whose handlers do real database work run in real time,
    /// like the home switcher tests.
    Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 700));
      });
      await tester.pumpAndSettle();
    }

    Future<void> tapVersion(WidgetTester tester, int times) async {
      for (var i = 0; i < times; i++) {
        await tester.tap(find.text('1.5.6'));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pumpAndSettle();
    }

    Future<String?> storedFlag(WidgetTester tester) async =>
        await tester.runAsync<String?>(
            () => AppDb.getSetting(proTestModeSettingKey));

    testWidgets('six taps do nothing; the seventh opens the dialog, '
        'a wrong code changes nothing, the right code turns Pro on',
        (tester) async {
      final state = await tester.runAsync(seeded) ??
          (throw StateError('seed failed'));
      await pumpSettings(tester, state);
      expect(state.isPro, isFalse);
      expect(find.text('Pro (test mode)'), findsNothing);

      await tapVersion(tester, 6);
      expect(find.text('Pro test unlock'), findsNothing);
      await tapVersion(tester, 1);
      expect(find.text('Pro test unlock'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Wrong code: the dialog says so and nothing changes.
      await tester.enterText(find.byType(TextField), 'not-the-code');
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong code'), findsOneWidget);
      expect(find.text('Pro test unlock'), findsOneWidget);
      expect(state.isPro, isFalse);
      expect(state.proTestMode, isFalse);
      expect(await storedFlag(tester), isNull);

      // Right code (messy case and spaces on purpose): Pro turns on
      // with no billing state behind it.
      await tester.enterText(
          find.byType(TextField), '  NestKeep-Pro-Test ');
      await tapAndSettle(tester, find.text('Turn on'));
      expect(find.text('Pro test unlock'), findsNothing);
      expect(state.proTestMode, isTrue);
      expect(state.isPro, isTrue);
      expect(state.entitlement.isPro, isFalse);
      expect(state.entitlement.source, EntitlementSource.none);
      expect(await storedFlag(tester), '1');

      // About now says so, with the way back out.
      await pumpSettings(tester, state);
      expect(find.text('Pro (test mode)'), findsOneWidget);
      expect(find.text('Turn off'), findsOneWidget);

      // Turn off restores the real (free) billing state at once.
      await tapAndSettle(tester, find.text('Turn off'));
      expect(state.proTestMode, isFalse);
      expect(state.isPro, isFalse);
      expect(await storedFlag(tester), isNull);
      await pumpSettings(tester, state);
      expect(find.text('Pro (test mode)'), findsNothing);
    });

    testWidgets('the same 7-tap + code flow turns test mode back off',
        (tester) async {
      final state = await tester.runAsync(seeded) ??
          (throw StateError('seed failed'));
      await tester.runAsync(() => state.setProTestMode(true));
      expect(state.isPro, isTrue);
      await pumpSettings(tester, state);
      await tapVersion(tester, 7);
      expect(find.text('Pro test unlock'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'nestkeep-pro-test');
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Turn off'),
        ),
      );
      expect(state.proTestMode, isFalse);
      expect(state.isPro, isFalse);
      expect(await storedFlag(tester), isNull);
    });

    testWidgets('the flag survives a restart (fresh state init)',
        (tester) async {
      final state = await tester.runAsync(seeded) ??
          (throw StateError('seed failed'));
      await tester.runAsync(() => state.setProTestMode(true));
      final fresh = AppState();
      await tester.runAsync(() => fresh.init());
      expect(fresh.proTestMode, isTrue);
      expect(fresh.isPro, isTrue);
      expect(fresh.entitlement.isPro, isFalse);
    });
  });
}
