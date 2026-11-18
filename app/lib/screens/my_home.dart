import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/avatar_menu.dart';
import '../widgets/home_photo.dart';
import 'appliances.dart';
import 'belongings.dart';
import 'contractors.dart';
import 'documents.dart';
import 'history.dart';
import 'home_details.dart';
import 'home_notes.dart';
import 'receipts.dart';

/// My Home as a hub (build 18): the home up top, a strip of three
/// honest counts, then a grid of big tiles — one per area, each
/// opening its own screen. Nothing lives on this page but the way in,
/// so everything is clear and easy to tap.
class MyHomeScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenScan;
  final VoidCallback onOpenCosts;
  final VoidCallback onOpenPaywall;
  final VoidCallback? onAvatarTap;

  const MyHomeScreen({
    super.key,
    required this.state,
    required this.onOpenScan,
    required this.onOpenCosts,
    required this.onOpenPaywall,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final home = state.activeHome!;
    final doneCount =
        state.tasks.where((t) => t.status == TaskStatus.done).length;
    final tiles = _tiles(context, doneCount);
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
            AvatarButton(state: state, onTap: onAvatarTap),
          ],
        ),
        const SizedBox(height: 12),
        // The home's own photo (build 20, free, local only) rides on
        // top of the summary card as a banner when one is set; with
        // no photo the card is exactly as it was. Tapping the banner
        // replaces or removes the photo.
        Builder(builder: (context) {
          final photoPath = state.homePhotoPath(home.id!);
          final summaryRow = Row(
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
          );
          if (photoPath == null) return NkCard(child: summaryRow);
          return NkCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () => showHomePhotoActions(context, state, home.id!),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    child: Image.file(
                      File(photoPath),
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: summaryRow,
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        // The stats strip: three real counts, straight from state.
        NkCard(
          child: Row(
            children: [
              _stat(context, '${state.appliances.length}', 'Appliances'),
              _divider(context),
              _stat(context, '${state.docs.length}', 'Documents'),
              _divider(context),
              _stat(context, '$doneCount', 'Jobs done'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 138,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, i) => tiles[i],
        ),
      ],
    );
  }

  List<Widget> _tiles(BuildContext context, int doneCount) {
    final docs = state.docs;
    return [
      _HubTile(
        icon: Icons.kitchen_outlined,
        color: NkColors.green,
        label: 'Appliances',
        sublabel: '${state.appliances.length} tracked',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AppliancesScreen(
            state: state,
            onOpenScan: onOpenScan,
            onOpenPaywall: onOpenPaywall,
          ),
        )),
      ),
      _HubTile(
        icon: Icons.description_outlined,
        color: NkColors.amber,
        label: 'Documents',
        sublabel: docs.isEmpty && !state.isPro
            ? 'Pro'
            : '${docs.length} stored',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DocumentsScreen(
            state: state,
            onOpenPaywall: onOpenPaywall,
          ),
        )),
      ),
      _HubTile(
        icon: Icons.savings_outlined,
        color: context.primary,
        label: 'Costs',
        sublabel: '${money(state.spentThisYear)} this year',
        onTap: onOpenCosts,
      ),
      _HubTile(
        icon: Icons.history_outlined,
        color: NkColors.green,
        label: 'History',
        sublabel: '$doneCount jobs done',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HistoryScreen(state: state),
        )),
      ),
      _HubTile(
        icon: Icons.receipt_long_outlined,
        color: NkColors.amber,
        label: 'Receipts',
        sublabel: state.receipts.isEmpty
            ? 'None saved yet'
            : '${state.receipts.length} saved',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ReceiptsScreen(state: state),
        )),
      ),
      _HubTile(
        icon: Icons.handyman_outlined,
        color: context.primary,
        label: 'Contractors',
        sublabel: state.contractors.isEmpty
            ? 'None added yet'
            : '${state.contractors.length} saved',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ContractorsScreen(state: state),
        )),
      ),
      _HubTile(
        icon: Icons.inventory_2_outlined,
        color: NkColors.green,
        label: 'Belongings',
        sublabel: state.belongings.isEmpty
            ? 'Nothing listed yet'
            : '${money(state.belongingsTotal)} listed',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BelongingsScreen(state: state),
        )),
      ),
      _HubTile(
        icon: Icons.sticky_note_2_outlined,
        color: NkColors.amber,
        label: 'Home notes',
        sublabel: state.homeNotes.isEmpty
            ? 'Nothing written yet'
            : '${state.homeNotes.length} note${state.homeNotes.length == 1 ? '' : 's'}',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NotesScreen(state: state),
        )),
      ),
      _HubTile(
        icon: Icons.info_outline,
        color: context.primary,
        label: 'Details',
        sublabel:
            '${homeTypeLabel(state.activeHome!.type)} · built ${state.activeHome!.yearBuilt}',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HomeDetailsScreen(state: state),
        )),
      ),
    ];
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.navyText)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.muted)),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(width: 1, height: 40, color: context.line);
  }
}

/// One hub tile: a big tinted icon, a label, and a small honest
/// sublabel (a count or the current figure), the whole card tappable.
class _HubTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NkCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: context.navyText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: context.muted),
          ),
        ],
      ),
    );
  }
}
