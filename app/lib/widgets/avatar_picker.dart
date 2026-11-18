import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../avatars.dart';
import '../theme.dart';

/// The avatar grid: twelve emoji faces, six free and six Pro, plus a
/// final tile for the user's own photo (build 20, Pro). Locked tiles
/// call [onLockedTap] (Profile opens the paywall; the avatar sheet
/// closes itself first, then opens the paywall). A Pro avatar already
/// picked stays picked if the plan lapses; it just cannot be
/// re-picked while locked. Used by the Profile card and by the avatar
/// menu's picker sheet, so both stay identical.
///
/// With [collapsible] (Profile), the grid starts as one row of four
/// with a chevron underneath that expands the rest; the menu sheet
/// always shows the full grid. In the collapsed row the selected
/// avatar stays visible: when it sits beyond the first four it takes
/// the fourth slot.
class AvatarPicker extends StatefulWidget {
  final AppState state;
  final VoidCallback onLockedTap;
  final bool collapsible;

  const AvatarPicker({
    super.key,
    required this.state,
    required this.onLockedTap,
    this.collapsible = false,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  bool _expanded = false;

  AppState get state => widget.state;

  /// The tiles in display order: the catalogue, then the custom
  /// photo tile (null) last.
  List<AvatarDef?> get _allTiles => [...avatarCatalogue, null];

  List<AvatarDef?> get _visibleTiles {
    final all = _allTiles;
    if (!widget.collapsible || _expanded) return all;
    final firstFour = all.take(4).toList();
    final currentId = state.currentAvatar.id;
    final selectedIndex = all.indexWhere(
      (a) => a == null ? currentId == 'custom' : a.id == currentId,
    );
    // Keep the selected avatar visible in the collapsed row: beyond
    // the first four, it swaps into the fourth slot.
    if (selectedIndex >= 4) firstFour[3] = all[selectedIndex];
    return firstFour;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to state so a pick (here or anywhere) repaints the grid
    // at once — the bottom-sheet picker has no other rebuild trigger.
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final tiles = _visibleTiles;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisExtent: 100,
                crossAxisSpacing: 6,
                mainAxisSpacing: 10,
              ),
              itemCount: tiles.length,
              itemBuilder: (context, i) {
                final a = tiles[i];
                return a == null ? _customTile(context) : _tile(context, a);
              },
            ),
            if (widget.collapsible)
              IconButton(
                tooltip: _expanded ? 'Show fewer avatars' : 'Show all avatars',
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: context.muted,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
          ],
        );
      },
    );
  }

  Widget _tile(BuildContext context, AvatarDef a) {
    final current = state.currentAvatar;
    final selected = a.id == current.id;
    final locked = a.proOnly && !state.isPro;
    return GestureDetector(
      onTap: () {
        if (selected) return;
        if (locked) {
          widget.onLockedTap();
        } else {
          state.setAvatar(a);
        }
      },
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? context.primary.withValues(alpha: 0.15)
                      : context.line.withValues(alpha: 0.5),
                  border: selected
                      ? Border.all(color: context.primary, width: 2.5)
                      : null,
                ),
                child: Center(
                  child: Opacity(
                    opacity: locked ? 0.45 : 1,
                    child: Text(a.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.primary,
                    ),
                    child:
                        const Icon(Icons.check, size: 11, color: Colors.white),
                  ),
                ),
              if (locked)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.isDark
                          ? NkColors.darkLine
                          : NkColors.lightNavy,
                    ),
                    child:
                        const Icon(Icons.lock, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            a.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? context.navyText : context.muted,
            ),
          ),
          if (a.proOnly)
            Text(
              'PRO',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: state.isPro
                    ? NkColors.green
                    : context.muted.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  /// The last tile: the user's own photo. Free users get the same
  /// lock treatment as the Pro emoji; Pro users pick a photo (or, with
  /// one already set, replace or remove it).
  Widget _customTile(BuildContext context) {
    final photo = state.customAvatarFile;
    final hasPhoto = photo != null;
    final selected = state.currentAvatar.id == 'custom' && hasPhoto;
    final locked = !state.isPro;
    return GestureDetector(
      onTap: () => _onCustomTap(context, hasPhoto: hasPhoto),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? context.primary.withValues(alpha: 0.15)
                      : context.line.withValues(alpha: 0.5),
                  border: selected
                      ? Border.all(color: context.primary, width: 2.5)
                      : Border.all(color: context.line, width: 1),
                ),
                child: hasPhoto
                    ? ClipOval(
                        child: Opacity(
                          opacity: locked ? 0.45 : 1,
                          child: Image.file(
                            photo,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.add,
                        size: 24,
                        color: locked ? context.muted : context.primary,
                      ),
              ),
              if (selected)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.primary,
                    ),
                    child:
                        const Icon(Icons.check, size: 11, color: Colors.white),
                  ),
                ),
              if (locked)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.isDark
                          ? NkColors.darkLine
                          : NkColors.lightNavy,
                    ),
                    child:
                        const Icon(Icons.lock, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            customAvatarDef.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? context.navyText : context.muted,
            ),
          ),
          Text(
            'PRO',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: state.isPro
                  ? NkColors.green
                  : context.muted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCustomTap(BuildContext context,
      {required bool hasPhoto}) async {
    if (!state.isPro) {
      widget.onLockedTap();
      return;
    }
    if (!hasPhoto) {
      await _pickCustomPhoto(context);
      return;
    }
    // A photo is already set: tapping the tile manages it — replace
    // it with a new pick, or remove it (the app's sheet pattern, the
    // same one space management uses).
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Replace photo'),
              onTap: () => Navigator.pop(ctx, 'replace'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove photo'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'replace') {
      await _pickCustomPhoto(context);
    } else if (action == 'remove') {
      await state.removeCustomAvatar();
    }
  }

  /// Pick a photo the way attachments do (camera or gallery sheet),
  /// then save it as the custom avatar and select it.
  Future<void> _pickCustomPhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    await state.setCustomAvatarFromPicked(picked.path);
  }
}
