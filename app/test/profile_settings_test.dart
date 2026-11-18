import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/db.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/screens/profile.dart';
import 'package:nestkeep/screens/settings.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets/avatar_menu.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

TaskInstance _task({
  required TaskStatus status,
  DateTime? due,
  DateTime? done,
  String category = 'HVAC',
}) {
  final now = DateTime.now();
  return TaskInstance(
    homeId: 1,
    templateId: 'tpl',
    title: 'Job',
    category: category,
    dueDate: due ?? now,
    status: status,
    doneDate: done,
    updatedAt: now,
  );
}

Future<void> _pumpProfile(
  WidgetTester tester,
  AppState state, {
  VoidCallback? onOpenSettings,
  VoidCallback? onOpenPaywall,
  VoidCallback? onAddHome,
}) async {
  // A tall viewport: Profile grew in build 20 (Appearance moved in),
  // and rows left at the very edge of the default surface take taps
  // on their borders instead of their centres.
  tester.view.physicalSize = const Size(1080, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: nkLightTheme(),
      home: Scaffold(
        body: ProfileScreen(
          state: state,
          themeMode: ThemeMode.system,
          onThemeChanged: (_) {},
          onOpenPaywall: onOpenPaywall ?? () {},
          onAddHome: onAddHome ?? () {},
          onOpenSettings: onOpenSettings ?? () {},
        ),
      ),
    ),
  );
}

Future<void> _pumpSettings(WidgetTester tester, AppState state,
    {VoidCallback? onOpenPaywall}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: nkLightTheme(state.accent),
      home: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: SettingsScreen(
          state: state,
          onOpenPaywall: onOpenPaywall ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Profile shows earned badges only', (tester) async {
    final state = AppState();
    final threeWeeksAgo = DateTime.now().subtract(const Duration(days: 21));
    state.tasks = [
      _task(status: TaskStatus.done, due: threeWeeksAgo, done: threeWeeksAgo),
    ];
    await _pumpProfile(tester, state);
    await tester.scrollUntilVisible(
      find.text('First job done'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('First job done'), findsOneWidget);
    expect(find.text('Did it myself'), findsOneWidget);
    expect(find.text('On time'), findsOneWidget);
    // Unearned badges are not shown at all — no greyed catalogue.
    expect(find.text('200 jobs done'), findsNothing);
    expect(find.text('10 documents'), findsNothing);
    expect(find.text('Pro member'), findsNothing);
    expect(find.textContaining('Finish your first job'), findsNothing);
    expect(find.textContaining('earned'), findsOneWidget);
  });

  testWidgets('Profile with nothing earned shows the first-badge hint', (
    tester,
  ) async {
    final state = AppState();
    final longOverdue = DateTime.now().subtract(const Duration(days: 30));
    state.tasks = [
      for (var i = 0; i < 3; i++)
        _task(
          status: TaskStatus.upcoming,
          due: longOverdue,
          category: 'Safety',
        ),
    ];
    await _pumpProfile(tester, state);
    await tester.scrollUntilVisible(
      find.text('Finish your first job to earn your first badge.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Finish your first job to earn your first badge.'),
      findsOneWidget,
    );
    expect(find.text('First job done'), findsNothing);
    expect(find.text('0 earned out of 80'), findsOneWidget);
  });

  testWidgets('the Settings row on Profile opens Settings', (tester) async {
    var opened = false;
    final state = AppState();
    await _pumpProfile(tester, state, onOpenSettings: () => opened = true);
    await tester.scrollUntilVisible(
      find.text('Settings'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Settings'));
    expect(opened, isTrue);
  });

  testWidgets('Settings carries data and about only', (tester) async {
    final state = AppState();
    await _pumpSettings(tester, state);
    // Appearance moved to Profile in build 20: no theme or colour
    // controls remain here.
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('App colour'), findsNothing);
    expect(find.text('Violet'), findsNothing);
    expect(find.text('Data'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Export backup'), 120);
    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Version'), 120);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('1.5.4'), findsOneWidget);
    expect(find.textContaining('NestKeep 1.5.4'), findsOneWidget);
  });

  testWidgets('Profile carries the appearance section', (tester) async {
    final state = AppState();
    await _pumpProfile(tester, state);
    await tester.scrollUntilVisible(
      find.text('App colour'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('App colour'), findsOneWidget);
    expect(find.text('Purple'), findsOneWidget);
    expect(find.text('Violet'), findsOneWidget);
    expect(find.text('Plum'), findsOneWidget);
    expect(find.text('Fuchsia'), findsOneWidget);
    expect(find.text('Orange'), findsOneWidget);
  });

  testWidgets('the avatar menu opens with its rows and the picker', (
    tester,
  ) async {
    final state = AppState();
    var proOpened = false;
    var settingsOpened = false;
    var profileOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: AvatarButton(
                state: state,
                onTap: () => showAvatarMenu(
                  context,
                  state: state,
                  onOpenPaywall: () => proOpened = true,
                  onOpenSettings: () => settingsOpened = true,
                  onOpenProfile: () => profileOpened = true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AvatarButton));
    await tester.pumpAndSettle();
    expect(find.text('Guest — your data lives on this phone'), findsOneWidget);
    expect(find.text('Change avatar'), findsOneWidget);
    expect(find.text('Go Pro'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Change avatar'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your avatar'), findsOneWidget);
    expect(find.text('Owl'), findsOneWidget);
    expect(find.text('Crown'), findsOneWidget);
    expect(proOpened, isFalse);
    expect(settingsOpened, isFalse);
    expect(profileOpened, isFalse);
  });

  testWidgets('the avatar menu omits the Profile row when told to', (
    tester,
  ) async {
    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: AvatarButton(
                state: state,
                onTap: () => showAvatarMenu(
                  context,
                  state: state,
                  onOpenPaywall: () {},
                  onOpenSettings: () {},
                  onOpenProfile: null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AvatarButton));
    await tester.pumpAndSettle();
    expect(find.text('Change avatar'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('custom colours are locked for free users', (tester) async {
    var paywallOpened = false;
    final state = AppState();
    await _pumpProfile(tester, state,
        onOpenPaywall: () => paywallOpened = true);
    await tester.scrollUntilVisible(
      find.text('App colour'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    // All four custom colours carry the lock and the PRO caption;
    // Purple, the free default, never does. (The collapsed avatar
    // grid shows only free avatars, so it adds no locks.)
    expect(find.byIcon(Icons.lock), findsNWidgets(4));
    expect(find.text('PRO'), findsNWidgets(4));
    await tester.tap(find.text('Violet'));
    expect(paywallOpened, isTrue);
    expect(state.accent, AppAccent.purple);
    await tester.tap(find.text('Orange'));
    expect(paywallOpened, isTrue);
    expect(state.accent, AppAccent.purple);
  });

  testWidgets('a stored custom colour stays applied while free',
      (tester) async {
    var paywallOpened = false;
    final state = AppState()..accent = AppAccent.plum;
    await _pumpProfile(tester, state,
        onOpenPaywall: () => paywallOpened = true);
    await tester.scrollUntilVisible(
      find.text('App colour'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    // Plum is in use, so only the other three custom colours lock.
    expect(find.byIcon(Icons.lock), findsNWidgets(3));
    // Picking a different custom colour routes to the paywall instead.
    await tester.tap(find.text('Fuchsia'));
    expect(paywallOpened, isTrue);
    expect(state.accent, AppAccent.plum);
    // Re-tapping the colour in use is a no-op, not a paywall trip.
    paywallOpened = false;
    await tester.tap(find.text('Plum'));
    expect(paywallOpened, isFalse);
    expect(state.accent, AppAccent.plum);
  });

  testWidgets('a stored custom accent drives the theme while free',
      (tester) async {
    final state = AppState()..accent = AppAccent.plum;
    Color? rendered;
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(state.accent),
        home: Builder(
          builder: (context) {
            rendered = context.primary;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(state.isPro, isFalse);
    expect(rendered, AppAccent.plum.lightPrimary);
  });

  testWidgets('Pro users see no colour locks', (tester) async {
    final state = AppState()
      ..entitlement =
          const Entitlement(isPro: true, source: EntitlementSource.yearly);
    await _pumpProfile(tester, state);
    await tester.scrollUntilVisible(
      find.text('App colour'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byIcon(Icons.lock), findsNothing);
    // Four colour captions plus the plan card's PRO chip.
    expect(find.text('PRO'), findsNWidgets(5));
  });

  group('home switcher dropdown (build 21)', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    Future<AppState> seededHomes(List<String> names) async {
      await AppDb.wipeAll();
      for (final name in names) {
        await AppDb.insertHome(Home(
          name: name,
          addressLine: '',
          type: 'house',
          yearBuilt: 2000,
          updatedAt: DateTime(2026, 1, 1),
        ));
      }
      final state = AppState();
      await state.init();
      return state;
    }

    /// Taps whose handlers do real database work run in real time,
    /// like the appliance flow tests.
    Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 700));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('shows the current home; the menu lists every home '
        'with the current one ticked, plus Add home', (tester) async {
      final state = await tester.runAsync(
            () => seededHomes(['Alpha house', 'Beta house']),
          ) ??
          (throw StateError('seed failed'));
      await _pumpProfile(tester, state);
      // The switcher at the top shows the current home, and the old
      // Your homes card list is gone.
      expect(find.text('Alpha house'), findsOneWidget);
      expect(find.text('Your homes'), findsNothing);

      await tester.tap(find.text('Alpha house'));
      await tester.pumpAndSettle();
      expect(find.text('Beta house'), findsOneWidget);
      expect(find.text('Add home'), findsOneWidget);
      // The current home's menu row carries the tick; the other
      // home's does not. (The menu's Alpha row is the later of the
      // two Alpha texts: the switcher keeps its own underneath.)
      final alphaRow = find.ancestor(
        of: find.text('Alpha house').last,
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: alphaRow, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      final betaRow = find.ancestor(
        of: find.text('Beta house'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: betaRow, matching: find.byIcon(Icons.check)),
        findsNothing,
      );
    });

    testWidgets('picking another home switches the current home',
        (tester) async {
      final state = await tester.runAsync(
            () => seededHomes(['Alpha house', 'Beta house']),
          ) ??
          (throw StateError('seed failed'));
      await _pumpProfile(tester, state);
      await tester.tap(find.text('Alpha house'));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Beta house'));
      expect(state.activeHome?.name, 'Beta house');
      // Rebuilt (the app root rebuilds on state changes), the
      // switcher now fronts the new home.
      await _pumpProfile(tester, state);
      expect(find.text('Beta house'), findsOneWidget);
    });

    testWidgets('a free user with a home already: Add home opens the '
        'paywall, not the wizard', (tester) async {
      final state = await tester.runAsync(
            () => seededHomes(['Alpha house']),
          ) ??
          (throw StateError('seed failed'));
      var paywallOpened = false;
      var addHomeOpened = false;
      await _pumpProfile(
        tester,
        state,
        onOpenPaywall: () => paywallOpened = true,
        onAddHome: () => addHomeOpened = true,
      );
      await tester.tap(find.text('Alpha house'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add home'));
      await tester.pumpAndSettle();
      expect(paywallOpened, isTrue);
      expect(addHomeOpened, isFalse);
    });

    testWidgets('a Pro user below the cap: Add home opens the wizard',
        (tester) async {
      final state = await tester.runAsync(
            () => seededHomes(['Alpha house', 'Beta house']),
          ) ??
          (throw StateError('seed failed'));
      state.entitlement =
          const Entitlement(isPro: true, source: EntitlementSource.yearly);
      var paywallOpened = false;
      var addHomeOpened = false;
      await _pumpProfile(
        tester,
        state,
        onOpenPaywall: () => paywallOpened = true,
        onAddHome: () => addHomeOpened = true,
      );
      await tester.tap(find.text('Alpha house'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add home'));
      await tester.pumpAndSettle();
      expect(addHomeOpened, isTrue);
      expect(paywallOpened, isFalse);
    });

    testWidgets('a Pro user at three homes: Add home shows the limit '
        'message instead', (tester) async {
      final state = await tester.runAsync(
            () => seededHomes(['Alpha house', 'Beta house', 'Gamma house']),
          ) ??
          (throw StateError('seed failed'));
      state.entitlement =
          const Entitlement(isPro: true, source: EntitlementSource.yearly);
      var addHomeOpened = false;
      await _pumpProfile(
        tester,
        state,
        onAddHome: () => addHomeOpened = true,
      );
      await tester.tap(find.text('Alpha house'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add home'));
      await tester.pumpAndSettle();
      expect(find.text('3 homes is the limit'), findsOneWidget);
      expect(addHomeOpened, isFalse);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
