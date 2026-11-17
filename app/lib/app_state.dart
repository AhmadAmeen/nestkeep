import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import 'db.dart';
import 'health.dart';
import 'models.dart';
import 'plan.dart';
import 'theme.dart';

/// App-wide state, deliberately simple: one ChangeNotifier holding the
/// active home and its data, reloaded from SQLite after every mutation.
/// The phone's database is the source of truth; this is just its mirror
/// for the UI.
class AppState extends ChangeNotifier {
  List<TaskTemplate> templates = [];
  Map<String, TaskTemplate> templateById = {};
  List<Home> homes = [];
  Map<int, HomeProfile> profiles = {};
  Map<int, Set<String>> planSelections = {};
  Home? activeHome;

  HomeProfile? profileFor(int? homeId) =>
      homeId == null ? null : profiles[homeId];
  List<TaskInstance> tasks = [];
  List<Appliance> appliances = [];
  List<Expense> expenses = [];
  List<Receipt> receipts = [];
  List<Contractor> contractors = [];
  List<HomeNote> homeNotes = [];
  List<Belonging> belongings = [];
  Entitlement entitlement = Entitlement.free;
  AppAccent accent = AppAccent.purple;
  bool loaded = false;

  bool get hasHome => activeHome != null;
  bool get isPro => entitlement.isPro;

  Future<void> init() async {
    final raw = await rootBundle.loadString('assets/tasks.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    templates = (decoded['tasks'] as List)
        .map((e) => TaskTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
    templateById = {for (final t in templates) t.id: t};

    final savedEnt = await AppDb.getSetting('entitlement');
    if (savedEnt != null) {
      final m = jsonDecode(savedEnt) as Map<String, dynamic>;
      entitlement = Entitlement(
        isPro: m['isPro'] as bool? ?? false,
        source: EntitlementSource.values.byName(m['source'] as String? ?? 'none'),
        expiry: m['expiry'] == null ? null : DateTime.parse(m['expiry'] as String),
      );
      if (entitlement.expiry != null &&
          entitlement.expiry!.isBefore(DateTime.now()) &&
          entitlement.source != EntitlementSource.lifetime) {
        entitlement = Entitlement.free;
      }
    }

    final savedAccent = await AppDb.getSetting('accent');
    accent = parseAppAccent(savedAccent);

    homes = await AppDb.homes();
    for (final h in homes) {
      final p = await loadProfile(h.id!);
      if (p != null) profiles[h.id!] = p;
    }
    final activeId = await AppDb.getSetting('activeHomeId');
    if (homes.isNotEmpty) {
      activeHome = homes.firstWhere(
        (h) => h.id.toString() == activeId,
        orElse: () => homes.first,
      );
      await reload();
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> reload() async {
    if (activeHome == null) return;
    final id = activeHome!.id!;
    if (!profiles.containsKey(id)) {
      final p = await loadProfile(id);
      if (p != null) profiles[id] = p;
    }
    tasks = await AppDb.tasksForHome(id);
    planSelections[id] =
        await loadPlanSelection(id) ?? derivedSelectionFromTasks(tasks);
    appliances = await AppDb.appliancesForHome(id);
    expenses = await AppDb.expensesForHome(id);
    receipts = await AppDb.receiptsForHome(id);
    contractors = await AppDb.contractorsForHome(id);
    homeNotes = await AppDb.homeNotesForHome(id);
    belongings = await AppDb.belongingsForHome(id);
    notifyListeners();
  }

  Future<void> setActiveHome(Home h) async {
    activeHome = h;
    await AppDb.setSetting('activeHomeId', h.id.toString());
    await reload();
  }

  /// The library jobs the user has ticked for a home, from the cache
  /// filled by reload(). For the active home before any reload, falls
  /// back to the templates already in its plan.
  Set<String> selectionFor(int homeId) =>
      planSelections[homeId] ??
      (homeId == activeHome?.id
          ? derivedSelectionFromTasks(tasks)
          : const <String>{});

  /// The ticked library jobs for any home, storage-checked: the saved
  /// selection when one exists, otherwise (homes planned before build
  /// 10) the templates that already have jobs in that home's plan.
  Future<Set<String>> selectedTemplateIds(int homeId) async {
    final stored = await loadPlanSelection(homeId);
    if (stored != null) return stored;
    if (planSelections.containsKey(homeId)) return planSelections[homeId]!;
    final homeTasks = homeId == activeHome?.id
        ? tasks
        : await AppDb.tasksForHome(homeId);
    return derivedSelectionFromTasks(homeTasks);
  }

  HealthResult get health => computeHealth(tasks, templateById, DateTime.now());
  List<CategoryHealth> get healthByCategory =>
      computeHealthByCategory(tasks, templateById, DateTime.now());
  int get streakWeeks => computeStreakWeeks(tasks, DateTime.now());

  double get belongingsTotal =>
      belongings.fold(0.0, (sum, b) => sum + b.value);

  List<TaskInstance> get upcoming =>
      tasks.where((t) => t.status == TaskStatus.upcoming).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<TaskInstance> get overdue =>
      upcoming.where((t) => t.isOverdue(DateTime.now())).toList();

  List<TaskInstance> get actionNeeded => overdue;

  double get spentThisYear {
    final y = DateTime.now().year;
    return expenses
        .where((e) => e.date.year == y)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// The "typical" comparison for the Spent card: the plan's own DIY costs
  /// for a year, from the task library (an honest internal yardstick, not a
  /// made-up national statistic).
  double get typicalYearSpend {
    var total = 0.0;
    for (final t in tasks) {
      final tpl = t.templateId == null ? null : templateById[t.templateId];
      if (tpl != null && tpl.frequencyMonths > 0) {
        total += tpl.diyCost * (12 / tpl.frequencyMonths);
      }
    }
    return total;
  }

  /// Switch the app colour. Persisted, and the whole app (light and
  /// dark alike) repaints in the new accent.
  Future<void> setAccent(AppAccent a) async {
    accent = a;
    await AppDb.setSetting('accent', a.name);
    notifyListeners();
  }

  Future<void> setEntitlement(Entitlement e) async {
    entitlement = e;
    await AppDb.setSetting(
      'entitlement',
      jsonEncode({
        'isPro': e.isPro,
        'source': e.source.name,
        'expiry': e.expiry?.toIso8601String(),
      }),
    );
    notifyListeners();
  }
}
