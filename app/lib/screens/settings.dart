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

/// Settings (build 19, split out of Profile): how the app looks and
/// what happens to its data. Profile keeps who you are — account,
/// avatar, plan, homes, badges; this page keeps how it behaves.
class SettingsScreen extends StatelessWidget {
  final AppState state;
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeChanged;
  final VoidCallback onOpenPaywall;
  final VoidCallback? onShowIntro;

  const SettingsScreen({
    super.key,
    required this.state,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onOpenPaywall,
    this.onShowIntro,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
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
                  '1.5.1',
                  style: TextStyle(color: context.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'NestKeep 1.5.1 · Made to be kept: no ads, no selling data, your home data lives on your phone.',
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

/// The app-colour picker: purple, violet, plum or fuchsia (one close
/// family), worn by the whole app in light and dark alike.
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
                : 'Works in light and dark. Violet, Plum and Fuchsia come '
                    'with Pro; a colour already in use stays yours.',
            style: TextStyle(fontSize: 12.5, color: context.muted),
          ),
        ],
      ),
    );
  }
}
