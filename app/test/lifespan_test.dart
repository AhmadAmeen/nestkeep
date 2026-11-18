import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/lifespan.dart';
import 'package:nestkeep/models.dart';

Appliance _appliance({
  String name = 'Toaster',
  DateTime? purchaseDate,
  int? lifespanYears,
}) =>
    Appliance(
      homeId: 1,
      name: name,
      purchaseDate: purchaseDate,
      warrantyMonths: 12,
      lifespanYears: lifespanYears,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  final now = DateTime(2026, 6, 15);

  DateTime yearsAgo(double years) =>
      now.subtract(Duration(days: (years * 365.25).round()));

  group('typicalLifespanYears', () {
    test('matches the common kinds', () {
      expect(typicalLifespanYears('Refrigerator'), 12);
      expect(typicalLifespanYears('Chest freezer'), 16);
      expect(typicalLifespanYears('Washing machine'), 10);
      expect(typicalLifespanYears('Tumble dryer'), 10);
      expect(typicalLifespanYears('Dishwasher'), 10);
      expect(typicalLifespanYears('Water heater'), 12);
      expect(typicalLifespanYears('Furnace'), 15);
      expect(typicalLifespanYears('Heat pump'), 15);
      expect(typicalLifespanYears('Gas range'), 15);
      expect(typicalLifespanYears('Microwave'), 9);
      expect(typicalLifespanYears('Boiler'), 20);
    });

    test('is case-insensitive and falls back to 10', () {
      expect(typicalLifespanYears('FRIDGE'), 12);
      expect(typicalLifespanYears('Toaster oven'), 15); // contains "oven"
      expect(typicalLifespanYears('Espresso machine'), 10);
    });
  });

  group('effectiveLifespan', () {
    test('the owner number wins over the typical one', () {
      expect(effectiveLifespan(_appliance(name: 'Fridge')), 12);
      expect(
        effectiveLifespan(_appliance(name: 'Fridge', lifespanYears: 18)),
        18,
      );
    });
  });

  group('lifeUsed and lifeStatus', () {
    test('no purchase date means no clock', () {
      final a = _appliance();
      expect(lifeUsed(a, now), 0);
      expect(lifeStatus(a, now), LifeStatus.good);
    });

    test('half-way through a 10-year life is good', () {
      final a = _appliance(purchaseDate: yearsAgo(5), lifespanYears: 10);
      expect(lifeUsed(a, now), closeTo(0.5, 0.01));
      expect(lifeStatus(a, now), LifeStatus.good);
    });

    test('the 0.7 band edge separates good from monitor', () {
      final under = _appliance(purchaseDate: yearsAgo(6.9), lifespanYears: 10);
      final over = _appliance(purchaseDate: yearsAgo(7.1), lifespanYears: 10);
      expect(lifeStatus(under, now), LifeStatus.good);
      expect(lifeStatus(over, now), LifeStatus.monitor);
    });

    test('the 0.95 band edge separates monitor from replace soon', () {
      final under = _appliance(purchaseDate: yearsAgo(9.4), lifespanYears: 10);
      final over = _appliance(purchaseDate: yearsAgo(9.6), lifespanYears: 10);
      expect(lifeStatus(under, now), LifeStatus.monitor);
      expect(lifeStatus(over, now), LifeStatus.replaceSoon);
    });

    test('used is clamped at 1.2 for very old appliances', () {
      final a = _appliance(purchaseDate: yearsAgo(30), lifespanYears: 10);
      expect(lifeUsed(a, now), 1.2);
      expect(lifeStatus(a, now), LifeStatus.replaceSoon);
    });
  });

  group('lifeRemaining (what the bar draws, build 24)', () {
    test('a new appliance starts full', () {
      final a = _appliance(purchaseDate: now, lifespanYears: 10);
      expect(lifeRemaining(a, now), closeTo(1.0, 0.01));
    });

    test('it drains with age: a quarter used leaves three quarters', () {
      final a = _appliance(purchaseDate: yearsAgo(3), lifespanYears: 12);
      expect(lifeRemaining(a, now), closeTo(0.75, 0.01));
    });

    test('at and past the end of its life it is empty', () {
      final at = _appliance(purchaseDate: yearsAgo(10), lifespanYears: 10);
      expect(lifeRemaining(at, now), closeTo(0.0, 0.01));
      final past = _appliance(purchaseDate: yearsAgo(30), lifespanYears: 10);
      expect(lifeRemaining(past, now), 0);
    });

    test('no purchase date means no clock: the track stays empty', () {
      expect(lifeRemaining(_appliance(), now), 0);
    });
  });

  group('labels', () {
    test('year index counts the year the appliance is in', () {
      final a = _appliance(
          name: 'Fridge', purchaseDate: yearsAgo(2.5)); // typical 12
      expect(lifeLabel(a, now), 'Year 3 of about 12');
    });

    test('past its lifespan the label shows plain age', () {
      final a = _appliance(name: 'Fridge', purchaseDate: yearsAgo(13.2));
      expect(lifeLabel(a, now), 'Year 13 of about 12');
    });

    test('life left rounds up, and replace-soon asks for a budget', () {
      final mid = _appliance(name: 'Fridge', purchaseDate: yearsAgo(3));
      expect(lifeLeftLabel(mid, now), 'Life left ~9 yrs');
      final old = _appliance(name: 'Fridge', purchaseDate: yearsAgo(12.5));
      expect(lifeLeftLabel(old, now), 'Budget for a new one');
    });

    test('status labels read plainly', () {
      expect(lifeStatusLabel(LifeStatus.good), 'Good shape');
      expect(lifeStatusLabel(LifeStatus.monitor), 'Monitor');
      expect(lifeStatusLabel(LifeStatus.replaceSoon), 'Replace soon');
    });
  });

  test('the free plan tracks five appliances', () {
    expect(freeApplianceLimit, 5);
  });
}
