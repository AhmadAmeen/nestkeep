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
  });

  bool get isApartmentLike => homeType == 'condo' || homeType == 'apartment';
}

/// Which templates a profile should NOT get, by template id.
bool templateApplies(TaskTemplate t, HomeProfile p) {
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
  return true;
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

/// Generate and store the full plan for a home. Returns how many jobs.
Future<int> generatePlan(
  int homeId,
  HomeProfile profile,
  List<TaskTemplate> templates,
  DateTime now,
) async {
  final applicable = templates.where((t) => templateApplies(t, profile)).toList()
    ..sort((a, b) => a.category.compareTo(b.category));
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
