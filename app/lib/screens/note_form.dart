import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../sync.dart';
import '../theme.dart';

/// Add or edit a home note: paint colours, part numbers, gate codes,
/// where the shut-off is. The things a house knows and people forget.
class NoteFormScreen extends StatefulWidget {
  final AppState state;
  final HomeNote? existing;

  const NoteFormScreen({super.key, required this.state, this.existing});

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    final n = widget.existing;
    _title = TextEditingController(text: n?.title ?? '');
    _body = TextEditingController(text: n?.body ?? '');
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) return;
    final n = HomeNote(
      id: widget.existing?.id,
      homeId: widget.state.activeHome!.id!,
      title: _title.text.trim().isEmpty ? 'Note' : _title.text.trim(),
      body: _body.text.trim(),
      updatedAt: DateTime.now(),
    );
    if (widget.existing == null) {
      await AppDb.insertHomeNote(n);
    } else {
      await AppDb.updateHomeNote(n);
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
    await AppDb.deleteHomeNote(widget.existing!.id!);
    await widget.state.reload();
    SyncService.syncNow();
    if (mounted) Navigator.of(context).pop('deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add a note' : 'Home note'),
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
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Living room paint',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 8,
            minLines: 4,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'e.g. Behr Marquee, Swiss Coffee, eggshell. '
                  'Two coats, March 2026.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Paint colours, filter sizes, part numbers, codes, where things are.',
            style: TextStyle(color: context.muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Save note')),
        ],
      ),
    );
  }
}
