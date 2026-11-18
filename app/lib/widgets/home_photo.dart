import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../widgets.dart';

/// The home photo flows (build 20), shared by the My Home summary
/// card and the Home details screen so both manage the picture the
/// same way. One photo per home, stored locally in the app documents
/// folder and never synced.
///
/// Pro since build 21: adding or replacing the photo is a Pro extra,
/// so a free user who taps for one lands on the paywall instead of
/// the picker. A photo already set stays put and stays visible if
/// Pro lapses (grandfathered, the same rule as Pro avatars and
/// colours), and removing it is always allowed.

/// Pick a photo (the app's usual camera-or-gallery sheet) and save
/// it as the home's photo. Shows the confirmation ticker on success.
/// Free users get the paywall instead: the picker never opens.
Future<void> pickHomePhoto(
  BuildContext context,
  AppState state,
  int homeId, {
  required bool replacing,
  required VoidCallback onOpenPaywall,
}) async {
  if (!state.isPro) {
    onOpenPaywall();
    return;
  }
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
  final ok = await state.setHomePhoto(homeId, picked.path);
  if (ok && context.mounted) {
    showTicker(context, replacing ? 'Home photo updated' : 'Home photo added');
  }
}

/// Manage an existing home photo: replace it or remove it. Replacing
/// is Pro-gated inside [pickHomePhoto]; removing never is, so a
/// lapsed Pro can always take a photo back off.
Future<void> showHomePhotoActions(
  BuildContext context,
  AppState state,
  int homeId, {
  required VoidCallback onOpenPaywall,
}) async {
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
    await pickHomePhoto(context, state, homeId,
        replacing: true, onOpenPaywall: onOpenPaywall);
  } else if (action == 'remove') {
    await state.removeHomePhoto(homeId);
    if (context.mounted) showTicker(context, 'Home photo removed');
  }
}
