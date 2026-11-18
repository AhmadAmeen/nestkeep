import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/avatars.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets/avatar_menu.dart';
import 'package:nestkeep/widgets/avatar_picker.dart';

/// Build 20 avatar picker behaviour: the collapsible Profile grid
/// and the Pro custom-photo tile.
void main() {
  late File tempPhoto;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('nk_avatar_picker');
    tempPhoto = File('${dir.path}/avatar.png');
    await tempPhoto.writeAsBytes(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg=='));
  });

  Future<void> pumpPicker(
    WidgetTester tester,
    AppState state, {
    bool collapsible = false,
    VoidCallback? onLockedTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(
          body: AvatarPicker(
            state: state,
            collapsible: collapsible,
            onLockedTap: onLockedTap ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('collapsed grid shows the first four plus a chevron, '
      'and expands to the whole grid', (tester) async {
    final state = AppState();
    await pumpPicker(tester, state, collapsible: true);
    expect(find.text('House'), findsOneWidget);
    expect(find.text('Owl'), findsOneWidget);
    expect(find.text('Sunflower'), findsOneWidget);
    expect(find.text('Cat'), findsOneWidget);
    expect(find.text('Fixer'), findsNothing);
    expect(find.text('Dragon'), findsNothing);
    expect(find.text('Yours'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(find.text('Fixer'), findsOneWidget);
    expect(find.text('Dragon'), findsOneWidget);
    expect(find.text('Yours'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  testWidgets('a selected avatar beyond the first four stays visible '
      'in the collapsed row', (tester) async {
    final state = AppState()..currentAvatar = avatarById('star');
    await pumpPicker(tester, state, collapsible: true);
    // Star (6th) swaps into the 4th slot; Cat is the one swapped out.
    expect(find.text('Star'), findsOneWidget);
    expect(find.text('Cat'), findsNothing);
    expect(find.text('House'), findsOneWidget);
  });

  testWidgets('a free user tapping the Yours tile routes to the '
      'paywall path', (tester) async {
    var lockedTaps = 0;
    final state = AppState();
    await pumpPicker(tester, state, onLockedTap: () => lockedTaps++);
    expect(find.text('Yours'), findsOneWidget);
    await tester.tap(find.text('Yours'));
    await tester.pumpAndSettle();
    expect(lockedTaps, 1);
    expect(state.currentAvatar.id, 'house');
  });

  testWidgets('the custom avatar renders its photo in the header '
      'button', (tester) async {
    final state = AppState()
      ..entitlement =
          const Entitlement(isPro: true, source: EntitlementSource.yearly)
      ..customAvatarPath = tempPhoto.path
      ..currentAvatar = customAvatarDef;
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(body: AvatarButton(state: state, onTap: () {})),
      ),
    );
    await tester.pumpAndSettle();
    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(circle.backgroundImage, isA<FileImage>());
    expect(find.text('🏠'), findsNothing);
  });

  testWidgets('the custom avatar falls back to the house when its '
      'file is missing', (tester) async {
    final state = AppState()
      ..entitlement =
          const Entitlement(isPro: true, source: EntitlementSource.yearly)
      ..currentAvatar = customAvatarDef;
    // customAvatarPath stays null: no file on disk.
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(body: AvatarButton(state: state, onTap: () {})),
      ),
    );
    await tester.pumpAndSettle();
    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(circle.backgroundImage, isNull);
    expect(find.text('🏠'), findsOneWidget);
    expect(state.displayAvatar.id, 'house');
  });
}
