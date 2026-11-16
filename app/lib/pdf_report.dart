import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';
import 'models.dart';

/// The PDF home report (Pro): a clean one-document summary of the home —
/// health score, what was done, what is coming, what it cost, and every
/// appliance with its warranty state. Built entirely on-device.
Future<void> shareHomeReport(AppState state) async {
  final home = state.activeHome!;
  final health = state.health;
  final now = DateTime.now();
  final doc = pw.Document();

  final byCategory = <String, double>{};
  for (final e in state.expenses) {
    byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
  }
  final done = state.tasks.where((t) => t.status == TaskStatus.done).toList()
    ..sort((a, b) => (b.doneDate ?? b.dueDate).compareTo(a.doneDate ?? a.dueDate));
  final upcoming = state.upcoming.take(12).toList();

  String d(DateTime x) => '${x.month}/${x.day}/${x.year}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      build: (ctx) => [
        pw.Text('NestKeep Home Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('${home.name} · ${home.addressLine} · built ${home.yearBuilt}'),
        pw.Text('Generated ${d(now)}'),
        pw.SizedBox(height: 16),
        pw.Text('Health Score: ${health.score} (${health.grade})',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text(health.statusSentence),
        pw.SizedBox(height: 16),
        pw.Text('Spending',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text('This year: \$${state.spentThisYear.toStringAsFixed(2)}'),
        for (final e in byCategory.entries)
          pw.Text('${e.key}: \$${e.value.toStringAsFixed(2)}'),
        pw.SizedBox(height: 16),
        pw.Text('Coming up',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        for (final t in upcoming) pw.Text('${d(t.dueDate)} — ${t.title}'),
        pw.SizedBox(height: 16),
        pw.Text('Completed',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        for (final t in done.take(30))
          pw.Text(
              '${t.doneDate == null ? '' : d(t.doneDate!)} — ${t.title}${t.costPaid != null && t.costPaid! > 0 ? ' (\$${t.costPaid!.toStringAsFixed(2)})' : ''}'),
        pw.SizedBox(height: 16),
        pw.Text('Appliances & warranties',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        for (final a in state.appliances)
          pw.Text(
              '${a.name}${a.brand != null ? ' (${a.brand} ${a.model ?? ''})' : ''} — bought ${a.purchaseDate == null ? 'date unknown' : d(a.purchaseDate!)}, warranty ${a.warrantyMonths} months${a.warrantyEnd != null ? ', ends ${d(a.warrantyEnd!)}' : ''}'),
      ],
    ),
  );

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/nestkeep-report.pdf');
  await file.writeAsBytes(await doc.save());
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
}
