import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../calendar.dart';
import '../db.dart';
import '../sync.dart';
import '../theme.dart';
import '../widgets.dart';

/// Settings (build 19, split out of Profile): what happens to the
/// app's data, and about. How the app looks moved back to Profile in
/// build 20, with who you are — account, avatar, appearance, plan,
/// homes, badges.
class SettingsScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenPaywall;
  final VoidCallback? onShowIntro;

  const SettingsScreen({
    super.key,
    required this.state,
    required this.onOpenPaywall,
    this.onShowIntro,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
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
                onTap: state.signedIn ? () => _deleteAccount(context) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeading('About'),
        const SizedBox(height: 10),
        NkCard(
          child: Column(
            children: [
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
                title: const Text('Version'),
                trailing: Text(
                  '1.5.2',
                  style: TextStyle(color: context.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'NestKeep 1.5.2 · Made to be kept: no ads, no selling data, your home data lives on your phone.',
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
