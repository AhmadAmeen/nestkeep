import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../sync.dart';
import '../theme.dart';

/// Add or edit an appliance. Includes a nameplate scan: photograph the
/// metal plate on the appliance and the form fills brand / model / serial
/// from the text it finds (on-device OCR, same as receipts).
class ApplianceFormScreen extends StatefulWidget {
  final AppState state;
  final Appliance? existing;

  const ApplianceFormScreen({super.key, required this.state, this.existing});

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
  late DateTime? _purchaseDate;
  late int _warrantyMonths;
  bool _scanning = false;

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
    _purchaseDate = a?.purchaseDate;
    _warrantyMonths = a?.warrantyMonths ?? 12;
    _name.addListener(() {
      if (widget.existing == null) {
        setState(() => _warrantyMonths = typicalWarrantyMonths(_name.text));
      }
    });
  }

  Future<void> _scanNameplate() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return;
    setState(() => _scanning = true);
    try {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result =
          await recognizer.processImage(InputImage.fromFilePath(picked.path));
      await recognizer.close();
      final text = result.text;
      String? after(String label) {
        final m = RegExp('$label[:\\s]+([A-Za-z0-9\\-/ ]{2,30})',
                caseSensitive: false)
            .firstMatch(text);
        return m?.group(1)?.trim();
      }

      setState(() {
        _model.text = after('model') ?? _model.text;
        _serial.text = after('serial') ?? after('s/n') ?? _serial.text;
        _brand.text = after('brand') ?? after('make') ?? _brand.text;
      });
    } catch (_) {
      // A failed plate scan just leaves the fields for typing.
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
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
      store: _store.text.trim().isEmpty ? null : _store.text.trim(),
      price: double.tryParse(_price.text.trim()),
      receiptId: widget.existing?.receiptId,
      imagePath: widget.existing?.imagePath,
      imageSynced: widget.existing?.imageSynced ?? false,
      updatedAt: now,
    );
    if (widget.existing == null) {
      await AppDb.insertAppliance(a);
    } else {
      await AppDb.updateAppliance(a);
    }
    await widget.state.reload();
    SyncService.syncNow();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    await AppDb.deleteAppliance(widget.existing!.id!);
    await widget.state.reload();
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
