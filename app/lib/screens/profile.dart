import 'package:flutter/material.dart';

import '../app_state.dart';
import '../sync.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/avatar_menu.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/badge_celebration.dart';

/// Profile: who you are in the app — the optional account, your
/// avatar, how the app looks (build 20 moved Appearance here from
/// Settings), your plan and the badges you have earned. Home
/// switching and home management moved to the My Home header
/// dropdown in build 23 (the build-21 switcher that lived at the
/// top of this page is gone). Settings keeps data and about. Guest
/// mode is the default and the full app.
class ProfileScreen extends StatelessWidget {
  final AppState state;
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeChanged;
  final VoidCallback onOpenPaywall;
  final VoidCallback onOpenSettings;
  final VoidCallback? onAvatarTap;

  const ProfileScreen({
    super.key,
    required this.state,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onOpenPaywall,
    required this.onOpenSettings,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Profile',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.navyText)),
            ),
            AvatarButton(state: state, onTap: onAvatarTap),
          ],
        ),
        const SizedBox(height: 14),
        NkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: context.isDark
                        ? context.primary
                        : NkColors.lightNavy,
                    child: Icon(
                        state.signedIn ? Icons.person : Icons.person_outline,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.signedIn ? 'Signed in' : 'Guest mode',
                          style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: context.navyText),
                        ),
                        Text(
                          state.accountEmail ??
                              'No account needed. Make a free one if you want your home backed up and on every phone.',
                          style: TextStyle(color: context.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!state.signedIn)
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      await SyncService.signInWithGoogle();
                    } catch (_) {
                      // Sign-in cancelled or unavailable: guest mode continues.
                    }
                    await state.reload();
                  },
                  icon: const Icon(Icons.login, size: 19),
                  label: const Text('Sign in with Google'),
                )
              else
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        await SyncService.syncNow();
                        await state.reload();
                      },
                      child: const Text('Sync now'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await SyncService.signOut();
                        await state.reload();
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _AvatarCard(state: state, onOpenPaywall: onOpenPaywall),
        const SizedBox(height: 20),
        const SectionHeading('Appearance'),
        const SizedBox(height: 10),
        NkCard(
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) => onThemeChanged(s.first),
          ),
        ),
        const SizedBox(height: 20),
        _ColourCard(state: state, onOpenPaywall: onOpenPaywall),
        const SizedBox(height: 20),
        _BadgesCard(state: state),
        const SizedBox(height: 20),
        const SectionHeading('Your plan'),
        const SizedBox(height: 10),
        NkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    // PRO-TEST-UNLOCK (TEMPORARY, build 22): the plan
                    // card names the test unlock for what it is.
                    state.proTestMode && !state.entitlement.isPro
                        ? 'NestKeep Pro (test mode)'
                        : state.isPro
                            ? 'NestKeep Pro'
                            : 'Free plan',
                    style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: context.navyText),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: state.isPro
                          ? NkColors.green.withValues(alpha: 0.14)
                          : context.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      state.isPro ? 'PRO' : 'FREE',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: state.isPro ? NkColors.green : context.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!state.isPro) ...[
                for (final f in const [
                  'Seasonal plan and reminders for 1 home',
                  'Home health score that shows its work',
                  'Warranty vault and lifespan for 5 appliances',
                  'Unlimited receipt scanning',
                  'Add your own jobs (10 at a time)',
                ])
                  _includedRow(context, f),
                const SizedBox(height: 6),
                Text(
                  'Pro adds up to 3 homes, every appliance tracked with '
                  'photos and invoices, receipt photos saved in the app, '
                  'full cost history, a PDF home report and backup export.',
                  style: TextStyle(
                      fontSize: 13.5, color: context.muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onOpenPaywall,
                  child: const Text('See NestKeep Pro'),
                ),
              ] else
                Text(
                  'Everything is unlocked: up to 3 homes, every appliance '
                  'tracked with photos and invoices, receipt photos saved '
                  'and synced, full cost history, PDF home report and '
                  'backup export.',
                  style: TextStyle(
                      fontSize: 13.5, color: context.muted, height: 1.4),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        NkCard(
          onTap: onOpenSettings,
          child: Row(
            children: [
              Icon(Icons.settings_outlined, color: context.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: context.navyText),
                    ),
                    Text(
                      'Your data and about',
                      style: TextStyle(fontSize: 13, color: context.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.muted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _includedRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, size: 18, color: NkColors.green),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14.5)),
          ),
        ],
      ),
    );
  }
}

/// The badge shelf: small proof of a home being looked after. Only
/// earned badges are shown (build 19) — the shelf is a record, not a
/// catalogue of what is missing.
class _BadgesCard extends StatelessWidget {
  final AppState state;

  const _BadgesCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final allBadges = state.currentBadges;
    final earned = allBadges.where((b) => b.earned).toList();
    return NkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your badges',
                style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: context.navyText),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.line,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${earned.length} earned out of ${allBadges.length}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: context.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (earned.isEmpty)
            Text(
              'Finish your first job to earn your first badge.',
              style: TextStyle(color: context.muted, fontSize: 13.5),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisExtent: 104,
                crossAxisSpacing: 6,
                mainAxisSpacing: 10,
              ),
              itemCount: earned.length,
              itemBuilder: (context, i) {
                final b = earned[i];
                final iconColor =
                    b.isProBadge ? NkColors.amber : context.primary;
                final bgColor = b.isProBadge
                    ? NkColors.amber.withValues(alpha: 0.15)
                    : context.primary.withValues(alpha: 0.13);
                // Build 24: tapping an earned badge reopens its
                // detail — the same panel as the earn moment. The
                // shelf only ever shows earned badges (build 19),
                // so every tile here is tappable.
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showBadgeDetail(context, b),
                  child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration:
                          BoxDecoration(color: bgColor, shape: BoxShape.circle),
                      child: Icon(b.icon, size: 24, color: iconColor),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      b.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.navyText,
                        height: 1.15,
                      ),
                    ),
                  ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// The avatar picker card: the shared grid (see widgets/avatar_picker)
/// with Profile's heading. Locked avatars open the paywall, in the
/// same quiet way as everywhere else.
class _AvatarCard extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenPaywall;

  const _AvatarCard({required this.state, required this.onOpenPaywall});

  @override
  Widget build(BuildContext context) {
    final current = state.currentAvatar;
    return NkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Avatar',
                style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: context.navyText),
              ),
              const Spacer(),
              Text(
                current.label,
                style: TextStyle(fontSize: 12.5, color: context.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AvatarPicker(
            state: state,
            onLockedTap: onOpenPaywall,
            collapsible: true,
          ),
        ],
      ),
    );
  }
}

/// The app-colour picker: purple, violet, plum, fuchsia or orange,
/// worn by the whole app in light and dark alike. Lives on Profile
/// with the rest of Appearance (build 20; it was in Settings for one
/// build). Custom colours are Pro, with the avatar rule: one already
/// in use stays applied while free.
class _ColourCard extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenPaywall;

  const _ColourCard({required this.state, required this.onOpenPaywall});

  @override
  Widget build(BuildContext context) {
    return NkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App colour',
            style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: context.navyText),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final accent in AppAccent.values) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (state.accent == accent) return;
                      // Custom colours are Pro (build 19), with the
                      // avatar rule: one already in use stays applied
                      // while free, it just cannot be newly picked.
                      if (accent.proOnly && !state.isPro) {
                        onOpenPaywall();
                      } else {
                        state.setAccent(accent);
                      }
                    },
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: accent.primaryFor(context.isDark),
                                shape: BoxShape.circle,
                                border: state.accent == accent
                                    ? Border.all(
                                        color: context.navyText, width: 2.5)
                                    : null,
                              ),
                            ),
                            if (accent.proOnly &&
                                !state.isPro &&
                                state.accent != accent)
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
                        const SizedBox(height: 6),
                        Text(
                          accent.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: state.accent == accent
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: context.navyText,
                          ),
                        ),
                        if (accent.proOnly)
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
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.isPro
                ? 'Works in light and dark.'
                : 'Works in light and dark. Violet, Plum, Fuchsia and '
                    'Orange come with Pro; a colour already in use '
                    'stays yours.',
            style: TextStyle(fontSize: 12.5, color: context.muted),
          ),
        ],
      ),
    );
  }
}
