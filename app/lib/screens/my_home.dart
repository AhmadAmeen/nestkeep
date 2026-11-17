import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../lifespan.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'appliance_detail.dart';
import 'appliance_form.dart';
import 'belonging_form.dart';
import 'contractor_form.dart';
import 'documents_section.dart';
import 'history.dart';
import 'note_form.dart';

/// My Home: the warranty vault. Appliances with their warranty clocks,
/// receipts kept with them, and the home's basic facts.
class MyHomeScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenScan;
  final VoidCallback onOpenCosts;
  final VoidCallback onOpenPaywall;

  const MyHomeScreen({
    super.key,
    required this.state,
    required this.onOpenScan,
    required this.onOpenCosts,
    required this.onOpenPaywall,
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
              onPressed: () {
                if (!state.isPro &&
                    state.appliances.length >= freeApplianceLimit) {
                  onOpenPaywall();
                  return;
                }
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ApplianceFormScreen(
                      state: state, onOpenPaywall: onOpenPaywall),
                ));
              },
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
                    context.isDark ? context.primary : NkColors.lightNavy,
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
                      home.addressLine.isEmpty
                          ? 'Built ${home.yearBuilt}'
                          : '${home.addressLine} · built ${home.yearBuilt}',
                      style: TextStyle(color: context.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionHeading(state.appliances.isEmpty
            ? 'Appliances'
            : 'Appliances · ${state.appliances.length} tracked'),
        const SizedBox(height: 10),
        if (!state.isPro && state.appliances.isNotEmpty) ...[
          NkCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.appliances.length} of $freeApplianceLimit free appliances tracked',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.navyText),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (state.appliances.length / freeApplianceLimit)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                    minHeight: 8,
                    backgroundColor: context.line,
                    valueColor: AlwaysStoppedAnimation(context.primary),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Pro tracks every appliance in the house, with its invoice and photos attached.',
                  style: TextStyle(fontSize: 12.5, color: context.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
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
          _ApplianceCard(
              state: state,
              appliance: a,
              now: now,
              onOpenPaywall: onOpenPaywall),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        DocumentsSection(state: state, onOpenPaywall: onOpenPaywall),
        const SizedBox(height: 20),
        NkCard(
          onTap: onOpenCosts,
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.savings_outlined,
                    color: context.primary, size: 24),
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
        const SizedBox(height: 12),
        NkCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HistoryScreen(state: state),
          )),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: NkColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.history_outlined,
                    color: NkColors.green, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Home history',
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: context.navyText)),
                    Text(
                      state.tasks
                              .where((t) => t.status == TaskStatus.done)
                              .isEmpty
                          ? 'Finished jobs will live here'
                          : '${state.tasks.where((t) => t.status == TaskStatus.done).length} jobs done, on the record',
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
        const SizedBox(height: 12),
        SectionHeading('Your pros',
            actionLabel: 'Add',
            onAction: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ContractorFormScreen(state: state),
                ))),
        const SizedBox(height: 10),
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
        const SizedBox(height: 12),
        SectionHeading('Home notes',
            actionLabel: 'Add',
            onAction: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NoteFormScreen(state: state),
                ))),
        const SizedBox(height: 10),
        if (state.homeNotes.isEmpty)
          NkCard(
            child: Text(
              'Paint colours, part numbers, codes, where things are. The stuff a house knows and people forget.',
              style: TextStyle(color: context.muted, height: 1.4),
            ),
          ),
        for (final n in state.homeNotes) ...[
          NkCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NoteFormScreen(state: state, existing: n),
            )),
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
        const SizedBox(height: 12),
        SectionHeading('Belongings',
            actionLabel: 'Add',
            onAction: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BelongingFormScreen(state: state),
                ))),
        if (state.belongings.isNotEmpty) ...[
          const SizedBox(height: 10),
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
        ],
        const SizedBox(height: 10),
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
    );
  }
}

class _ApplianceCard extends StatelessWidget {
  final AppState state;
  final Appliance appliance;
  final DateTime now;
  final VoidCallback onOpenPaywall;

  const _ApplianceCard({
    required this.state,
    required this.appliance,
    required this.now,
    required this.onOpenPaywall,
  });

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
    final hasDate = appliance.purchaseDate != null;
    final status = lifeStatus(appliance, now);
    return NkCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ApplianceDetailScreen(
          state: state,
          appliance: appliance,
          onOpenPaywall: onOpenPaywall,
        ),
      )),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (appliance.imagePath != null &&
                  File(appliance.imagePath!).existsSync())
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
                  child: const Icon(Icons.kitchen_outlined,
                      color: NkColors.green),
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
                    if ((appliance.notes ?? '').isNotEmpty)
                      Text(
                        appliance.notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: context.muted),
                      ),
                  ],
                ),
              ),
              if (hasDate) LifeChip(status: status),
            ],
          ),
          if (hasDate) ...[
            const SizedBox(height: 11),
            LifeBar(appliance: appliance, now: now),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    lifeLabel(appliance, now),
                    style: TextStyle(fontSize: 12, color: context.muted),
                  ),
                ),
                Text(
                  lifeLeftLabel(appliance, now),
                  style: TextStyle(fontSize: 12, color: context.muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
