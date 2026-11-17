import 'dart:convert';

import 'db.dart';
import 'models.dart';

/// Onboarding answers. A handful of questions, then the plan is generated
/// locally in under a minute. No account, no server.
class HomeProfile {
  final String homeType; // house, townhouse, condo, apartment
  final String heating; // forced_air, heat_pump, boiler, none
  final String cooling; // central, window, none
  final bool hasBasement;
  final bool hasGarage;
  final bool hasDeck;
  final bool hasSprinklers;
  final bool hasSoftener;
  final bool hasChimney;
  final bool hasPool;
  final bool hasSeptic;
  final bool hasWell;
  final bool hasSolar;
  final bool hasGenerator;
  final bool hasEvCharger;
  final String climate; // cold, mild, hot (how hard winters bite)

  const HomeProfile({
    required this.homeType,
    required this.heating,
    required this.cooling,
    required this.hasBasement,
    required this.hasGarage,
    required this.hasDeck,
    required this.hasSprinklers,
    required this.hasSoftener,
    required this.hasChimney,
    this.hasPool = false,
    this.hasSeptic = false,
    this.hasWell = false,
    this.hasSolar = false,
    this.hasGenerator = false,
    this.hasEvCharger = false,
    this.climate = 'mild',
  });

  bool get isApartmentLike => homeType == 'condo' || homeType == 'apartment';

  /// The answer flags templates match against (TaskTemplate.requiresAny).
  Set<String> get flags => {
        if (hasBasement) 'basement',
        if (hasGarage) 'garage',
        if (hasDeck) 'deck',
        if (hasSprinklers) 'sprinklers',
        if (hasSoftener) 'softener',
        if (hasChimney) 'chimney',
        if (hasPool) 'pool',
        if (hasSeptic) 'septic',
        if (hasWell) 'well',
        if (hasSolar) 'solar',
        if (hasGenerator) 'generator',
        if (hasEvCharger) 'ev',
        'heating_$heating',
        'cooling_$cooling',
        if (isApartmentLike) 'apartment_like',
      };

  Map<String, dynamic> toJson() => {
        'homeType': homeType,
        'heating': heating,
        'cooling': cooling,
        'hasBasement': hasBasement,
        'hasGarage': hasGarage,
        'hasDeck': hasDeck,
        'hasSprinklers': hasSprinklers,
        'hasSoftener': hasSoftener,
        'hasChimney': hasChimney,
        'hasPool': hasPool,
        'hasSeptic': hasSeptic,
        'hasWell': hasWell,
        'hasSolar': hasSolar,
        'hasGenerator': hasGenerator,
        'hasEvCharger': hasEvCharger,
        'climate': climate,
      };

  factory HomeProfile.fromJson(Map<String, dynamic> j) => HomeProfile(
        homeType: j['homeType'] as String? ?? 'house',
        heating: j['heating'] as String? ?? 'forced_air',
        cooling: j['cooling'] as String? ?? 'central',
        hasBasement: j['hasBasement'] as bool? ?? false,
        hasGarage: j['hasGarage'] as bool? ?? false,
        hasDeck: j['hasDeck'] as bool? ?? false,
        hasSprinklers: j['hasSprinklers'] as bool? ?? false,
        hasSoftener: j['hasSoftener'] as bool? ?? false,
        hasChimney: j['hasChimney'] as bool? ?? false,
        hasPool: j['hasPool'] as bool? ?? false,
        hasSeptic: j['hasSeptic'] as bool? ?? false,
        hasWell: j['hasWell'] as bool? ?? false,
        hasSolar: j['hasSolar'] as bool? ?? false,
        hasGenerator: j['hasGenerator'] as bool? ?? false,
        hasEvCharger: j['hasEvCharger'] as bool? ?? false,
        climate: j['climate'] as String? ?? 'mild',
      );
}

/// The profile is stored per home so the plan can explain itself later
/// ("in your plan because...") and show what was left out.
Future<void> saveProfile(int homeId, HomeProfile profile) =>
    AppDb.setSetting('profile_$homeId', jsonEncode(profile.toJson()));

Future<HomeProfile?> loadProfile(int homeId) async {
  final raw = await AppDb.getSetting('profile_$homeId');
  if (raw == null) return null;
  try {
    return HomeProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// Which templates a profile should NOT get, by template id.
bool templateApplies(TaskTemplate t, HomeProfile p) {
  // Data-driven gate: a template that names required answers only
  // applies when the home actually has one of them (pool, septic, ...).
  if (t.requiresAny.isNotEmpty && !t.requiresAny.any(p.flags.contains)) {
    return false;
  }
  final id = t.id;
  if (p.isApartmentLike) {
    // Renters and condo owners do not own the roof, shell or grounds.
    if (t.category == 'Roof & Gutters') return false;
    const excluded = {
      'ext-foundation', 'ext-driveway', 'ext-siding-wash', 'ext-deck',
      'ext-fence', 'ext-caulk', 'ext-paint', 'ext-sprinkler-start',
      'ext-sprinkler-blowout', 'plumb-winterize-faucets',
      'seasonal-window-ac', // still possible; handled below by cooling
    };
    if (excluded.contains(id) && id != 'seasonal-window-ac') return false;
  }
  if (!p.hasBasement) {
    const basementOnly = {
      'plumb-sump', 'int-floor-drains', 'appl-dehumidifier', 'safety-radon',
      'int-attic-pests', 'roof-attic',
    };
    if (basementOnly.contains(id)) return false;
  }
  if (!p.hasGarage && id == 'ext-garage-door') return false;
  if (!p.hasDeck && id == 'ext-deck') return false;
  if (!p.hasSprinklers &&
      (id == 'ext-sprinkler-start' || id == 'ext-sprinkler-blowout')) {
    return false;
  }
  if (!p.hasSoftener && id == 'plumb-softener') return false;
  if (!p.hasChimney && id == 'roof-chimney') return false;
  if (p.cooling == 'none' &&
      (id == 'hvac-condenser' || id == 'hvac-ac-service' || id == 'hvac-condensate')) {
    return false;
  }
  if (p.cooling != 'window' && id == 'seasonal-window-ac') return false;
  if (p.heating == 'none' &&
      (id == 'hvac-furnace-service' || id == 'hvac-humidifier' || id == 'hvac-furnace-filter-slot')) {
    return false;
  }
  if (p.heating == 'boiler' && id == 'hvac-filter') return false;
  // Winterizing outdoor faucets only matters where winters actually freeze.
  if (id == 'plumb-winterize-faucets' && p.climate != 'cold') return false;
  return true;
}

/// Why a job is in this home's plan, in the user's own terms, or null
/// for jobs every home gets. Shown on the task guide so the plan reads
/// as built for this home, not handed to everyone.
String? planReason(TaskTemplate t, HomeProfile p) {
  const reasons = {
    'ext-deck': 'you have a deck or patio',
    'ext-garage-door': 'you have a garage',
    'plumb-sump': 'you have a basement or crawlspace',
    'int-floor-drains': 'you have a basement or crawlspace',
    'appl-dehumidifier': 'you have a basement or crawlspace',
    'safety-radon': 'you have a basement or crawlspace',
    'int-attic-pests': 'you have a basement or crawlspace',
    'roof-attic': 'you have a basement or crawlspace',
    'ext-sprinkler-start': 'you have a sprinkler system',
    'ext-sprinkler-blowout': 'you have a sprinkler system',
    'plumb-softener': 'you have a water softener',
    'roof-chimney': 'you have a fireplace or chimney',
    'pool-filter': 'you have a pool or hot tub',
    'pool-chemistry': 'you have a pool or hot tub',
    'septic-pump': 'your home runs on a septic system',
    'well-test': 'your home draws well water',
    'well-filter': 'your home draws well water',
    'solar-clean': 'you have solar panels',
    'gen-test': 'you have a standby generator',
    'gen-service': 'you have a standby generator',
    'ev-charger-check': 'you charge an EV at home',
    'ev-charger-service': 'you charge an EV at home',
    'plumb-winterize-faucets': 'you have freezing winters',
    'seasonal-window-ac': 'you cool with window units',
  };
  final r = reasons[t.id];
  if (r != null) return r;
  if (t.id == 'hvac-filter' || t.id == 'hvac-furnace-filter-slot') {
    if (p.heating == 'forced_air') return 'you heat with a forced-air furnace';
    if (p.heating == 'heat_pump') return 'you heat with a heat pump';
  }
  if (t.id == 'hvac-furnace-service' || t.id == 'hvac-humidifier') {
    return 'you heat with a forced-air furnace';
  }
  if (t.id == 'hvac-condenser' ||
      t.id == 'hvac-ac-service' ||
      t.id == 'hvac-condensate') {
    return 'you have central air conditioning';
  }
  return null;
}

const _seasonStartMonth = {'spring': 3, 'summer': 6, 'fall': 9, 'winter': 12};

/// First due date for a template: seasonal jobs land at the start of their
/// next season (or a week from now if that season is already here); the rest
/// are staggered across the next couple of months so day one is not a wall.
DateTime firstDueDate(TaskTemplate t, DateTime now, int staggerIndex) {
  final today = DateTime(now.year, now.month, now.day);
  if (t.seasons.isNotEmpty) {
    DateTime? best;
    for (final s in t.seasons) {
      final m = _seasonStartMonth[s]!;
      var candidate = DateTime(now.year, m, 1);
      if (candidate.isBefore(today.subtract(const Duration(days: 60)))) {
        candidate = DateTime(now.year + 1, m, 1);
      }
      if (best == null || candidate.isBefore(best)) best = candidate;
    }
    final d = best!;
    if (d.isBefore(today)) return today.add(const Duration(days: 7));
    return d;
  }
  return today.add(Duration(days: 10 + (staggerIndex * 5) % 75));
}

/// The next due date after a completion: the job's own clock restarts.
DateTime nextDueAfter(TaskTemplate t, DateTime doneDate) {
  return DateTime(
    doneDate.year,
    doneDate.month + t.frequencyMonths,
    doneDate.day,
  );
}

/// Which templates a plan build instantiates, in plan order. With no
/// explicit selection, the profile decides (templateApplies). With an
/// explicit selection, the user's ticks win outright: they may tick a
/// job their answers would have excluded, and unticked jobs stay out
/// even when their answers would have included them.
List<TaskTemplate> templatesForPlan(
  List<TaskTemplate> templates,
  HomeProfile profile,
  Set<String>? onlyTemplateIds,
) {
  final chosen = onlyTemplateIds == null
      ? templates.where((t) => templateApplies(t, profile)).toList()
      : templates.where((t) => onlyTemplateIds.contains(t.id)).toList();
  chosen.sort((a, b) => a.category.compareTo(b.category));
  return chosen;
}

/// Generate and store the full plan for a home. Returns how many jobs.
/// When [onlyTemplateIds] is given, only those library jobs are created
/// (the user's own ticked selection); otherwise the profile decides.
Future<int> generatePlan(
  int homeId,
  HomeProfile profile,
  List<TaskTemplate> templates,
  DateTime now, {
  Set<String>? onlyTemplateIds,
}) async {
  final applicable = templatesForPlan(templates, profile, onlyTemplateIds);
  var i = 0;
  for (final t in applicable) {
    await AppDb.insertTask(TaskInstance(
      homeId: homeId,
      templateId: t.id,
      title: t.title,
      category: t.category,
      dueDate: firstDueDate(t, now, i),
      updatedAt: now,
    ));
    i++;
  }
  return applicable.length;
}

/// What changed between two job selections: the templates to start
/// (added) and the templates to stop (removed).
({Set<String> added, Set<String> removed}) planSelectionDiff(
  Set<String> oldSet,
  Set<String> newSet,
) =>
    (
      added: newSet.difference(oldSet),
      removed: oldSet.difference(newSet),
    );

/// The user's ticked library jobs for a home, stored per home so the
/// picker reopens exactly where they left it.
Future<void> savePlanSelection(int homeId, Set<String> templateIds) =>
    AppDb.setSetting(
      'selected_templates_$homeId',
      jsonEncode(templateIds.toList()..sort()),
    );

/// The stored selection, or null when this home has none yet (installs
/// from before build 10 never saved one).
Future<Set<String>?> loadPlanSelection(int homeId) async {
  final raw = await AppDb.getSetting('selected_templates_$homeId');
  if (raw == null) return null;
  try {
    return (jsonDecode(raw) as List).cast<String>().toSet();
  } catch (_) {
    return null;
  }
}

/// The selection implied by a home's existing jobs: every template that
/// already has an instance (any status) counts as chosen. This is the
/// fallback for homes planned before selections existed.
Set<String> derivedSelectionFromTasks(List<TaskInstance> tasks) => {
      for (final t in tasks)
        if (t.templateId != null) t.templateId!,
    };

/// Apply a picker save to a home's live plan: newly ticked templates get
/// their next upcoming instance (first due date by the same schedule the
/// plan builder uses), unticked templates lose their upcoming instances
/// (done and skipped history is never touched), and the new selection is
/// persisted. The caller reloads state and reschedules reminders.
Future<void> applyPlanSelection({
  required int homeId,
  required Set<String> newSelection,
  required List<TaskTemplate> templates,
  required List<TaskInstance> currentTasks,
  required DateTime now,
}) async {
  final oldSelection =
      await loadPlanSelection(homeId) ?? derivedSelectionFromTasks(currentTasks);
  final diff = planSelectionDiff(oldSelection, newSelection);

  for (final task in currentTasks) {
    if (task.templateId != null &&
        diff.removed.contains(task.templateId) &&
        task.status == TaskStatus.upcoming) {
      await AppDb.deleteTask(task.id!);
    }
  }

  final byId = {for (final t in templates) t.id: t};
  var stagger = 0;
  for (final id in diff.added) {
    final t = byId[id];
    if (t == null) continue;
    final alreadyLive = currentTasks.any(
        (x) => x.templateId == id && x.status == TaskStatus.upcoming);
    if (alreadyLive) continue;
    await AppDb.insertTask(TaskInstance(
      homeId: homeId,
      templateId: t.id,
      title: t.title,
      category: t.category,
      dueDate: firstDueDate(t, now, stagger),
      updatedAt: now,
    ));
    stagger++;
  }

  await savePlanSelection(homeId, newSelection);
}

/// How many of their own jobs a free plan can hold at one time.
/// Pro is unlimited.
const freeCustomJobLimit = 10;

/// Jobs the user added themselves (no template) that are still live in
/// the plan. Done and skipped jobs free their slot back up.
int activeCustomJobs(List<TaskInstance> tasks) => tasks
    .where((t) => t.templateId == null && t.status == TaskStatus.upcoming)
    .length;
