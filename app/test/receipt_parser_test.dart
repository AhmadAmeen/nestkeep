import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/receipt_parser.dart';

void main() {
  test('home depot receipt: store, date, total, items', () {
    final r = parseReceipt([
      'THE HOME DEPOT',
      '123 Main St',
      '11/02/2026 10:24 AM',
      'SAMSUNG REFRIGERATOR RF28  899.00',
      'EXT WARRANTY 3YR  129.99',
      'SUBTOTAL  1028.99',
      'SALES TAX  82.32',
      'TOTAL  1111.31',
      'VISA  1111.31',
      'THANK YOU',
    ]);
    expect(r.store, contains('HOME DEPOT'));
    expect(r.date, DateTime(2026, 11, 2));
    expect(r.total, 1111.31);
    expect(r.items.length, 2);
    expect(r.items.first.name, contains('REFRIGERATOR'));
    expect(r.items.first.price, 899.00);
  });

  test('total falls back to the largest amount when unlabelled', () {
    final r = parseReceipt([
      'COSTCO WHOLESALE',
      'FILTER 4-PACK 24.99',
      'BATTERIES 12.50',
      '137.49',
    ]);
    expect(r.total, 137.49);
    expect(r.items.length, 2);
  });

  test('month-name dates parse', () {
    final r = parseReceipt([
      'LOWES',
      'Nov 5, 2026',
      'WATER HEATER 50GAL 649.00',
      'TOTAL 649.00',
    ]);
    expect(r.date, DateTime(2026, 11, 5));
    expect(r.total, 649.00);
  });

  test('summary lines never become items', () {
    final r = parseReceipt([
      'TARGET',
      'DETERGENT 15.99',
      'SUBTOTAL 15.99',
      'TAX 1.28',
      'TOTAL 17.27',
      'CHANGE 2.73',
      'CASH 20.00',
    ]);
    expect(r.items.length, 1);
    expect(r.total, 17.27);
  });
}
