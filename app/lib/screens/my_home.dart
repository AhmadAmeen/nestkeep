import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../sync.dart';
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

  /// Opens the add-a-home flow (the onboarding wizard in the app).
  /// Optional so hub tests can pump the screen without it; the menu
  /// entry simply does nothing then.
  final VoidCallback? onAddHome;

  const MyHomeScreen({
    super.key,
    required this.state,
    required this.onOpenScan,
    required this.onOpenCosts,
    required this.onOpenPaywall,
    this.onAvatarTap,
    this.onAddHome,
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
              child: _HomeTitleMenu(
                state: state,
                onOpenPaywall: onOpenPaywall,
                onAddHome: onAddHome,
              ),
            ),
            // The home's editor lives in the header now (build 24):
            // one pencil beside the avatar, opening the details
            // screen straight in edit mode. The hub grid no longer
            // carries a separate Details tile.
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit home',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HomeDetailsScreen(
                    state: state,
                    onOpenPaywall: onOpenPaywall,
                    startEditing: true,
                  ),
                ),
              ),
            ),
            AvatarButton(state: state, onTap: onAvatarTap),
          ],
        ),
        const SizedBox(height: 12),
        // The home's own photo (build 20, local only) rides on
        // top of the summary card as a banner when one is set; with
        // no photo the card is exactly as it was. Tapping the banner
        // replaces or removes the photo; replacing is Pro since
        // build 21, a photo already set stays for everyone.
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
                  onTap: () => showHomePhotoActions(context, state, home.id!,
                      onOpenPaywall: onOpenPaywall),
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

/// The header title as a home dropdown (build 23): the current
/// home's name in the title style with a small chevron, tappable.
/// Its menu lists every home (the current one ticked; tapping
/// switches), then the home actions: Add home, Edit home (the
/// current home's details, straight into Edit mode) and Delete
/// home (confirmed; the cascade delete in AppDb; the app switches
/// to a remaining home and confirms with a ticker). Home management
/// lives here now — Profile's build-21 switcher is gone. The caps
/// are the locked ones: Free is 1 home, so a free user with a home
/// already goes to the paywall from Add home; Pro allows up to 3,
/// and at 3 the entry answers "3 homes is the limit". The only home
/// can never be deleted: "You need at least one home".
/// The header menu's action entries, told apart from a picked
/// [Home] (the menu value is either a Home or one of these).
enum _HomeMenuAction { add, edit, delete }

class _HomeTitleMenu extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenPaywall;
  final VoidCallback? onAddHome;

  const _HomeTitleMenu({
    required this.state,
    required this.onOpenPaywall,
    required this.onAddHome,
  });

  void _onSelected(BuildContext context, Object value) {
    if (value == _HomeMenuAction.add) {
      if (!state.isPro && state.homes.length >= 1) {
        onOpenPaywall();
      } else if (state.homes.length >= 3) {
        showTicker(context, '3 homes is the limit');
      } else {
        onAddHome?.call();
      }
      return;
    }
    if (value == _HomeMenuAction.edit) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HomeDetailsScreen(
          state: state,
          onOpenPaywall: onOpenPaywall,
          startEditing: true,
        ),
      ));
      return;
    }
    if (value == _HomeMenuAction.delete) {
      final home = state.activeHome;
      if (home != null) _deleteHomeFlow(context, home);
      return;
    }
    final home = value as Home;
    if (home.id != state.activeHome?.id) {
      state.setActiveHome(home);
    }
  }

  Future<void> _deleteHomeFlow(BuildContext context, Home home) async {
    if (state.homes.length <= 1) {
      showTicker(context, 'You need at least one home');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this home?'),
        content: Text(
          '${home.name} and everything in it — its plan, appliances, '
          'costs and documents — will be removed from this phone. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NkColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AppDb.deleteHome(home.id!);
    await state.removeHomePhoto(home.id!);
    state.homes = await AppDb.homes();
    state.profiles.remove(home.id);
    state.planSelections.remove(home.id);
    if (state.homes.isEmpty) return;
    await state.setActiveHome(state.homes.first);
    SyncService.syncNow();
    if (context.mounted) showTicker(context, 'Home deleted');
  }

  @override
  Widget build(BuildContext context) {
    final active = state.activeHome;
    return PopupMenuButton<Object>(
      tooltip: 'Switch home',
      padding: EdgeInsets.zero,
      onSelected: (value) => _onSelected(context, value),
      itemBuilder: (context) => [
        for (final h in state.homes)
          PopupMenuItem<Object>(
            value: h,
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: h.id == active?.id
                      ? Icon(Icons.check, size: 18, color: context.primary)
                      : null,
                ),
                Expanded(
                  child: Text(
                    h.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  homeTypeLabel(h.type),
                  style: TextStyle(fontSize: 12.5, color: context.muted),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: _HomeMenuAction.add,
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Icon(Icons.add, size: 18, color: context.primary),
              ),
              const Text('Add home', style: TextStyle(fontSize: 14.5)),
            ],
          ),
        ),
        PopupMenuItem<Object>(
          value: _HomeMenuAction.edit,
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Icon(Icons.edit_outlined,
                    size: 18, color: context.primary),
              ),
              const Text('Edit home', style: TextStyle(fontSize: 14.5)),
            ],
          ),
        ),
        PopupMenuItem<Object>(
          value: _HomeMenuAction.delete,
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Icon(Icons.delete_outline,
                    size: 18, color: NkColors.red),
              ),
              const Text('Delete home', style: TextStyle(fontSize: 14.5)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              active?.name ?? 'My home',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.navyText,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 24, color: context.navyText),
        ],
      ),
    );
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
