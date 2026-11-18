import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/db.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/plan.dart';
import 'package:nestkeep/screens/scan.dart';
import 'package:nestkeep/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Build 23 scanner gate tests: a scan is only saved when the OCR
/// actually found an invoice in the photo — prices (at least one
/// priced item or a total). A no-price read (camera OR gallery: both
/// arrive through the one intake in ScanScreen._scan) is rejected
/// with a clear message; no review sheet opens, no receipt record
/// is written and the image is never copied into the app. A read
/// with prices behaves exactly as before.
///
/// The platform seams are mocked at their channels: image_picker
/// hands back a prepared file (and records which source was asked
/// for), ML Kit returns a payload built from the test's lines, and
/// path_provider points at a real temp directory so the Pro image
/// copy can be asserted on disk.
void main() {
  late Directory docsDir;
  late File pickedFile;
  var ocrLines = <String>[];
  int? lastPickSource;

  Map<String, dynamic> ocrPayload(List<String> lines) {
    Map<String, dynamic> rect(int r) =>
        {'left': 0, 'top': 0, 'right': 100, 'bottom': r};
    return {
      'text': lines.join('\n'),
      'blocks': [
        {
          'text': lines.join('\n'),
          'rect': rect(100),
          'recognizedLanguages': <String>[],
          'points': <dynamic>[],
          'lines': [
            for (final l in lines)
              {
                'text': l,
                'rect': rect(10),
                'recognizedLanguages': <String>[],
                'points': <dynamic>[],
                'elements': <dynamic>[],
                'confidence': null,
                'angle': null,
              },
          ],
        },
      ],
    };
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'initialize' ? true : null,
    );
    docsDir = await Directory.systemTemp.createTemp('nestkeep_scan_test');
    pickedFile = File('${docsDir.path}/picked_source.jpg');
    await pickedFile.writeAsBytes([1, 2, 3, 4]);
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => docsDir.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_picker'),
      (call) async {
        if (call.method == 'pickImage') {
          final args = call.arguments as Map<dynamic, dynamic>;
          lastPickSource = args['source'] as int?;
          return pickedFile.path;
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('google_mlkit_text_recognizer'),
      (call) async {
        if (call.method == 'vision#startTextRecognizer') {
          return ocrPayload(ocrLines);
        }
        return null;
      },
    );
  });

  Future<AppState> seededState({bool pro = false}) async {
    await AppDb.wipeAll();
    final homeId = await AppDb.insertHome(Home(
      name: 'Test home',
      addressLine: '',
      type: 'house',
      yearBuilt: 2000,
      updatedAt: DateTime(2026, 1, 1),
    ));
    await saveProfile(
      homeId,
      const HomeProfile(
        homeType: 'house',
        heating: 'forced_air',
        cooling: 'central',
        hasBasement: false,
        hasGarage: false,
        hasDeck: false,
        hasSprinklers: false,
        hasSoftener: false,
        hasChimney: false,
      ),
    );
    final state = AppState();
    await state.init();
    if (pro) {
      state.entitlement =
          const Entitlement(isPro: true, source: EntitlementSource.yearly);
    }
    return state;
  }

  Future<void> pumpScan(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(state.accent),
        home: Scaffold(body: ScanScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pumpAndSettle();
  }

  /// Bounded pumps until [finder] matches. The priced path needs
  /// this instead of pumpAndSettle: ScanScreen._scan awaits the
  /// review sheet with _busy still true, so the spinner behind the
  /// sheet animates forever and pumpAndSettle can never settle
  /// while the sheet is open.
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  const noInvoiceLines = [
    'A plain wall',
    'Nothing priced here',
    'Just some words',
  ];

  void expectNothingSaved(AppState state) {
    expect(state.receipts, isEmpty);
    // The image was never copied into the app: the documents folder
    // holds only the file the picker handed back.
    final kept = docsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('receipt_'))
        .toList();
    expect(kept, isEmpty);
  }

  testWidgets('gallery pick with no prices: rejected with the '
      'message, nothing saved, no image kept', (tester) async {
    ocrLines = noInvoiceLines;
    lastPickSource = null;
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpScan(tester, state);
    await tapAndSettle(tester, find.text('Pick from gallery'));

    // The pick really went to the gallery (source 1).
    expect(lastPickSource, 1);
    expect(
      find.text("Couldn't read an invoice in that photo. "
          'Try a clearer, straight-on shot.'),
      findsOneWidget,
    );
    // No review sheet ever opened.
    expect(find.text('Save receipt'), findsNothing);
    expectNothingSaved(state);
  });

  testWidgets('camera shot with no prices: rejected the same way',
      (tester) async {
    ocrLines = noInvoiceLines;
    lastPickSource = null;
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpScan(tester, state);
    await tapAndSettle(tester, find.text('Take a photo'));

    expect(lastPickSource, 0);
    expect(
      find.text("Couldn't read an invoice in that photo. "
          'Try a clearer, straight-on shot.'),
      findsOneWidget,
    );
    expect(find.text('Save receipt'), findsNothing);
    expectNothingSaved(state);
  });

  testWidgets('gallery pick with prices: the review sheet opens '
      'and saving files the receipt, the appliance, the spend — '
      'and keeps the photo for Pro', (tester) async {
    ocrLines = const [
      'Corner Store',
      'Fridge 499.99',
      'TOTAL 499.99',
    ];
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = await tester.runAsync(() => seededState(pro: true)) ??
        (throw StateError('seed'));
    await pumpScan(tester, state);
    await tester.runAsync(() async {
      await tester.tap(find.text('Pick from gallery'));
      await Future<void>.delayed(const Duration(milliseconds: 900));
    });
    await pumpUntilFound(tester, find.text('Save receipt'));

    expect(lastPickSource, 1);
    expect(find.text('Save receipt'), findsOneWidget);
    await tester.ensureVisible(find.text('Save receipt'));
    await tester.pump(const Duration(milliseconds: 300));
    await tapAndSettle(tester, find.text('Save receipt'));

    // Saved as before: receipt, appliance, expense, ticker.
    expect(find.text('Receipt saved'), findsOneWidget);
    expect(state.receipts, hasLength(1));
    expect(state.receipts.single.total, 499.99);
    expect(state.appliances.map((a) => a.name), contains('Fridge'));
    expect(state.expenses.map((e) => e.amount), contains(499.99));
    // Pro keeps the photo: copied into the app folder and recorded.
    final imagePath = state.receipts.single.imagePath;
    expect(imagePath, isNotNull);
    expect(File(imagePath!).existsSync(), isTrue);
    await tester.pump(const Duration(seconds: 4));
  });
}
