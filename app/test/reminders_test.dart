import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/reminders.dart';

Appliance _appliance({DateTime? purchase, int months = 12}) => Appliance(
      homeId: 1,
      name: 'Washer',
      purchaseDate: purchase,
      warrantyMonths: months,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('warrantySlots', () {
    test('warns 30 days before expiry and on the day', () {
      final slots = Reminders.warrantySlots(
        _appliance(purchase: DateTime(2026, 1, 15)),
        DateTime(2026, 6, 1),
      );
      expect(slots.length, 2);
      expect(slots[0].$1, DateTime(2026, 12, 16));
      expect(slots[0].$2, contains('ends in 30 days'));
      expect(slots[1].$1, DateTime(2027, 1, 15));
      expect(slots[1].$2, contains('ends today'));
    });

    test('drops warnings already past', () {
      final slots = Reminders.warrantySlots(
        _appliance(purchase: DateTime(2026, 1, 15)),
        DateTime(2027, 1, 1),
      );
      expect(slots.length, 1);
      expect(slots.single.$1, DateTime(2027, 1, 15));
    });

    test('no purchase date, no warnings', () {
      expect(
        Reminders.warrantySlots(_appliance(), DateTime(2026, 6, 1)),
        isEmpty,
      );
    });

    test('month overflow rolls into the next year', () {
      final slots = Reminders.warrantySlots(
        _appliance(purchase: DateTime(2026, 11, 20), months: 3),
        DateTime(2026, 12, 1),
      );
      expect(slots.last.$1, DateTime(2027, 2, 20));
    });
  });
}
