import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_state.dart';
import '../db.dart';
import '../lifespan.dart';
import '../models.dart';
import '../receipt_parser.dart';
import '../reminders.dart';
import '../sync.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/avatar_menu.dart';

/// Receipt scanning: fully on-device ML Kit OCR. Nothing leaves the phone.
/// The scan itself and the extracted data are free for everyone, unlimited.
/// Only storing + syncing the receipt IMAGE inside the app is Pro.
class ScanScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback? onAvatarTap;

  const ScanScreen({super.key, required this.state, this.onAvatarTap});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _scan(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final input = InputImage.fromFilePath(picked.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(input);
      await recognizer.close();
      final lines = <String>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          lines.add(line.text);
        }
      }
      final parsed = parseReceipt(lines);
      if (!mounted) return;
      final sheetResult = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ReceiptSheet(
          state: widget.state,
          parsed: parsed,
          sourceImagePath: picked.path,
        ),
      );
      await widget.state.reload();
      if (sheetResult == 'saved' && mounted) {
        showTicker(context, 'Receipt saved');
      }
    } catch (e) {
      setState(() => _error = 'That scan did not work. Try a flatter, brighter photo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Scan a receipt',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.navyText)),
            ),
            AvatarButton(state: widget.state, onTap: widget.onAvatarTap),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'NestKeep reads the store, date, items and total on your phone. '
          'Nothing is uploaded. You check every line before it saves.',
          style: TextStyle(color: context.muted, height: 1.4),
        ),
        const SizedBox(height: 20),
        NkCard(
          onTap: _busy ? null : () => _scan(ImageSource.camera),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.photo_camera_outlined,
                    color: context.primary, size: 27),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Take a photo',
                        style: TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.w700)),
                    Text('Flat, bright, whole receipt in frame'),
                  ],
                ),
              ),
              if (_busy)
                const CircularProgressIndicator()
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 12),
        NkCard(
          onTap: _busy ? null : () => _scan(ImageSource.gallery),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: NkColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.photo_library_outlined,
                    color: NkColors.green, size: 27),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pick from gallery',
                        style: TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.w700)),
                    Text('A photo or screenshot you already have'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: NkColors.red)),
        ],
        const SizedBox(height: 20),
        NkCard(
          accentLeft: NkColors.amber,
          child: Text(
            widget.state.isPro
                ? 'Pro: the receipt photo is kept in the app and backed up with your account, ready for a warranty claim.'
                : 'Free keeps the scan and all its data. Pro also keeps the receipt photo itself in the app, backed up for warranty claims.',
            style: TextStyle(color: context.muted, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// The receipt table modal, styled like the paper receipt itself. Every row
/// is editable; nothing saves until the user confirms.
class ReceiptSheet extends StatefulWidget {
  final AppState state;
  final ParsedReceipt parsed;
  final String sourceImagePath;

  const ReceiptSheet({
    super.key,
    required this.state,
    required this.parsed,
    required this.sourceImagePath,
  });

  @override
  State<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ItemRow {
  final TextEditingController name;
  final TextEditingController price;
  _ItemRow(String n, double? p)
      : name = TextEditingController(text: n),
        price = TextEditingController(text: p == null ? '' : p.toStringAsFixed(2));
}

class _ReceiptSheetState extends State<ReceiptSheet> {
  late final TextEditingController _store;
  late final TextEditingController _total;
  late final TextEditingController _applianceName;
  late DateTime _date;
  late final List<_ItemRow> _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _store = TextEditingController(
        text: widget.parsed.store.isEmpty ? 'Store' : widget.parsed.store);
    _total = TextEditingController(
        text: widget.parsed.total?.toStringAsFixed(2) ?? '');
    _date = widget.parsed.date ?? DateTime.now();
    _rows = widget.parsed.items.map((i) => _ItemRow(i.name, i.price)).toList();
    // The appliance this receipt is for defaults to the priciest item.
    var mainItem = '';
    var best = -1.0;
    for (final i in widget.parsed.items) {
      if ((i.price ?? 0) > best) {
        best = i.price ?? 0;
        mainItem = i.name;
      }
    }
    _applianceName = TextEditingController(text: mainItem);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final state = widget.state;
    final homeId = state.activeHome!.id!;
    final now = DateTime.now();
    final total = double.tryParse(_total.text.trim()) ?? 0.0;
    final items = _rows
        .where((r) => r.name.text.trim().isNotEmpty)
        .map((r) => ReceiptItem(
              r.name.text.trim(),
              double.tryParse(r.price.text.trim()),
            ))
        .toList();

    // Image gate (locked design): the scan and its data are free for
    // everyone. The photo itself is kept inside the app only for Pro;
    // free users' photos stay wherever they already were (their gallery).
    String? localImage;
    if (state.isPro) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final dest = p.join(dir.path,
            'receipt_${now.millisecondsSinceEpoch}${p.extension(widget.sourceImagePath)}');
        await File(widget.sourceImagePath).copy(dest);
        localImage = dest;
      } catch (_) {
        localImage = null;
      }
    }

    final receiptId = await AppDb.insertReceipt(Receipt(
      homeId: homeId,
      store: _store.text.trim(),
      date: _date,
      total: total,
      items: items,
      imagePath: localImage,
      updatedAt: now,
    ));

    final applianceName = _applianceName.text.trim();
    int? applianceId;
    // Free plans track up to freeApplianceLimit appliances. At the cap
    // the receipt and its expense still save; only the new appliance
    // record is skipped, quietly, rather than failing the whole scan.
    if (applianceName.isNotEmpty &&
        (state.isPro || state.appliances.length < freeApplianceLimit)) {
      applianceId = await AppDb.insertAppliance(Appliance(
        homeId: homeId,
        name: applianceName,
        purchaseDate: _date,
        warrantyMonths: typicalWarrantyMonths(applianceName),
        store: _store.text.trim(),
        price: total,
        receiptId: receiptId,
        imagePath: localImage,
        updatedAt: now,
      ));
    }

    if (total > 0) {
      await AppDb.insertExpense(Expense(
        homeId: homeId,
        date: _date,
        amount: total,
        category: 'Appliances',
        applianceId: applianceId,
        note: '${_store.text.trim()} receipt',
        updatedAt: now,
      ));
    }

    await state.reload();
    await Reminders.reschedule(state.tasks, state.appliances);
    SyncService.syncNow();
    if (state.isPro && SyncService.signedIn) {
      final saved = state.receipts.where((r) => r.id == receiptId).firstOrNull;
      if (saved != null) SyncService.syncReceiptImage(saved);
    }
    // Pop with the outcome so the Scan screen can confirm the save
    // once the sheet has closed (build 20).
    if (mounted) Navigator.of(context).pop('saved');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 60, 12, 12 + bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'RECEIPT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  letterSpacing: 4,
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
              TextField(
                controller: _store,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: Text(
                  '${_date.month}/${_date.day}/${_date.year}  ·  tap to change',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              const _DashedLine(),
              for (var i = 0; i < _rows.length; i++)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _rows[i].name,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Item',
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _rows[i].price,
                        textAlign: TextAlign.right,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0.00',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.black38),
                      onPressed: () => setState(() => _rows.removeAt(i)),
                    ),
                  ],
                ),
              TextButton.icon(
                onPressed: () => setState(() => _rows.add(_ItemRow('', null))),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add item'),
              ),
              const _DashedLine(),
              Row(
                children: [
                  const Expanded(
                    child: Text('TOTAL',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: Colors.black)),
                  ),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _total,
                      textAlign: TextAlign.right,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.black),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        prefixText: '\$ ',
                      ),
                    ),
                  ),
                ],
              ),
              const _DashedLine(),
              const Text(
                'This receipt is for (appliance or job):',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              TextField(
                controller: _applianceName,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  hintText: 'e.g. Samsung refrigerator',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.state.isPro
                    ? 'Saving starts its warranty clock and logs the spend. The photo is kept and backed up.'
                    : 'Saving starts its warranty clock and logs the spend. The photo stays in your gallery; Pro also keeps it in the app, backed up.',
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save receipt'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Discard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints.maxWidth / 9).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => Container(width: 5, height: 1.5, color: Colors.black26),
            ),
          );
        },
      ),
    );
  }
}
