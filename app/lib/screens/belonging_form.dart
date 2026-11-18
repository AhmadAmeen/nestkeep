import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../sync.dart';
import '../theme.dart';

/// Add or edit a belonging for the insurance list: what it is, which
/// room, and an honest value. Feeds the PDF home report.
class BelongingFormScreen extends StatefulWidget {
  final AppState state;
  final Belonging? existing;

  const BelongingFormScreen({super.key, required this.state, this.existing});

  @override
  State<BelongingFormScreen> createState() => _BelongingFormScreenState();
}

class _BelongingFormScreenState extends State<BelongingFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _room;
  late final TextEditingController _value;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _name = TextEditingController(text: b?.name ?? '');
    _room = TextEditingController(text: b?.room ?? '');
    _value = TextEditingController(
        text: b == null ? '' : b.value.toStringAsFixed(0));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final b = Belonging(
      id: widget.existing?.id,
      homeId: widget.state.activeHome!.id!,
      name: _name.text.trim(),
      room: _room.text.trim().isEmpty ? 'Home' : _room.text.trim(),
      value: double.tryParse(_value.text.trim()) ?? 0,
      updatedAt: DateTime.now(),
    );
    if (widget.existing == null) {
      await AppDb.insertBelonging(b);
    } else {
      await AppDb.updateBelonging(b);
    }
    await widget.state.reload();
    SyncService.syncNow();
    // Pop with the outcome so the list underneath can confirm it
    // with a ticker once navigation has completed (build 20).
    if (mounted) {
      Navigator.of(context)
          .pop(widget.existing == null ? 'added' : 'updated');
    }
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    await AppDb.deleteBelonging(widget.existing!.id!);
    await widget.state.reload();
    SyncService.syncNow();
    if (mounted) Navigator.of(context).pop('deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add a belonging' : 'Belonging'),
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
          _field(_name, 'What is it', 'e.g. Sofa, TV, laptop, jewellery'),
          _field(_room, 'Room', 'e.g. Living room'),
          _field(_value, 'Value (\$)', '', numeric: true),
          const SizedBox(height: 12),
          Text(
            'For insurance: keep values honest and current. What it would cost to replace, not what you wish it was worth.',
            style: TextStyle(color: context.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Save')),
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
