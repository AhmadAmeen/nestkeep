import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/nameplate.dart';

void main() {
  test('labelled plate: brand matched, model and serial read', () {
    const text = '''
      SAMSUNG ELECTRONICS
      MODEL: RF28R7351SR
      SERIAL NO: 0A1B54AN700123X
      115V 60Hz
    ''';
    final r = parseNameplate(text);
    expect(r.brand, 'Samsung');
    expect(r.model, 'RF28R7351SR');
    expect(r.serial, '0A1B54AN700123X');
  });

  test('unlabelled plate: heuristics find model and serial', () {
    const text = 'Whirlpool WDT750SAKZ 24 INCH DISHWASHER SER 9876543210';
    final r = parseNameplate(text);
    expect(r.brand, 'Whirlpool');
    expect(r.model, 'WDT750SAKZ');
    expect(r.serial, '9876543210');
  });

  test('multi-word brands win and GE does not fire inside words', () {
    final r = parseNameplate('BRADFORD WHITE WATER HEATER MODEL MI403T6FBN');
    expect(r.brand, 'Bradford White');
    expect(r.model, 'MI403T6FBN');
    final g = parseNameplate('MANAGED STORAGE UNIT 12345');
    expect(g.brand, isNull);
  });

  test('empty text yields nothing', () {
    final r = parseNameplate('');
    expect(r.brand, isNull);
    expect(r.model, isNull);
    expect(r.serial, isNull);
  });
}
