import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../avatars.dart';
import '../badges.dart';
import '../calendar.dart';
import '../db.dart';
import '../models.dart';
import '../sync.dart';
import '../theme.dart';
import '../widgets.dart';

/// Profile & settings: the optional account, homes, appearance, backup,
/// and the legal pages. Guest mode is the default and the full app.
class ProfileScreen extends StatelessWidget {
  final AppState state;
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeChanged;
  final VoidCallback onOpenPaywall;
  final VoidCallback onAddHome;
  final VoidCallback? onShowIntro;

  const ProfileScreen({
    super.key,
    required this.state,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onOpenPaywall,
    required this.onAddHome,
    this.onShowIntro,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Profile',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: context.navyText)),
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
                        user == null ? Icons.person_outline : Icons.person,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user == null ? 'Guest mode' : 'Signed in',
                          style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: context.navyText),
                        ),
                        Text(
                          user?.email ??
                              'No account needed. Make a free one if you want your home backed up and on every phone.',
                          style: TextStyle(color: context.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (user == null)
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
        _BadgesCard(state: state, onOpenPaywall: onOpenPaywall),
        const SizedBox(height: 20),
        _ColourCard(state: state),
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
                    state.isPro ? 'NestKeep Pro' : 'Free plan',
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
        const SectionHeading('Your homes'),
        const SizedBox(height: 10),
        for (final h in state.homes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NkCard(
              onTap: () => state.setActiveHome(h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    h.id == state.activeHome?.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: NkColors.green,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(h.name,
                            style: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w600)),
                        if (h.addressLine.isNotEmpty)
                          Text(h.addressLine,
                              style: TextStyle(
                                  fontSize: 13, color: context.muted)),
                      ],
                    ),
                  ),
                  if (state.homes.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await AppDb.deleteHome(h.id!);
                        state.homes = await AppDb.homes();
                        if (state.activeHome?.id == h.id) {
                          await state.setActiveHome(state.homes.first);
                        }
                        await state.reload();
                        SyncService.syncNow();
                      },
                    ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () {
            if (!state.isPro && state.homes.length >= 1) {
              onOpenPaywall();
            } else if (state.homes.length >= 3) {
              onOpenPaywall();
            } else {
              onAddHome();
            }
          },
          icon: const Icon(Icons.add),
          label: Text(state.isPro || state.homes.isEmpty
              ? 'Add another home'
              : 'Add another home (Pro)'),
        ),
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
        const SectionHeading('Data'),
        const SizedBox(height: 10),
        NkCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Export backup'),
                subtitle: Text(
                  state.isPro
                      ? 'A JSON file with everything, yours to keep'
                      : 'Pro feature',
                  style: TextStyle(color: context.muted),
                ),
                trailing: const Icon(Icons.ios_share_outlined),
                onTap: state.isPro ? () => _export(context) : onOpenPaywall,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Export plan (.ics)'),
                subtitle: Text(
                  'Every upcoming job as an all-day calendar event. Import it into any calendar app.',
                  style: TextStyle(color: context.muted),
                ),
                trailing: const Icon(Icons.event_outlined),
                onTap: () => sharePlanIcs(state),
              ),
              if (onShowIntro != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('How NestKeep works'),
                  subtitle: Text(
                    'The five-slide tour, any time',
                    style: TextStyle(color: context.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: onShowIntro,
                ),
                const Divider(height: 1),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Privacy policy'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => launchUrl(
                    Uri.parse('https://nestkeep.pages.dev/privacy'),
                    mode: LaunchMode.externalApplication),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Delete account',
                    style: TextStyle(color: NkColors.red)),
                subtitle: Text(
                  'Removes the account copy and signs you out. Your phone data stays unless you choose to clear it too.',
                  style: TextStyle(color: context.muted),
                ),
                onTap: user == null ? null : () => _deleteAccount(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'NestKeep 1.3.0 · Made to be kept: no ads, no selling data, your home data lives on your phone.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: context.muted),
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

  Future<void> _export(BuildContext context) async {
    final db = await AppDb.open();
    final data = <String, Object?>{};
    for (final table in [
      'homes', 'task_instances', 'appliances', 'receipts', 'expenses',
      'contractors', 'home_notes', 'belongings'
    ]) {
      data[table] = await db.query(table);
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/nestkeep-backup.json');
    await file.writeAsString(jsonEncode(data));
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final wipeLocal = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This deletes the backed-up copy of your home and your account. '
          'Do you also want to clear everything on this phone?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep phone data')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear everything')),
        ],
      ),
    );
    if (wipeLocal == null) return;
    await SyncService.deleteAccount();
    if (wipeLocal) {
      await AppDb.wipeAll();
    }
    await state.reload();
  }
}

/// The badge shelf: small proof of a home being looked after, earned
/// from the app's own numbers. The Pro member badge doubles as the
/// quietest possible advert for the paid plan.
class _BadgesCard extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenPaywall;

  const _BadgesCard({required this.state, required this.onOpenPaywall});

  @override
  Widget build(BuildContext context) {
    final badges = computeBadges(
      doneCount:
          state.tasks.where((t) => t.status == TaskStatus.done).length,
      receiptsCount: state.receipts.length,
      appliancesCount: state.appliances.length,
      streakWeeks: state.streakWeeks,
      score: state.health.score,
      isPro: state.isPro,
    );
    final earnedCount = badges.where((b) => b.earned).length;
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
                  '$earnedCount of ${badges.length} earned',
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisExtent: 104,
              crossAxisSpacing: 6,
              mainAxisSpacing: 10,
            ),
            itemCount: badges.length,
            itemBuilder: (context, i) {
              final b = badges[i];
              final Color iconColor;
              final Color bgColor;
              if (b.earned && b.isProBadge) {
                iconColor = NkColors.amber;
                bgColor = NkColors.amber.withValues(alpha: 0.15);
              } else if (b.earned) {
                iconColor = context.primary;
                bgColor = context.primary.withValues(alpha: 0.13);
              } else {
                iconColor = context.muted.withValues(alpha: 0.45);
                bgColor = context.line.withValues(alpha: 0.5);
              }
              return GestureDetector(
                onTap: b.isProBadge && !b.earned ? onOpenPaywall : null,
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
                        color: b.earned ? context.navyText : context.muted,
                        height: 1.15,
                      ),
                    ),
                    if (b.progressLabel != null)
                      Text(
                        b.progressLabel!,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 10.5, color: context.muted),
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

/// The avatar picker: twelve emoji faces for the Today header, six
/// free and six Pro. Locked ones open the paywall, in the same quiet
/// way the Pro badge does. A Pro avatar already picked stays picked
/// if the plan lapses; it just cannot be re-picked while locked.
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
          GridView.builder(
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
                    onOpenPaywall();
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
                                ? Border.all(
                                    color: context.primary, width: 2.5)
                                : null,
                          ),
                          child: Center(
                            child: Opacity(
                              opacity: locked ? 0.45 : 1,
                              child: Text(a.emoji,
                                  style: const TextStyle(fontSize: 24)),
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
          ),
        ],
      ),
    );
  }
}

/// The app-colour picker: indigo, purple or plum (one close family),
/// worn by the whole app in light and dark alike.
class _ColourCard extends StatelessWidget {
  final AppState state;

  const _ColourCard({required this.state});

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
            children: [
              for (final accent in AppAccent.values) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => state.setAccent(accent),
                    child: Column(
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
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Works in light and dark.',
            style: TextStyle(fontSize: 12.5, color: context.muted),
          ),
        ],
      ),
    );
  }
}
