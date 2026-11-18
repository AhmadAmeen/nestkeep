import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'note_form.dart';

/// Home notes as their own screen (build 18 moved them off the My
/// Home hub): paint colours, part numbers, codes — the stuff a house
/// knows and people forget.
class NotesScreen extends StatelessWidget {
  final AppState state;

  const NotesScreen({super.key, required this.state});

  /// Open the form and confirm its outcome here on the list, once
  /// navigation has completed (build 20 tickers).
  Future<void> _openForm(BuildContext context, {HomeNote? existing}) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => NoteFormScreen(state: state, existing: existing),
      ),
    );
    if (!context.mounted || result == null) return;
    final message = switch (result) {
      'added' => 'Note added',
      'updated' => 'Note updated',
      'deleted' => 'Note deleted',
      _ => null,
    };
    if (message != null) showTicker(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add a note',
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (state.homeNotes.isEmpty)
            NkCard(
              child: Text(
                'Paint colours, part numbers, codes, where things are. The stuff a house knows and people forget.',
                style: TextStyle(color: context.muted, height: 1.4),
              ),
            ),
          for (final n in state.homeNotes) ...[
            NkCard(
              onTap: () => _openForm(context, existing: n),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: NkColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.sticky_note_2_outlined,
                        color: NkColors.amber, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.title,
                            style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: context.navyText)),
                        if (n.body.isNotEmpty)
                          Text(
                            n.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: context.muted),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
