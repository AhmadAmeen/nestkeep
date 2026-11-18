import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'contractor_form.dart';

/// Your pros as their own screen (build 18 moved them off the My Home
/// hub): the plumber, electrician and HVAC tech you trust, one tap to
/// add or edit.
class ContractorsScreen extends StatelessWidget {
  final AppState state;

  const ContractorsScreen({super.key, required this.state});

  /// Open the form and confirm its outcome here on the list, once
  /// navigation has completed (build 20 tickers).
  Future<void> _openForm(BuildContext context, {Contractor? existing}) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ContractorFormScreen(state: state, existing: existing),
      ),
    );
    if (!context.mounted || result == null) return;
    final message = switch (result) {
      'added' => 'Contractor added',
      'updated' => 'Contractor updated',
      'deleted' => 'Contractor deleted',
      _ => null,
    };
    if (message != null) showTicker(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your pros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add a pro',
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (state.contractors.isEmpty)
            NkCard(
              child: Text(
                'Your plumber, electrician, HVAC tech. Add the people you trust so their number is here when something breaks.',
                style: TextStyle(color: context.muted, height: 1.4),
              ),
            ),
          for (final c in state.contractors) ...[
            NkCard(
              onTap: () => _openForm(context, existing: c),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: context.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.handyman_outlined,
                        color: context.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: context.navyText)),
                        Text(
                          [c.trade, if ((c.phone ?? '').isNotEmpty) c.phone!]
                              .join(' · '),
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
