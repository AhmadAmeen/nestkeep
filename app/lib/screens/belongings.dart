import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'belonging_form.dart';

/// Belongings as their own screen (build 18 moved them off the My
/// Home hub): the big things, listed with their value for the home
/// report and for insurance.
class BelongingsScreen extends StatelessWidget {
  final AppState state;

  const BelongingsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Belongings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add a belonging',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BelongingFormScreen(state: state),
            )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (state.belongings.isNotEmpty) ...[
            NkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Listed value',
                            style: TextStyle(fontSize: 13, color: context.muted)),
                      ),
                      Text(money(state.belongingsTotal),
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: context.navyText)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For insurance: keep values honest and current.',
                    style: TextStyle(fontSize: 13, color: context.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (state.belongings.isEmpty)
            NkCard(
              child: Text(
                'Nothing listed yet. Add the big things: furniture, TV, laptop, jewellery. The list goes into your home report.',
                style: TextStyle(color: context.muted, height: 1.4),
              ),
            ),
          for (final b in state.belongings) ...[
            NkCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BelongingFormScreen(state: state, existing: b),
              )),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: NkColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: NkColors.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name,
                            style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: context.navyText)),
                        Text(b.room,
                            style: TextStyle(fontSize: 13, color: context.muted)),
                      ],
                    ),
                  ),
                  Text(money(b.value),
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
