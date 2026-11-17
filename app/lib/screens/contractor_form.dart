import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../sync.dart';
import '../theme.dart';

/// Add or edit one of your own pros: the plumber, electrician or HVAC
/// tech you actually call. Pure local data, no marketplace, no ads.
class ContractorFormScreen extends StatefulWidget {
  final AppState state;
  final Contractor? existing;

  const ContractorFormScreen({super.key, required this.state, this.existing});

  @override
  State<ContractorFormScreen> createState() => _ContractorFormScreenState();
}

class _ContractorFormScreenState extends State<ContractorFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _trade;
  late final TextEditingController _phone;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _trade = TextEditingController(text: c?.trade ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final c = Contractor(
      id: widget.existing?.id,
      homeId: widget.state.activeHome!.id!,
      name: _name.text.trim(),
      trade: _trade.text.trim().isEmpty ? 'General' : _trade.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      updatedAt: DateTime.now(),
    );
    if (widget.existing == null) {
      await AppDb.insertContractor(c);
    } else {
      await AppDb.updateContractor(c);
    }
    await widget.state.reload();
    SyncService.syncNow();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    await AppDb.deleteContractor(widget.existing!.id!);
    await widget.state.reload();
    SyncService.syncNow();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add a pro' : 'Your pro'),
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
          _field(_name, 'Name', 'e.g. Mike the plumber'),
          _field(_trade, 'Trade', 'e.g. Plumbing'),
          _field(_phone, 'Phone', '', phone: true),
          _field(_notes, 'Notes', 'e.g. Ask for the Saturday rate', lines: 3),
          const SizedBox(height: 12),
          Text(
            'Only your pros, saved on this phone. NestKeep never sells or shares this list.',
            style: TextStyle(color: context.muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {bool phone = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: lines,
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}
