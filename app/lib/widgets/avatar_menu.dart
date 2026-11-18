import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'avatar_picker.dart';

/// The avatar as drawn everywhere: the user's own photo when the
/// custom avatar is picked and its file exists (build 20), otherwise
/// the chosen emoji on an accent tint. A custom pick whose photo is
/// missing falls back to the default house avatar.
class AvatarFace extends StatelessWidget {
  final AppState state;
  final double radius;

  const AvatarFace({super.key, required this.state, required this.radius});

  @override
  Widget build(BuildContext context) {
    final tint = context.primary.withValues(
      alpha: context.isDark ? 0.28 : 0.14,
    );
    final photo =
        state.currentAvatar.id == 'custom' ? state.customAvatarFile : null;
    if (photo != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: tint,
        backgroundImage: FileImage(photo),
        onBackgroundImageError: (_, _) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: tint,
      child: Text(
        state.displayAvatar.emoji,
        style: TextStyle(fontSize: radius),
      ),
    );
  }
}

/// The header avatar, identical on every tab (build 19): the chosen
/// emoji on an accent tint. Tapping it opens the avatar menu.
class AvatarButton extends StatelessWidget {
  final AppState state;
  final VoidCallback? onTap;

  const AvatarButton({super.key, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AvatarFace(state: state, radius: 21),
    );
  }
}

/// The avatar menu: one shared bottom sheet reached from the header
/// avatar on any tab. It shows who you are in the app, and is the way
/// to the avatar picker, the paywall and Settings from everywhere.
/// [onOpenProfile] is null on the Profile tab itself, where the row
/// would go nowhere.
Future<void> showAvatarMenu(
  BuildContext context, {
  required AppState state,
  required VoidCallback onOpenPaywall,
  required VoidCallback onOpenSettings,
  required VoidCallback? onOpenProfile,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final avatar = state.displayAvatar;
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarFace(state: state, radius: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            avatar.label,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: sheetContext.navyText,
                            ),
                          ),
                          Text(
                            state.signedIn
                                ? (state.accountEmail ?? 'Signed in')
                                : 'Guest — your data lives on this phone',
                            style: TextStyle(
                              color: sheetContext.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.face_outlined),
                  title: const Text('Change avatar'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showAvatarPickerSheet(
                      context,
                      state: state,
                      onOpenPaywall: onOpenPaywall,
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.workspace_premium_outlined,
                    color: state.isPro ? NkColors.amber : null,
                  ),
                  title: Text(state.isPro ? 'Pro is active' : 'Go Pro'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onOpenPaywall();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onOpenSettings();
                  },
                ),
                if (onOpenProfile != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profile'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onOpenProfile();
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The avatar picker as a bottom sheet, for the avatar menu. Picking
/// a free avatar applies at once; a locked one closes the sheet and
/// opens the paywall, in the same quiet way as everywhere else.
Future<void> showAvatarPickerSheet(
  BuildContext context, {
  required AppState state,
  required VoidCallback onOpenPaywall,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose your avatar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: sheetContext.navyText,
                  ),
                ),
                const SizedBox(height: 14),
                AvatarPicker(
                  state: state,
                  onLockedTap: () {
                    Navigator.of(sheetContext).pop();
                    onOpenPaywall();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
