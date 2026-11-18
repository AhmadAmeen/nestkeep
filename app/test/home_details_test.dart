import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/db.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/plan.dart';
import 'package:nestkeep/screens/home_details.dart';
import 'package:nestkeep/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Build 20: the Home details screen gains a home photo and an edit
/// mode. These tests run against a real (FFI) database and prove the
/// edit persists name + profile answers, and that editing the facts
/// never touches the plan's task instances.
void main() {
  late File tempPhoto;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // A real 1x1 PNG the image widgets can decode.
    final dir = await Directory.systemTemp.createTemp('nk_home_details');
    tempPhoto = File('${dir.path}/photo.png');
    await tempPhoto.writeAsBytes(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg=='));
  });

  Future<(AppState, int)> seededState() async {
    await AppDb.wipeAll();
    final homeId = await AppDb.insertHome(Home(
      name: 'Old name',
      addressLine: '',
      type: 'house',
      yearBuilt: 1998,
      updatedAt: DateTime(2026, 1, 1),
    ));
    await saveProfile(
      homeId,
      const HomeProfile(
        homeType: 'house',
        heating: 'forced_air',
        cooling: 'central',
        climate: 'mild',
        hasBasement: false,
        hasGarage: false,
        hasDeck: false,
        hasSprinklers: false,
        hasSoftener: false,
        hasChimney: false,
      ),
    );
    for (var i = 0; i < 2; i++) {
      await AppDb.insertTask(TaskInstance(
        homeId: homeId,
        templateId: 'seed_$i',
        title: 'Seed job $i',
        category: 'HVAC',
        dueDate: DateTime(2026, 2, 1),
        status: TaskStatus.upcoming,
        updatedAt: DateTime(2026, 1, 1),
      ));
    }
    final state = AppState();
    await state.init();
    return (state, homeId);
  }

  /// Tap whose handler does real IO, run in real time like the
  /// appliance flow tests (fake-zone futures cannot complete).
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('no photo shows the add row; a photo file shows the '
      'picture instead', (tester) async {
    final (state, homeId) =
        await tester.runAsync(seededState) ?? (throw StateError('seed failed'));
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: HomeDetailsScreen(state: state, onOpenPaywall: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add home photo'), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    state.homePhotos[homeId] = tempPhoto.path;
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: HomeDetailsScreen(state: state, onOpenPaywall: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add home photo'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('build 21: a free user tapping Add home photo gets the '
      'paywall, never the picker', (tester) async {
    final (state, _) =
        await tester.runAsync(seededState) ?? (throw StateError('seed failed'));
    var paywallOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: HomeDetailsScreen(
          state: state,
          onOpenPaywall: () => paywallOpened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(state.isPro, isFalse);
    await tester.tap(find.text('Add home photo'));
    await tester.pumpAndSettle();
    expect(paywallOpened, isTrue);
    // The camera-or-gallery sheet never opened.
    expect(find.text('Take a photo'), findsNothing);
    expect(find.text('Pick from gallery'), findsNothing);
  });

  testWidgets('build 21: a Pro user tapping Add home photo reaches the '
      'picker sheet', (tester) async {
    final (state, _) =
        await tester.runAsync(seededState) ?? (throw StateError('seed failed'));
    state.entitlement =
        const Entitlement(isPro: true, source: EntitlementSource.yearly);
    var paywallOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: HomeDetailsScreen(
          state: state,
          onOpenPaywall: () => paywallOpened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add home photo'));
    await tester.pumpAndSettle();
    expect(paywallOpened, isFalse);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Pick from gallery'), findsOneWidget);
    // Dismiss the sheet again.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsNothing);
  });

  testWidgets('editing saves the name and a profile answer, persists '
      'them, and leaves the plan alone', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (state, homeId) =
        await tester.runAsync(seededState) ?? (throw StateError('seed failed'));
    final tasksBefore =
        await tester.runAsync(() => AppDb.tasksForHome(homeId)) ?? const [];
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: HomeDetailsScreen(state: state, onOpenPaywall: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Renamed home');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Heat pump'));
    await tester.tap(find.widgetWithText(FilterChip, 'Pool / hot tub'));
    await tapAndSettle(tester, find.text('Save changes'));

    // Back in view mode with the confirmation ticker.
    expect(find.text('Home updated'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Renamed home'), findsWidgets);

    // Both changes persisted to the database.
    final homes = await tester.runAsync(AppDb.homes) ?? const [];
    expect(homes.single.name, 'Renamed home');
    final profile = await tester.runAsync(() => loadProfile(homeId));
    expect(profile, isNotNull);
    expect(profile!.heating, 'heat_pump');
    expect(profile.hasPool, isTrue);
    expect(profile.homeType, 'house');

    // The plan is untouched: same instances, same ids, same status.
    final tasksAfter =
        await tester.runAsync(() => AppDb.tasksForHome(homeId)) ?? const [];
    expect(tasksAfter.length, tasksBefore.length);
    expect(
      tasksAfter.map((t) => t.id).toList(),
      tasksBefore.map((t) => t.id).toList(),
    );
    expect(
      tasksAfter.every((t) => t.status == TaskStatus.upcoming),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 4));
  });
}
