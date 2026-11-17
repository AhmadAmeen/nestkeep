import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/screens/documents_section.dart';
import 'package:nestkeep/theme.dart';

AppState _state({
  bool pro = false,
  List<HomeDoc> docs = const [],
  List<HomeSpace> spaces = const [],
}) {
  final s = AppState();
  s.activeHome = Home(
    id: 1,
    name: 'Maple House',
    addressLine: '',
    type: 'house',
    yearBuilt: 1998,
    updatedAt: DateTime(2026, 1, 1),
  );
  s.entitlement = pro
      ? const Entitlement(isPro: true, source: EntitlementSource.lifetime)
      : Entitlement.free;
  s.docs = docs;
  s.spaces = spaces;
  return s;
}

HomeDoc _doc({String title = 'House deed', int? spaceId}) => HomeDoc(
  id: 5,
  homeId: 1,
  spaceId: spaceId,
  title: title,
  filePath: '/nowhere/deed.jpg',
  createdAt: DateTime(2026, 11, 2),
  updatedAt: DateTime(2026, 11, 2),
);

Future<void> _pump(
  WidgetTester tester,
  AppState state, {
  VoidCallback? onOpenPaywall,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: nkLightTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: DocumentsSection(
            state: state,
            onOpenPaywall: onOpenPaywall ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('models', () {
    test('HomeSpace survives a map round trip', () {
      final space = HomeSpace(
        id: 3,
        homeId: 1,
        name: 'Kitchen',
        icon: 'kitchen',
        createdAt: DateTime(2026, 11, 1, 9, 15),
        updatedAt: DateTime(2026, 11, 3, 20, 45),
      );
      final back = HomeSpace.fromMap(space.toMap());
      expect(back.id, 3);
      expect(back.name, 'Kitchen');
      expect(back.icon, 'kitchen');
      expect(back.createdAt, space.createdAt);
      expect(back.updatedAt, space.updatedAt);
    });

    test('HomeDoc survives a map round trip, whole home and spaced', () {
      final whole = _doc();
      final backWhole = HomeDoc.fromMap(whole.toMap());
      expect(backWhole.spaceId, isNull);
      expect(backWhole.title, 'House deed');
      expect(backWhole.filePath, '/nowhere/deed.jpg');

      final spaced = _doc(title: 'Oven manual', spaceId: 3);
      final backSpaced = HomeDoc.fromMap(spaced.toMap());
      expect(backSpaced.spaceId, 3);
      expect(backSpaced.title, 'Oven manual');
    });

    test('HomeDoc copyWith can move a doc back to the whole home', () {
      final moved = _doc(spaceId: 3).copyWith(spaceId: null, clearSpace: true);
      expect(moved.spaceId, isNull);
      final renamed = _doc().copyWith(title: 'Deed (copy)');
      expect(renamed.title, 'Deed (copy)');
      expect(renamed.spaceId, isNull);
    });
  });

  testWidgets('a free user with nothing saved sees the locked teaser', (
    tester,
  ) async {
    var paywallOpens = 0;
    await _pump(tester, _state(), onOpenPaywall: () => paywallOpens++);
    expect(
      find.text('Home documents and spaces are a Pro feature'),
      findsOneWidget,
    );
    expect(find.text('Add document'), findsNothing);
    await tester.tap(find.text('Home documents and spaces are a Pro feature'));
    expect(paywallOpens, 1);
  });

  testWidgets('a Pro user with nothing saved gets the inviting empty card', (
    tester,
  ) async {
    await _pump(tester, _state(pro: true));
    expect(find.text('Nothing filed yet.'), findsOneWidget);
    expect(find.text('Add document'), findsOneWidget);
    expect(
      find.text('Home documents and spaces are a Pro feature'),
      findsNothing,
    );
  });

  testWidgets('a lapsed Pro keeps viewing saved documents, read-only', (
    tester,
  ) async {
    var paywallOpens = 0;
    await _pump(
      tester,
      _state(docs: [_doc()]),
      onOpenPaywall: () => paywallOpens++,
    );
    // The document is still there to look at, with the paused note…
    expect(find.text('House deed'), findsOneWidget);
    expect(
      find.textContaining('adding and editing are paused'),
      findsOneWidget,
    );
    // …and adding routes to the paywall, not the picker.
    await tester.tap(find.text('Add'));
    expect(paywallOpens, 1);
  });

  testWidgets('a Pro user sees saved documents and space filters', (
    tester,
  ) async {
    final kitchen = HomeSpace(
      id: 3,
      homeId: 1,
      name: 'Kitchen',
      icon: 'kitchen',
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );
    await _pump(
      tester,
      _state(
        pro: true,
        spaces: [kitchen],
        docs: [
          _doc(),
          _doc(title: 'Oven manual', spaceId: 3),
        ],
      ),
    );
    expect(find.text('House deed'), findsOneWidget);
    expect(find.text('Oven manual'), findsOneWidget);
    expect(find.text('Kitchen'), findsWidgets);
    // Filtering to the Kitchen hides the whole-home deed.
    await tester.tap(find.text('Kitchen').first);
    await tester.pump();
    expect(find.text('Oven manual'), findsOneWidget);
    expect(find.text('House deed'), findsNothing);
  });
}
