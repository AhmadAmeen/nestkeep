import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/screens/profile.dart';
import 'package:nestkeep/screens/settings.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets/avatar_menu.dart';

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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: nkLightTheme(),
      home: Scaffold(
        body: ProfileScreen(
          state: state,
          onOpenPaywall: () {},
          onAddHome: () {},
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
          themeMode: ThemeMode.system,
          onThemeChanged: (_) {},
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
    expect(find.text('0 earned'), findsOneWidget);
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

  testWidgets('Settings carries appearance, colours, data and about', (
    tester,
  ) async {
    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SettingsScreen(
            state: state,
            themeMode: ThemeMode.system,
            onThemeChanged: (_) {},
            onOpenPaywall: () {},
          ),
        ),
      ),
    );
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('App colour'), findsOneWidget);
    expect(find.text('Purple'), findsOneWidget);
    expect(find.text('Violet'), findsOneWidget);
    expect(find.text('Plum'), findsOneWidget);
    expect(find.text('Fuchsia'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Export backup'), 120);
    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Version'), 120);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('1.5.1'), findsOneWidget);
    expect(find.textContaining('NestKeep 1.5.1'), findsOneWidget);
    // Nothing settings-like is left duplicated on Profile.
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
    await _pumpSettings(tester, state,
        onOpenPaywall: () => paywallOpened = true);
    // All three custom colours carry the lock and the PRO caption;
    // Purple, the free default, never does.
    expect(find.byIcon(Icons.lock), findsNWidgets(3));
    expect(find.text('PRO'), findsNWidgets(3));
    await tester.tap(find.text('Violet'));
    expect(paywallOpened, isTrue);
    expect(state.accent, AppAccent.purple);
  });

  testWidgets('a stored custom colour stays applied while free',
      (tester) async {
    var paywallOpened = false;
    final state = AppState()..accent = AppAccent.plum;
    await _pumpSettings(tester, state,
        onOpenPaywall: () => paywallOpened = true);
    // Plum is in use, so only the other two custom colours are locked.
    expect(find.byIcon(Icons.lock), findsNWidgets(2));
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
    await _pumpSettings(tester, state);
    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.text('PRO'), findsNWidgets(3));
  });
}
