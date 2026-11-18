import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/screens/appliances.dart';
import 'package:nestkeep/screens/documents.dart';
import 'package:nestkeep/screens/documents_section.dart';
import 'package:nestkeep/screens/history.dart';
import 'package:nestkeep/screens/my_home.dart';
import 'package:nestkeep/theme.dart';

AppState _seeded() {
  final s = AppState();
  final stamp = DateTime(2026, 1, 1);
  s.activeHome = Home(
    id: 1,
    name: 'Maple House',
    addressLine: '',
    type: 'house',
    yearBuilt: 1998,
    updatedAt: stamp,
  );
  s.appliances = [
    Appliance(
        id: 1,
        homeId: 1,
        name: 'Fridge',
        warrantyMonths: 12,
        updatedAt: stamp),
    Appliance(
        id: 2,
        homeId: 1,
        name: 'Washer',
        warrantyMonths: 24,
        updatedAt: stamp),
  ];
  s.docs = [
    HomeDoc(
      id: 5,
      homeId: 1,
      title: 'House deed',
      filePath: '/nowhere/deed.jpg',
      createdAt: DateTime(2026, 11, 2),
      updatedAt: DateTime(2026, 11, 2),
    ),
  ];
  s.tasks = [
    for (var i = 0; i < 3; i++)
      TaskInstance(
        id: i + 1,
        homeId: 1,
        title: 'Done job ${i + 1}',
        category: 'HVAC',
        dueDate: DateTime(2026, 10, i + 1),
        status: TaskStatus.done,
        doneDate: DateTime(2026, 10, i + 1),
        updatedAt: stamp,
      ),
    TaskInstance(
      id: 9,
      homeId: 1,
      title: 'Upcoming job',
      category: 'Plumbing',
      dueDate: DateTime(2027, 1, 1),
      updatedAt: stamp,
    ),
  ];
  s.expenses = [
    Expense(
      id: 1,
      homeId: 1,
      date: DateTime.now(),
      amount: 120,
      category: 'HVAC',
      updatedAt: stamp,
    ),
  ];
  s.receipts = [
    Receipt(
      id: 1,
      homeId: 1,
      store: 'Depot',
      date: DateTime(2026, 10, 3),
      total: 42,
      items: [ReceiptItem('Filter', 42)],
      updatedAt: stamp,
    ),
  ];
  s.contractors = [
    Contractor(
        id: 1, homeId: 1, name: 'Pat Plumber', trade: 'Plumber', updatedAt: stamp),
  ];
  s.belongings = [
    Belonging(
        id: 1, homeId: 1, name: 'Sofa', room: 'Living room', value: 250, updatedAt: stamp),
  ];
  s.homeNotes = [
    HomeNote(id: 1, homeId: 1, title: 'Paint', body: 'Eggshell', updatedAt: stamp),
  ];
  return s;
}

Future<void> _pumpHub(
  WidgetTester tester,
  AppState state, {
  VoidCallback? onOpenCosts,
}) async {
  // A tall surface so the whole hub, tiles included, is built.
  tester.view.physicalSize = const Size(900, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(
    theme: nkLightTheme(),
    home: Scaffold(
      body: MyHomeScreen(
        state: state,
        onOpenScan: () {},
        onOpenCosts: onOpenCosts ?? () {},
        onOpenPaywall: () {},
      ),
    ),
  ));
}

void main() {
  testWidgets('the hub shows the stats strip counts and every tile',
      (tester) async {
    await _pumpHub(tester, _seeded());

    // Stats strip: the three real counts with their labels.
    expect(find.text('2'), findsOneWidget); // appliances
    expect(find.text('1'), findsOneWidget); // documents
    expect(find.text('3'), findsOneWidget); // jobs done
    expect(find.text('Jobs done'), findsOneWidget);

    // Every tile is there with its label and honest sublabel.
    expect(find.text('Appliances'), findsWidgets); // stats label + tile
    expect(find.text('2 tracked'), findsOneWidget);
    expect(find.text('Documents'), findsWidgets);
    expect(find.text('1 stored'), findsOneWidget);
    expect(find.text('Costs'), findsOneWidget);
    expect(find.text('\$120 this year'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('3 jobs done'), findsOneWidget);
    expect(find.text('Receipts'), findsOneWidget);
    expect(find.text('Contractors'), findsOneWidget);
    expect(find.text('Belongings'), findsOneWidget);
    expect(find.text('\$250 listed'), findsOneWidget);
    expect(find.text('Home notes'), findsOneWidget);
    expect(find.text('1 note'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('House · built 1998'), findsOneWidget);
    // Contractors and Receipts both report one saved entry.
    expect(find.text('1 saved'), findsNWidgets(2));

    // Nothing is listed inline on the hub any more.
    expect(find.byType(DocumentsSection), findsNothing);
    expect(find.text('Your pros'), findsNothing);
    expect(find.text('House deed'), findsNothing);
    expect(find.text('Fridge'), findsNothing);
  });

  testWidgets('the Costs tile uses the existing costs route',
      (tester) async {
    var costsOpens = 0;
    await _pumpHub(tester, _seeded(), onOpenCosts: () => costsOpens++);
    await tester.tap(find.text('Costs'));
    await tester.pump();
    expect(costsOpens, 1);
  });

  testWidgets('tiles open their dedicated screens', (tester) async {
    await _pumpHub(tester, _seeded());

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MyHomeScreen), findsOneWidget);

    // The tile sublabel is unique (the stats strip also says
    // "Documents"); tapping it lands on the tile card.
    await tester.tap(find.text('1 stored'));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentsScreen), findsOneWidget);
    expect(find.text('House deed'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The tile sublabel is unique; tapping it lands on the tile card.
    await tester.tap(find.text('2 tracked'));
    await tester.pumpAndSettle();
    expect(find.byType(AppliancesScreen), findsOneWidget);
    expect(find.text('Fridge'), findsOneWidget);
    expect(find.text('Washer'), findsOneWidget);
  });
}
