import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Saved receipts as their own screen (build 18 moved them off the
/// My Home hub): every scanned receipt, with its store, date and
/// total.
class ReceiptsScreen extends StatelessWidget {
  final AppState state;

  const ReceiptsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipts')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (state.receipts.isEmpty)
            NkCard(
              child: Text('No receipts saved yet.',
                  style: TextStyle(color: context.muted)),
            ),
          for (final r in state.receipts) ...[
            NkCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: NkColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        color: NkColors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.store,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: context.navyText)),
                        Text(
                          '${r.date.month}/${r.date.day}/${r.date.year} · ${r.items.length} items',
                          style: TextStyle(fontSize: 13, color: context.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(money(r.total),
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: context.navyText)),
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
