import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/plan.dart';

TaskTemplate tpl(String id, String category, {List<String> req = const []}) =>
    TaskTemplate(
      id: id,
      category: category,
      title: id,
      frequencyMonths: 12,
      seasons: const [],
      diyCost: 10,
      ignoreCost: 100,
      difficulty: 'Easy',
      minutes: 10,
      why: 'why',
      steps: const ['step'],
      needs: const [],
      requiresAny: req,
    );

HomeProfile profile({bool pool = false}) => HomeProfile(
      homeType: 'house',
      heating: 'forced_air',
      cooling: 'central',
      hasBasement: true,
      hasGarage: true,
      hasDeck: true,
      hasSprinklers: false,
      hasSoftener: false,
      hasChimney: false,
      hasPool: pool,
    );

TaskInstance instance(String? templateId, TaskStatus status) => TaskInstance(
      homeId: 1,
      templateId: templateId,
      title: 't',
      category: 'HVAC',
      dueDate: DateTime(2026, 1, 1),
      status: status,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('planSelectionDiff', () {
    test('splits a change into added and removed', () {
      final diff = planSelectionDiff({'a', 'b', 'c'}, {'b', 'c', 'd', 'e'});
      expect(diff.added, {'d', 'e'});
      expect(diff.removed, {'a'});
    });

    test('identical selections change nothing', () {
      final diff = planSelectionDiff({'a', 'b'}, {'a', 'b'});
      expect(diff.added, isEmpty);
      expect(diff.removed, isEmpty);
    });

    test('empty to full is all additions, full to empty all removals', () {
      final up = planSelectionDiff({}, {'a'});
      expect(up.added, {'a'});
      expect(up.removed, isEmpty);
      final down = planSelectionDiff({'a'}, {});
      expect(down.added, isEmpty);
      expect(down.removed, {'a'});
    });
  });

  group('templatesForPlan (what generatePlan instantiates)', () {
    final templates = [
      tpl('hvac-filter', 'HVAC'),
      tpl('pool-filter', 'Exterior', req: ['pool']),
      tpl('gutter-clean', 'Roof & Gutters'),
    ];

    test('no explicit selection: the profile decides', () {
      final chosen = templatesForPlan(templates, profile(), null);
      expect(chosen.map((t) => t.id), ['hvac-filter', 'gutter-clean']);
      final withPool = templatesForPlan(templates, profile(pool: true), null);
      expect(withPool.map((t) => t.id),
          ['pool-filter', 'hvac-filter', 'gutter-clean']);
    });

    test('explicit selection wins over the profile', () {
      // The pool job is ticked even though the home has no pool: the
      // user's tick beats their answers. The unticked universal job
      // stays out even though it applies to every home.
      final chosen =
          templatesForPlan(templates, profile(), {'pool-filter'});
      expect(chosen.map((t) => t.id), ['pool-filter']);
    });

    test('an empty explicit selection builds an empty plan', () {
      expect(templatesForPlan(templates, profile(pool: true), {}), isEmpty);
    });

    test('unknown ids in the selection are ignored', () {
      final chosen =
          templatesForPlan(templates, profile(), {'hvac-filter', 'nope'});
      expect(chosen.map((t) => t.id), ['hvac-filter']);
    });
  });

  group('derivedSelectionFromTasks', () {
    test('collects template ids from any status, skips custom jobs', () {
      final tasks = [
        instance('hvac-filter', TaskStatus.upcoming),
        instance('hvac-filter', TaskStatus.done),
        instance('pool-filter', TaskStatus.skipped),
        instance(null, TaskStatus.upcoming),
      ];
      expect(derivedSelectionFromTasks(tasks), {'hvac-filter', 'pool-filter'});
    });

    test('no jobs means no selection', () {
      expect(derivedSelectionFromTasks(const []), isEmpty);
    });
  });
}
