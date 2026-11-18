import 'package:flutter/material.dart';

import '../app_state.dart';
import '../avatars.dart';
import '../theme.dart';

/// The avatar grid: twelve emoji faces, six free and six Pro. Locked
/// ones call [onLockedTap] (Profile opens the paywall; the avatar
/// sheet closes itself first, then opens the paywall). A Pro avatar
/// already picked stays picked if the plan lapses; it just cannot be
/// re-picked while locked. Used by the Profile card and by the avatar
/// menu's picker sheet, so both stay identical.
class AvatarPicker extends StatelessWidget {
  final AppState state;
  final VoidCallback onLockedTap;

  const AvatarPicker({
    super.key,
    required this.state,
    required this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final current = state.currentAvatar;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 100,
        crossAxisSpacing: 6,
        mainAxisSpacing: 10,
      ),
      itemCount: avatarCatalogue.length,
      itemBuilder: (context, i) {
        final a = avatarCatalogue[i];
        final selected = a.id == current.id;
        final locked = a.proOnly && !state.isPro;
        return GestureDetector(
          onTap: () {
            if (selected) return;
            if (locked) {
              onLockedTap();
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
                        child:
                            Text(a.emoji, style: const TextStyle(fontSize: 24)),
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
                        child: const Icon(Icons.check,
                            size: 11, color: Colors.white),
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
                        child: const Icon(Icons.lock,
                            size: 10, color: Colors.white),
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
      },
    );
  }
}
