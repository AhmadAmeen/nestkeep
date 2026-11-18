import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'contractor_form.dart';

/// Your pros as their own screen (build 18 moved them off the My Home
/// hub): the plumber, electrician and HVAC tech you trust, one tap to
/// add or edit.
class ContractorsScreen extends StatelessWidget {
  final AppState state;

  const ContractorsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your pros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add a pro',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ContractorFormScreen(state: state),
            )),
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
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ContractorFormScreen(state: state, existing: c),
              )),
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
