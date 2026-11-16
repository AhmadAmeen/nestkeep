import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'appliance_form.dart';

/// My Home: the warranty vault. Appliances with their warranty clocks,
/// receipts kept with them, and the home's basic facts.
class MyHomeScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenScan;
  final VoidCallback onOpenCosts;

  const MyHomeScreen({
    super.key,
    required this.state,
    required this.onOpenScan,
    required this.onOpenCosts,
  });

  @override
  Widget build(BuildContext context) {
    final home = state.activeHome!;
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('My home',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.navyText)),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ApplianceFormScreen(state: state),
              )),
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        NkCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    context.isDark ? NkColors.darkPrimary : NkColors.lightNavy,
                child: const Icon(Icons.home_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(home.name,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.navyText)),
                    Text(
                      '${home.addressLine} · built ${home.yearBuilt}',
                      style: TextStyle(color: context.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        NkCard(
          onTap: onOpenCosts,
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: NkColors.lightPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.savings_outlined,
                    color: NkColors.lightPrimary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Costs',
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: context.navyText)),
                    Text(
                      '${money(state.spentThisYear)} spent this year',
                      style: TextStyle(fontSize: 13, color: context.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeading('Appliances & warranties'),
        const SizedBox(height: 10),
        if (state.appliances.isEmpty)
          NkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nothing here yet.',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: context.navyText)),
                const SizedBox(height: 4),
                Text(
                  'Add an appliance by hand, or scan its receipt and NestKeep fills in the purchase date and warranty for you.',
                  style: TextStyle(color: context.muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onOpenScan,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan a receipt'),
                ),
              ],
            ),
          ),
        for (final a in state.appliances) ...[
          _ApplianceCard(state: state, appliance: a, now: now),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        const SectionHeading('Receipts'),
        const SizedBox(height: 10),
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
    );
  }
}

class _ApplianceCard extends StatelessWidget {
  final AppState state;
  final Appliance appliance;
  final DateTime now;

  const _ApplianceCard(
      {required this.state, required this.appliance, required this.now});

  @override
  Widget build(BuildContext context) {
    final end = appliance.warrantyEnd;
    final String warrantyText;
    final Color warrantyColor;
    if (end == null) {
      warrantyText = 'No purchase date yet';
      warrantyColor = context.muted;
    } else if (end.isAfter(now)) {
      final days = end.difference(now).inDays;
      warrantyText = days > 60
          ? 'Under warranty until ${end.month}/${end.year}'
          : 'Warranty ends in $days days';
      warrantyColor = days <= 60 ? NkColors.orange : NkColors.green;
    } else {
      warrantyText = 'Warranty ended ${end.month}/${end.year}';
      warrantyColor = context.muted;
    }
    return NkCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ApplianceFormScreen(state: state, existing: appliance),
      )),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (appliance.imagePath != null && File(appliance.imagePath!).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(appliance.imagePath!),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: NkColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.kitchen_outlined, color: NkColors.green),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appliance.name,
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: context.navyText)),
                if ((appliance.brand ?? '').isNotEmpty ||
                    (appliance.model ?? '').isNotEmpty)
                  Text(
                    [appliance.brand, appliance.model]
                        .where((s) => (s ?? '').isNotEmpty)
                        .join(' '),
                    style: TextStyle(fontSize: 13, color: context.muted),
                  ),
                Text(warrantyText,
                    style: TextStyle(
                        fontSize: 13,
                        color: warrantyColor,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
