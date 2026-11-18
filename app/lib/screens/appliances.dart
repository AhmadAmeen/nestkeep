import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../lifespan.dart';
import '../models.dart';
import '../sync.dart';
import '../theme.dart';
import '../widgets.dart';
import 'appliance_detail.dart';
import 'appliance_form.dart';

/// The warranty vault as its own screen (build 18 moved it off the
/// My Home hub): every appliance with its warranty clock, life bar,
/// condition tag and photo, the free-plan meter, and the add flow.
class AppliancesScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenScan;
  final VoidCallback onOpenPaywall;

  const AppliancesScreen({
    super.key,
    required this.state,
    required this.onOpenScan,
    required this.onOpenPaywall,
  });

  Future<void> _addAppliance(BuildContext context) async {
    if (!state.isPro && state.appliances.length >= freeApplianceLimit) {
      onOpenPaywall();
      return;
    }
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            ApplianceFormScreen(state: state, onOpenPaywall: onOpenPaywall),
      ),
    );
    if (result == 'added' && context.mounted) {
      showTicker(context, 'Appliance added');
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appliances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add appliance',
            onPressed: () => _addAppliance(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
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
            ApplianceCard(
                state: state,
                appliance: a,
                now: now,
                onOpenPaywall: onOpenPaywall),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// One appliance, one card: photo (or icon) tile, name, warranty line,
/// the owner's condition tag, and the life bar along the bottom.
class ApplianceCard extends StatelessWidget {
  final AppState state;
  final Appliance appliance;
  final DateTime now;
  final VoidCallback onOpenPaywall;

  const ApplianceCard({
    super.key,
    required this.state,
    required this.appliance,
    required this.now,
    required this.onOpenPaywall,
  });

  /// The condition tag saves the same way every other appliance edit
  /// does: write the row, reload, let sync follow.
  Future<void> _saveCondition(String? condition) async {
    if (appliance.id == null) return;
    await AppDb.updateAppliance(appliance.copyWith(
      condition: condition,
      clearCondition: condition == null,
      updatedAt: DateTime.now(),
    ));
    await state.reload();
    SyncService.syncNow();
  }

  /// The card's leading tile: the appliance's first attached photo
  /// when it has one (the receipt photo when that is all it has),
  /// otherwise the type icon. A free user with no photo gets a small
  /// gold PRO pill on the corner: photos are the Pro extra, shown
  /// honestly rather than hidden.
  Widget _tile(BuildContext context) {
    final attached =
        appliance.id == null ? null : state.appliancePhotos[appliance.id!];
    final photoPath = attached ?? appliance.imagePath;
    final photo = photoPath == null ? null : File(photoPath);
    final hasPhoto = photo != null && photo.existsSync();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (hasPhoto)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              photo,
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
        if (!hasPhoto && !state.isPro)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: NkColors.amber,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: NkColors.lightNavy,
                ),
              ),
            ),
          ),
      ],
    );
  }

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
      onTap: () async {
        // The detail screen pops itself with 'deleted' when the
        // appliance is deleted from its edit form, unwinding all the
        // way back here (build 20) — confirm on the list.
        final result = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => ApplianceDetailScreen(
              state: state,
              appliance: appliance,
              onOpenPaywall: onOpenPaywall,
            ),
          ),
        );
        if (result == 'deleted' && context.mounted) {
          showTicker(context, 'Appliance deleted');
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tile(context),
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
                    const SizedBox(height: 6),
                    ConditionChip(
                      condition: appliance.condition,
                      onTap: () => showConditionSheet(
                        context,
                        current: appliance.condition,
                        onSave: _saveCondition,
                      ),
                    ),
                    if ((appliance.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        appliance.notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: context.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasDate) LifeChip(status: status),
            ],
          ),
          const SizedBox(height: 11),
          ApplianceLifeSection(appliance: appliance, now: now),
        ],
      ),
    );
  }
}
