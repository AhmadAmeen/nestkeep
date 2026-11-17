import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_state.dart';
import '../db.dart';
import '../lifespan.dart';
import '../models.dart';
import '../sync.dart';
import '../theme.dart';
import '../widgets.dart';
import 'appliance_form.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// One appliance, in full: where it is in its expected life, what its
/// warranty is doing, and the photos and invoices attached to it.
/// Attachments are a Pro extra and live on this phone only.
class ApplianceDetailScreen extends StatefulWidget {
  final AppState state;
  final Appliance appliance;
  final VoidCallback onOpenPaywall;

  const ApplianceDetailScreen({
    super.key,
    required this.state,
    required this.appliance,
    required this.onOpenPaywall,
  });

  @override
  State<ApplianceDetailScreen> createState() => _ApplianceDetailScreenState();
}

class _ApplianceDetailScreenState extends State<ApplianceDetailScreen> {
  List<ApplianceFile> _files = [];

  AppState get state => widget.state;

  /// The freshest copy of this appliance: the form edits the row and
  /// reloads state, so read from state and fall back to what we were
  /// handed if it has since been deleted.
  Appliance get _current => state.appliances.firstWhere(
        (x) => x.id == widget.appliance.id,
        orElse: () => widget.appliance,
      );

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final id = widget.appliance.id;
    if (id == null) return;
    final files = await AppDb.filesForAppliance(id);
    if (mounted) setState(() => _files = files);
  }

  /// The condition tag, saved exactly as the My Home card saves it,
  /// so the two never disagree.
  Future<void> _saveCondition(String? condition) async {
    final a = _current;
    if (a.id == null) return;
    await AppDb.updateAppliance(a.copyWith(
      condition: condition,
      clearCondition: condition == null,
      updatedAt: DateTime.now(),
    ));
    await state.reload();
    SyncService.syncNow();
    if (mounted) setState(() {});
  }

  Future<void> _addFile() async {
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
    final a = _current;
    if (a.id == null) return;
    try {
      // Copied into the app's own folder, like receipt images: the
      // attachment stays put even if the gallery photo is deleted.
      // Local only, never synced.
      final dir = await getApplicationDocumentsDirectory();
      final dest = p.join(
        dir.path,
        'appliance_${a.id}_${DateTime.now().millisecondsSinceEpoch}'
        '${p.extension(picked.path)}',
      );
      await File(picked.path).copy(dest);
      await AppDb.insertApplianceFile(ApplianceFile(
        applianceId: a.id!,
        path: dest,
        createdAt: DateTime.now(),
      ));
      // Reload so the My Home card picks up the new first photo.
      await state.reload();
      await _loadFiles();
    } catch (_) {
      // A failed copy just leaves the attachments as they were.
    }
  }

  void _openImage(String path, {ApplianceFile? file}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullImage(
        path: path,
        onDelete: file == null
            ? null
            : () async {
                await AppDb.deleteApplianceFile(file.id!);
                try {
                  await File(file.path).delete();
                } catch (_) {}
                // Reload so the My Home card drops the removed photo.
                await state.reload();
                await _loadFiles();
              },
      ),
    ));
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ApplianceFormScreen(
        state: state,
        existing: _current,
        onOpenPaywall: widget.onOpenPaywall,
      ),
    ));
    await _loadFiles();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final a = _current;
    final now = DateTime.now();
    final status = lifeStatus(a, now);
    final statusColor = lifeStatusColor(status);
    final end = a.warrantyEnd;
    final subLine = [a.brand, a.model, a.serial]
        .where((s) => (s ?? '').isNotEmpty)
        .join(' · ');
    final hasReceiptImage =
        a.imagePath != null && File(a.imagePath!).existsSync();

    return Scaffold(
      appBar: AppBar(title: const Text('Appliance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.kitchen_outlined,
                    color: statusColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: context.navyText)),
                    if (subLine.isNotEmpty)
                      Text(subLine,
                          style:
                              TextStyle(fontSize: 13, color: context.muted)),
                    const SizedBox(height: 7),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConditionChip(
                        condition: a.condition,
                        onTap: () => showConditionSheet(
                          context,
                          current: a.condition,
                          onSave: _saveCondition,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (a.purchaseDate != null) LifeChip(status: status),
            ],
          ),
          if (a.purchaseDate != null) ...[
            const SizedBox(height: 16),
            NkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expected life',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.navyText)),
                  const SizedBox(height: 10),
                  LifeBar(appliance: a, now: now, height: 11),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Year ${lifeYearIndex(a, now)}',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.navyText),
                              ),
                              TextSpan(
                                text:
                                    ' of about ${effectiveLifespan(a)}',
                                style: TextStyle(
                                    fontSize: 12.5, color: context.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(lifeLeftLabel(a, now),
                          style:
                              TextStyle(fontSize: 12.5, color: context.muted)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (status) {
                      LifeStatus.good =>
                        'Plenty of life left. Keep up its plan jobs.',
                      LifeStatus.monitor =>
                        'Appliances like this typically last about '
                            '${effectiveLifespan(a)} years. Start budgeting '
                            'in the last couple of years so a breakdown is '
                            'not a surprise bill.',
                      LifeStatus.replaceSoon =>
                        'This one is at the end of its typical life. '
                            'Budget for a replacement so a breakdown is not '
                            'a surprise bill.',
                    },
                    style: TextStyle(
                        fontSize: 12.5, color: context.muted, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stat(
                context,
                a.purchaseDate == null ? 'Not set' : _monthYear(a.purchaseDate!),
                'Bought',
              ),
              const SizedBox(width: 10),
              _stat(context, a.price == null ? '—' : money(a.price!), 'Paid'),
              const SizedBox(width: 10),
              _stat(
                context,
                end == null
                    ? 'Not set'
                    : end.isAfter(now)
                        ? _monthYear(end)
                        : 'Ended',
                'Warranty',
              ),
            ],
          ),
          const SizedBox(height: 12),
          NkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attached to this appliance',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.navyText)),
                if (!hasReceiptImage && _files.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'The invoice, a photo of the nameplate, proof of '
                      'purchase: keep them with the appliance.',
                      style: TextStyle(
                          fontSize: 12.5, color: context.muted, height: 1.4),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasReceiptImage)
                      _chip(
                        context,
                        icon: Icons.receipt_long_outlined,
                        label: 'Receipt photo',
                        onTap: () => _openImage(a.imagePath!),
                      ),
                    for (var i = 0; i < _files.length; i++)
                      _chip(
                        context,
                        icon: Icons.image_outlined,
                        label: 'Photo ${i + 1}',
                        onTap: () =>
                            _openImage(_files[i].path, file: _files[i]),
                      ),
                    if (state.isPro)
                      _chip(
                        context,
                        icon: Icons.add,
                        label: 'Add photo or invoice',
                        onTap: _addFile,
                      )
                    else
                      _chip(
                        context,
                        icon: Icons.lock_outline,
                        label: 'Add photo or invoice · Pro',
                        color: NkColors.amber,
                        onTap: widget.onOpenPaywall,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if ((a.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            NkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.navyText)),
                  const SizedBox(height: 4),
                  Text(a.notes!,
                      style: TextStyle(
                          fontSize: 13.5, color: context.muted, height: 1.45)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _edit,
            child: const Text('Edit appliance'),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Expanded(
      child: NkCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        child: Column(
          children: [
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.navyText)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: context.muted)),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final fg = color ?? context.navyText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: context.line.withValues(alpha: 0.35),
          border: Border.all(color: context.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Full-screen look at one attachment, with a way to remove it.
class _FullImage extends StatelessWidget {
  final String path;
  final Future<void> Function()? onDelete;

  const _FullImage({required this.path, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove attachment',
              onPressed: () async {
                await onDelete!();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(path)),
        ),
      ),
    );
  }
}
