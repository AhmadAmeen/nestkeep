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
  VoidCallback? onOpenPaywall,
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

  testWidgets('tapping an earned badge opens its detail panel '
      '(build 24)', (tester) async {
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
    await tester.tap(find.text('First job done'));
    await tester.pumpAndSettle();
    // The earn-moment panel, as a dialog: heading, name, blurb,
    // and the same dismiss button.
    expect(find.text('BADGE EARNED'), findsOneWidget);
    expect(find.text('Your first job is in the books.'), findsOneWidget);
    expect(find.text('Nice'), findsOneWidget);
    await tester.tap(find.text('Nice'));
    await tester.pumpAndSettle();
    expect(find.text('BADGE EARNED'), findsNothing);
    expect(find.text('Your first job is in the books.'), findsNothing);
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
    expect(find.text('1.5.6'), findsOneWidget);
    expect(find.textContaining('NestKeep 1.5.6'), findsOneWidget);
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

  testWidgets('Profile has no home switcher (build 23: home '
      'management lives on My Home)', (tester) async {
    final state = AppState();
    await _pumpProfile(tester, state);
    // No dropdown, no Add home, no current-home row: the account
    // card is the first card on the page again.
    expect(find.byType(PopupMenuButton), findsNothing);
    expect(find.text('Add home'), findsNothing);
    expect(find.text('Your home'), findsNothing);
    expect(find.text('Guest mode'), findsOneWidget);
  });
}
