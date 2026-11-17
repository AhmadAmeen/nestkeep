import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../db.dart';
import '../lifespan.dart';
import '../models.dart';
import '../nameplate.dart';
import '../reminders.dart';
import '../sync.dart';
import '../theme.dart';

/// Add or edit an appliance. Includes a nameplate scan: photograph the
/// metal plate on the appliance and the form fills brand / model / serial
/// from the text it finds (on-device OCR, same as receipts).
class ApplianceFormScreen extends StatefulWidget {
  final AppState state;
  final Appliance? existing;

  /// Where to send a free user who tries to add appliance number six.
  /// Optional so older call sites keep working; without it the form
  /// explains the limit in a snackbar instead.
  final VoidCallback? onOpenPaywall;

  const ApplianceFormScreen({
    super.key,
    required this.state,
    this.existing,
    this.onOpenPaywall,
  });

  @override
  State<ApplianceFormScreen> createState() => _ApplianceFormScreenState();
}

class _ApplianceFormScreenState extends State<ApplianceFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _serial;
  late final TextEditingController _store;
  late final TextEditingController _price;
  late final TextEditingController _notes;
  late final TextEditingController _lifeYears;
  late DateTime? _purchaseDate;
  late int _warrantyMonths;
  bool _scanning = false;
  bool _lifeEdited = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _name = TextEditingController(text: a?.name ?? '');
    _brand = TextEditingController(text: a?.brand ?? '');
    _model = TextEditingController(text: a?.model ?? '');
    _serial = TextEditingController(text: a?.serial ?? '');
    _store = TextEditingController(text: a?.store ?? '');
    _price = TextEditingController(
        text: a?.price == null ? '' : a!.price!.toStringAsFixed(2));
    _notes = TextEditingController(text: a?.notes ?? '');
    _lifeYears = TextEditingController(
        text: a == null ? '' : effectiveLifespan(a).toString());
    _purchaseDate = a?.purchaseDate;
    _warrantyMonths = a?.warrantyMonths ?? 12;
    _name.addListener(() {
      if (widget.existing == null) {
        setState(() => _warrantyMonths = typicalWarrantyMonths(_name.text));
        // Keep the expected-life field tracking the name until the
        // user types their own number into it.
        if (!_lifeEdited) {
          _lifeYears.text = typicalLifespanYears(_name.text).toString();
        }
      }
    });
  }

  Future<void> _scanNameplate() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    setState(() => _scanning = true);
    try {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result =
          await recognizer.processImage(InputImage.fromFilePath(picked.path));
      await recognizer.close();
      // Prefill only: the user checks and edits before anything saves.
      final found = parseNameplate(result.text);
      setState(() {
        if (found.brand != null) _brand.text = found.brand!;
        if (found.model != null) _model.text = found.model!;
        if (found.serial != null) _serial.text = found.serial!;
      });
    } catch (_) {
      // A failed plate scan just leaves the fields for typing.
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    // Free plans track up to freeApplianceLimit appliances; a new one
    // past that is a Pro moment. Editing an existing appliance is
    // never blocked.
    if (widget.existing == null &&
        !widget.state.isPro &&
        widget.state.appliances.length >= freeApplianceLimit) {
      if (widget.onOpenPaywall != null) {
        widget.onOpenPaywall!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Free plans track up to $freeApplianceLimit appliances. '
                'Pro tracks every appliance in the house.'),
          ),
        );
      }
      return;
    }
    final now = DateTime.now();
    final a = Appliance(
      id: widget.existing?.id,
      homeId: widget.state.activeHome!.id!,
      name: _name.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      model: _model.text.trim().isEmpty ? null : _model.text.trim(),
      serial: _serial.text.trim().isEmpty ? null : _serial.text.trim(),
      purchaseDate: _purchaseDate,
      warrantyMonths: _warrantyMonths,
      lifespanYears: int.tryParse(_lifeYears.text.trim()),
      store: _store.text.trim().isEmpty ? null : _store.text.trim(),
      price: double.tryParse(_price.text.trim()),
      receiptId: widget.existing?.receiptId,
      imagePath: widget.existing?.imagePath,
      imageSynced: widget.existing?.imageSynced ?? false,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      // The form has no condition field; the tag set from the card or
      // the detail screen rides through an edit untouched.
      condition: widget.existing?.condition,
      updatedAt: now,
    );
    if (widget.existing == null) {
      await AppDb.insertAppliance(a);
    } else {
      await AppDb.updateAppliance(a);
    }
    await widget.state.reload();
    await Reminders.reschedule(widget.state.tasks, widget.state.appliances);
    SyncService.syncNow();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    await AppDb.deleteAppliance(widget.existing!.id!);
    await widget.state.reload();
    await Reminders.reschedule(widget.state.tasks, widget.state.appliances);
    SyncService.syncNow();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add appliance' : 'Appliance'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          OutlinedButton.icon(
            onPressed: _scanning ? null : _scanNameplate,
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(_scanning ? 'Reading plate…' : 'Scan the nameplate'),
          ),
          const SizedBox(height: 8),
          Text(
            'The metal plate on the back or inside the door has the model and serial. One photo fills them in.',
            style: TextStyle(color: context.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _field(_name, 'Appliance name', 'e.g. Refrigerator'),
          _field(_brand, 'Brand', 'e.g. Samsung'),
          _field(_model, 'Model', ''),
          _field(_serial, 'Serial number', ''),
          _field(_store, 'Bought from', 'e.g. Home Depot'),
          _field(_price, 'Price paid (\$)', '', numeric: true),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Purchase date'),
            subtitle: Text(_purchaseDate == null
                ? 'Not set'
                : '${_purchaseDate!.month}/${_purchaseDate!.day}/${_purchaseDate!.year}'),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _purchaseDate ?? DateTime.now(),
                firstDate: DateTime(1990),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _purchaseDate = picked);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text('Warranty length')),
              DropdownButton<int>(
                value: _warrantyMonths,
                items: const [6, 12, 24, 36, 60, 72, 120, 300]
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m >= 12 ? '${m ~/ 12} yr' : '$m mo'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _warrantyMonths = v ?? 12),
              ),
            ],
          ),
          Text(
            'Pre-filled with the typical length for this appliance. Check your paperwork; the real terms win.',
            style: TextStyle(color: context.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lifeYears,
            keyboardType: TextInputType.number,
            onChanged: (_) => _lifeEdited = true,
            decoration: const InputDecoration(
              labelText: 'Expected life (years)',
              hintText: 'e.g. 12',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'How long this kind of appliance usually lasts. The life bar on My Home measures against it.',
            style: TextStyle(color: context.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Filter size, manual link, quirks, who services it',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save appliance')),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}
