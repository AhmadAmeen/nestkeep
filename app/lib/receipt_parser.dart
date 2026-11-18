import 'models.dart';

/// Receipt OCR parsing. Input is the raw text lines from on-device ML Kit
/// recognition; output is a best-effort structured receipt that the user
/// always reviews and can edit before anything is saved. Heuristics are
/// deliberately conservative: a missed item is fine, a wrong total is not,
/// so the total prefers the line labelled TOTAL (never SUBTOTAL) and falls
/// back to the largest amount on the page.
class ParsedReceipt {
  final String store;
  final DateTime? date;
  final double? total;
  final List<ReceiptItem> items;

  ParsedReceipt({required this.store, this.date, this.total, required this.items});

  /// True when the read found invoice content: at least one priced
  /// item or a total. The scan flow's save gate (build 23) keys off
  /// this — a photo with no prices in it is not an invoice the app
  /// can file, so nothing from it is saved, image included.
  bool get hasPrices =>
      total != null || items.any((i) => i.price != null);
}

final _moneyRe = RegExp(r'\$?\s*(\d{1,6}[.,]\d{2})\b');
final _dateRes = [
  RegExp(r'\b(\d{1,2})/(\d{1,2})/(\d{2,4})\b'),
  RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b'),
  RegExp(
      r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})\b',
      caseSensitive: false),
];

const _skipLineWords = [
  'subtotal', 'tax', 'total', 'change', 'cash', 'visa', 'mastercard',
  'debit', 'credit', 'balance', 'tender', 'amount due', 'thank you',
  'welcome', 'receipt', 'tel', 'phone', 'www.', '.com', 'store #',
  'cashier', 'register', 'transaction', 'auth', 'approval', 'card',
];

double? _money(String s) {
  final m = _moneyRe.firstMatch(s);
  if (m == null) return null;
  return double.tryParse(m.group(1)!.replaceAll(',', '.'));
}

DateTime? _parseDate(String line) {
  var m = _dateRes[0].firstMatch(line);
  if (m != null) {
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    return DateTime(y, int.parse(m.group(1)!), int.parse(m.group(2)!));
  }
  m = _dateRes[1].firstMatch(line);
  if (m != null) {
    return DateTime(
        int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }
  m = _dateRes[2].firstMatch(line);
  if (m != null) {
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final mon = months[m.group(1)!.toLowerCase().substring(0, 3)];
    if (mon != null) {
      return DateTime(int.parse(m.group(3)!), mon, int.parse(m.group(2)!));
    }
  }
  return null;
}

ParsedReceipt parseReceipt(List<String> rawLines) {
  final lines = rawLines
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // Store: the first line that looks like a name, not a date, price or address.
  var store = '';
  for (final l in lines.take(4)) {
    final low = l.toLowerCase();
    if (_money(l) != null || _parseDate(l) != null) continue;
    if (RegExp(r'^\d+\s').hasMatch(l)) continue; // street address
    if (low.contains('welcome to')) {
      store = l.replaceAll(RegExp(r'welcome to', caseSensitive: false), '').trim();
      break;
    }
    store = l;
    break;
  }

  DateTime? date;
  for (final l in lines) {
    date = _parseDate(l);
    if (date != null) break;
  }

  // Total: prefer an explicit TOTAL line (not SUBTOTAL); else largest amount.
  double? total;
  for (final l in lines) {
    final low = l.toLowerCase();
    if (low.contains('total') && !low.contains('subtotal')) {
      final v = _money(l);
      if (v != null) total = v;
    }
  }
  if (total == null) {
    var largest = 0.0;
    for (final l in lines) {
      final v = _money(l);
      if (v != null && v > largest) largest = v;
    }
    if (largest > 0) total = largest;
  }

  // Items: lines ending in a price that are not summary lines.
  final items = <ReceiptItem>[];
  for (final l in lines) {
    final low = l.toLowerCase();
    if (_skipLineWords.any(low.contains)) continue;
    final m = _moneyRe.allMatches(l).toList();
    if (m.isEmpty) continue;
    final last = m.last;
    final price = double.tryParse(last.group(1)!.replaceAll(',', '.'));
    var name = l.substring(0, last.start).trim();
    name = name.replaceAll(RegExp(r'[.\s]+$'), '').trim();
    if (name.isEmpty || name.length < 2) continue;
    if (RegExp(r'^\d+$').hasMatch(name)) continue;
    items.add(ReceiptItem(name, price));
  }

  return ParsedReceipt(store: store, date: date, total: total, items: items);
}
