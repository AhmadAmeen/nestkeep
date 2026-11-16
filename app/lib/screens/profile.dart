import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../db.dart';
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

  const ProfileScreen({
    super.key,
    required this.state,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onOpenPaywall,
    required this.onAddHome,
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
                        ? NkColors.darkPrimary
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
        const SectionHeading('Your homes'),
        const SizedBox(height: 10),
        for (final h in state.homes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NkCard(
              onTap: () => state.setActiveHome(h),
              child: Row(
                children: [
                  Icon(
                    h.id == state.activeHome?.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: NkColors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(h.addressLine,
                            style:
                                TextStyle(fontSize: 13, color: context.muted)),
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
          'NestKeep 1.0 · Made to be kept: no ads, no selling data, your home data lives on your phone.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: context.muted),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    final db = await AppDb.open();
    final data = <String, Object?>{};
    for (final table in [
      'homes', 'task_instances', 'appliances', 'receipts', 'expenses'
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
