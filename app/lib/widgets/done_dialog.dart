import 'package:flutter/material.dart';

/// What the done dialog hands back: the cost paid (0 when the job
/// was free), who did it and an optional note. A null result from
/// [showDoneDialog] means the user backed out — nothing is
/// completed and nothing is saved.
class DoneResult {
  final double cost;
  final String? doneBy;
  final String? note;
  const DoneResult(this.cost, this.doneBy, this.note);
}

/// The one completion dialog (build 23): the task guide's Mark done
/// and every quick tick on a task card open this same dialog, so
/// there is exactly one completion path in the app. The job is only
/// completed when the user taps Save or Nothing here.
Future<DoneResult?> showDoneDialog(BuildContext context) {
  return showDialog<DoneResult>(
    context: context,
    builder: (_) => const DoneDialog(),
  );
}

class DoneDialog extends StatefulWidget {
  const DoneDialog({super.key});

  @override
  State<DoneDialog> createState() => _DoneDialogState();
}

class _DoneDialogState extends State<DoneDialog> {
  final _cost = TextEditingController();
  final _doneBy = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _cost.dispose();
    _doneBy.dispose();
    _note.dispose();
    super.dispose();
  }

  DoneResult _result(double cost) => DoneResult(
        cost,
        _doneBy.text.trim().isEmpty ? null : _doneBy.text.trim(),
        _note.text.trim().isEmpty ? null : _note.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Done. What did it cost?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The cost field starts EMPTY with a plain numeric
            // placeholder (build 23): the old hint was a whole
            // sentence ("0 if you did it yourself") sitting inside a
            // money field, which read as a pre-filled value with the
            // numeric keyboard open. The free case is the Nothing
            // button below, so the sentence is gone entirely. Save
            // parses the field as a number only; empty means 0.
            TextField(
              controller: _cost,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cost',
                prefixText: '\$ ',
                hintText: '0.00',
              ),
              autofocus: true,
            ),
            TextField(
              controller: _doneBy,
              decoration: const InputDecoration(
                labelText: 'Done by',
                hintText: "Me, or the pro's name",
              ),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Anything worth remembering',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _result(0.0)),
          child: const Text('Nothing'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, _result(double.tryParse(_cost.text.trim()) ?? 0.0)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
