/// Nameplate reading: pull brand / model / serial out of the OCR text of
/// an appliance's metal plate. Pure function, unit-tested. Labelled
/// values ("MODEL: ...") win; otherwise plain heuristics: the brand is a
/// known maker named on the plate, the model is the longest token mixing
/// letters and digits, the serial is the most digit-heavy long token.
class NameplateResult {
  final String? brand;
  final String? model;
  final String? serial;

  const NameplateResult({this.brand, this.model, this.serial});
}

const knownBrands = [
  'Samsung', 'LG', 'Whirlpool', 'GE', 'Bosch', 'Frigidaire', 'Maytag',
  'Kenmore', 'Rheem', 'Carrier', 'Trane', 'Lennox', 'Goodman', 'Honeywell',
  'Moen', 'Kohler', 'Delta', 'Panasonic', 'Sony', 'Dyson', 'Electrolux',
  'Haier', 'Miele', 'KitchenAid', 'Amana', 'Bradford White', 'AO Smith',
  'Daikin', 'Mitsubishi',
];

NameplateResult parseNameplate(String text) {
  String? labelled(List<String> labels) {
    // "SERIAL NO: X" must not capture the word NO as the value.
    const junk = {'no', 'number', 'num', 'type', 'code', 'date'};
    for (final label in labels) {
      final m = RegExp('$label[:\\s]+([A-Za-z0-9\\-/]{2,30})',
              caseSensitive: false)
          .firstMatch(text);
      final v = m?.group(1)?.trim();
      if (v != null && v.isNotEmpty && !junk.contains(v.toLowerCase())) {
        return v;
      }
    }
    return null;
  }

  // Brand: a known maker appearing anywhere on the plate. Longest names
  // first so "Bradford White" wins over a stray shorter match.
  String? brand;
  final lower = text.toLowerCase();
  final sorted = [...knownBrands]
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final b in sorted) {
    // Word-boundary match so "GE" does not fire inside other words.
    if (RegExp(
            r'(^|[^a-z])' + RegExp.escape(b.toLowerCase()) + r'([^a-z]|$)',
            caseSensitive: false)
        .hasMatch(lower)) {
      brand = b;
      break;
    }
  }
  brand ??= labelled(['brand', 'make', 'manufacturer']);

  final tokens = RegExp(r'[A-Za-z0-9][A-Za-z0-9\-/]{2,29}')
      .allMatches(text)
      .map((m) => m.group(0)!)
      .toList();

  bool hasLetterAndDigit(String s) =>
      RegExp(r'[A-Za-z]').hasMatch(s) && RegExp(r'[0-9]').hasMatch(s);

  // Model: the longest alphanumeric token containing letters and digits,
  // 5 to 15 chars — how model numbers actually look.
  String? model = labelled(['model number', 'model no', 'model', 'mod']);
  if (model == null) {
    final candidates = tokens
        .where((t) => t.length >= 5 && t.length <= 15 && hasLetterAndDigit(t))
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (candidates.isNotEmpty) model = candidates.first;
  }

  // Serial: a long, digit-heavy token that is not the model.
  String? serial =
      labelled(['serial number', 'serial no', 'serial', 's/n', 'sn']);
  if (serial == null) {
    String? best;
    var bestDigits = 0;
    for (final t in tokens) {
      if (t == model || t.length < 6) continue;
      final digits = t.replaceAll(RegExp(r'[^0-9]'), '').length;
      if (digits >= 6 && digits / t.length >= 0.6 && digits > bestDigits) {
        best = t;
        bestDigits = digits;
      }
    }
    serial = best;
  }

  return NameplateResult(brand: brand, model: model, serial: serial);
}
