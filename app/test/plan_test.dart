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

HomeProfile profile({
  String type = 'house',
  bool pool = false,
  bool septic = false,
  bool deck = true,
}) =>
    HomeProfile(
      homeType: type,
      heating: 'forced_air',
      cooling: 'central',
      hasBasement: true,
      hasGarage: true,
      hasDeck: deck,
      hasSprinklers: false,
      hasSoftener: false,
      hasChimney: false,
      hasPool: pool,
      hasSeptic: septic,
    );

void main() {
  test('feature jobs stay out until the home has the feature', () {
    final poolJob = tpl('pool-filter', 'Exterior', req: ['pool']);
    final septicJob = tpl('septic-pump', 'Plumbing', req: ['septic']);
    expect(templateApplies(poolJob, profile()), isFalse);
    expect(templateApplies(septicJob, profile()), isFalse);
    expect(templateApplies(poolJob, profile(pool: true)), isTrue);
    expect(templateApplies(septicJob, profile(septic: true)), isTrue);
  });

  test('universal jobs apply to every profile', () {
    final t = tpl('hvac-filter', 'HVAC');
    expect(templateApplies(t, profile()), isTrue);
    expect(templateApplies(t, profile(type: 'apartment')), isTrue);
  });

  test('apartments never get exterior ownership jobs', () {
    final deck = tpl('ext-deck', 'Exterior');
    expect(templateApplies(deck, profile()), isTrue);
    expect(templateApplies(deck, profile(type: 'apartment')), isFalse);
  });

  test('plan reasons speak in the user answers', () {
    final p = profile(pool: true);
    expect(planReason(tpl('pool-filter', 'Exterior', req: ['pool']), p),
        'you have a pool or hot tub');
    expect(planReason(tpl('ext-deck', 'Exterior'), p), 'you have a deck or patio');
    expect(planReason(tpl('hvac-filter', 'HVAC'), p),
        'you heat with a forced-air furnace');
    expect(planReason(tpl('safety-smoke-test', 'Safety'), p), isNull);
  });
}
