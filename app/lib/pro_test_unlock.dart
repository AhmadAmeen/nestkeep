import 'package:flutter/material.dart';

import 'app_state.dart';
import 'theme.dart';

// ===========================================================================
// PRO-TEST-UNLOCK — TEMPORARY, TEST-ONLY FACILITY (build 22).
//
// !!! REMOVE BEFORE THE PRODUCTION RELEASE BUILD !!!
//
// What this is: a hidden local switch that makes THIS phone read as
// Pro, so the developer can test the Pro side from a sideloaded APK
// (Google Play Billing cannot complete a purchase on a sideload
// install, so there is no other way to exercise the Pro code paths on
// a test device). It is NOT a purchase, it creates no purchase record,
// and it grants nothing anywhere else.
//
// It must never ship: a production build containing this file would
// hand Pro to anyone who learns the code.
//
// Removal checklist (every touch point is marked PRO-TEST-UNLOCK):
//   1. Delete this file.
//   2. lib/app_state.dart: delete the proTestMode field, its load in
//      init(), and setProTestMode(); restore the plain getter
//      `bool get isPro => entitlement.isPro;`.
//   3. lib/screens/settings.dart: swap ProTestVersionTile back to a
//      plain version ListTile and drop the ProTestModeRow block.
//   4. lib/screens/profile.dart: restore the plain plan-card title.
//   5. Delete test/pro_test_unlock_test.dart.
//
// The flag lives in the local settings table under
// [proTestModeSettingKey]. That table is never synced (SyncService
// syncs data tables only) and the backup export never includes
// settings rows, so the flag cannot leave this phone.
// ===========================================================================

/// Settings-table key for the test unlock flag ('1' = on). Local only.
const String proTestModeSettingKey = 'pro_test_mode';

const String _proTestCode = 'nestkeep-pro-test';

/// The unlock code check: forgiving about case and stray spaces,
/// exact about everything else.
bool proTestCodeMatches(String input) =>
    input.trim().toLowerCase() == _proTestCode;

/// Settings → About version row. Looks exactly like the plain row it
/// replaced; tapping it 7 times opens the test-unlock code dialog.
class ProTestVersionTile extends StatefulWidget {
  final AppState state;
  final String versionLabel;

  const ProTestVersionTile({
    super.key,
    required this.state,
    required this.versionLabel,
  });

  @override
  State<ProTestVersionTile> createState() => _ProTestVersionTileState();
}

class _ProTestVersionTileState extends State<ProTestVersionTile> {
  int _taps = 0;

  void _onTap() {
    _taps++;
    if (_taps < 7) return;
    _taps = 0;
    _showCodeDialog();
  }

  Future<void> _showCodeDialog() async {
    final controller = TextEditingController();
    var wrong = false;
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void submit() {
            if (proTestCodeMatches(controller.text)) {
              Navigator.pop(ctx, true);
            } else {
              setLocal(() => wrong = true);
            }
          }

          return AlertDialog(
            title: const Text('Pro test unlock'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Test-only: turns Pro on or off on this phone. '
                  'Not a purchase.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Test code',
                    errorText: wrong ? 'Wrong code' : null,
                  ),
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submit,
                child: Text(widget.state.proTestMode ? 'Turn off' : 'Turn on'),
              ),
            ],
          );
        },
      ),
    );
    if (apply == true && mounted) {
      await widget.state.setProTestMode(!widget.state.proTestMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Version'),
      trailing: Text(
        widget.versionLabel,
        style: TextStyle(color: context.muted),
      ),
      onTap: _onTap,
    );
  }
}

/// The visible "test mode is on" row for Settings → About, with the
/// one-tap way back out. Shown only while the test unlock is on.
class ProTestModeRow extends StatelessWidget {
  final AppState state;

  const ProTestModeRow({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Pro (test mode)'),
      subtitle: Text(
        'Test unlock is on — not a real purchase.',
        style: TextStyle(color: context.muted),
      ),
      trailing: TextButton(
        onPressed: () => state.setProTestMode(false),
        child: const Text('Turn off'),
      ),
    );
  }
}
