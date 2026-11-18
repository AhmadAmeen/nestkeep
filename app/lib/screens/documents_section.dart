import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../spaces.dart';
import '../theme.dart';
import '../widgets.dart';

/// My Home's Documents section (Pro): photos of the papers that belong
/// to this home — deed, insurance, manuals — filed under the whole home
/// or under a space the user names (Kitchen, Garden…). Files live on
/// this phone only, never synced, like receipt photos. A lapsed Pro
/// keeps viewing everything; adding and editing pause at the paywall.
class DocumentsSection extends StatefulWidget {
  final AppState state;
  final VoidCallback onOpenPaywall;

  const DocumentsSection({
    super.key,
    required this.state,
    required this.onOpenPaywall,
  });

  @override
  State<DocumentsSection> createState() => _DocumentsSectionState();
}

// Filter sentinels: -2 = everything, -1 = whole home, >= 0 = a space id.
const _filterAll = -2;
const _filterWholeHome = -1;

class _DocumentsSectionState extends State<DocumentsSection> {
  int _filter = _filterAll;

  AppState get state => widget.state;

  List<HomeDoc> get _visibleDocs {
    final docs = state.docs;
    return switch (_filter) {
      _filterAll => docs,
      _filterWholeHome => docs.where((d) => d.spaceId == null).toList(),
      _ => docs.where((d) => d.spaceId == _filter).toList(),
    };
  }

  String? _spaceName(int? spaceId) {
    if (spaceId == null) return null;
    for (final s in state.spaces) {
      if (s.id == spaceId) return s.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final docs = state.docs;
    final locked = !state.isPro && docs.isEmpty && state.spaces.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          docs.isEmpty ? 'Documents' : 'Documents · ${docs.length}',
          actionLabel: locked ? null : 'Add',
          onAction: state.isPro ? _addDoc : widget.onOpenPaywall,
        ),
        const SizedBox(height: 10),
        if (locked)
          NkCard(
            onTap: widget.onOpenPaywall,
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: NkColors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: NkColors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Home documents and spaces are a Pro feature',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: context.navyText,
                        ),
                      ),
                      Text(
                        'Keep the papers that belong to this home: deed, insurance, manuals.',
                        style: TextStyle(fontSize: 13, color: context.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          )
        else ...[
          _chipsRow(context),
          const SizedBox(height: 12),
          if (!state.isPro)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NkCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Text(
                  'Pro is off, so adding and editing are paused. Everything you saved is still here to look at.',
                  style: TextStyle(fontSize: 13, color: context.muted),
                ),
              ),
            ),
          if (docs.isEmpty)
            NkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nothing filed yet.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.navyText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep the papers that belong to this home: deed, insurance, manuals. File each one under the whole home, or under a space you name.',
                    style: TextStyle(color: context.muted, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _addDoc,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add document'),
                  ),
                ],
              ),
            )
          else if (_visibleDocs.isEmpty)
            NkCard(
              child: Text(
                'Nothing filed here yet.',
                style: TextStyle(color: context.muted),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.98,
              ),
              itemCount: _visibleDocs.length,
              itemBuilder: (context, i) => _docCell(context, _visibleDocs[i]),
            ),
        ],
      ],
    );
  }

  Widget _chipsRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            context,
            label: 'All',
            selected: _filter == _filterAll,
            onTap: () {
              setState(() => _filter = _filterAll);
            },
          ),
          const SizedBox(width: 8),
          _chip(
            context,
            label: 'Whole home',
            selected: _filter == _filterWholeHome,
            onTap: () {
              setState(() => _filter = _filterWholeHome);
            },
          ),
          for (final s in state.spaces) ...[
            const SizedBox(width: 8),
            _chip(
              context,
              label: s.name,
              icon: spaceIcon(s.icon),
              selected: _filter == s.id,
              onTap: () => setState(() => _filter = s.id!),
              onLongPress: () => _manageSpace(s),
            ),
          ],
          const SizedBox(width: 8),
          _chip(
            context,
            label: 'Space',
            icon: Icons.add,
            selected: false,
            onTap: state.isPro ? _addSpace : widget.onOpenPaywall,
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final accent = context.primary;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.13)
              : context.line.withValues(alpha: 0.35),
          border: Border.all(
            color: selected ? accent : context.line,
            width: selected ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? accent : context.navyText),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? accent : context.navyText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docCell(BuildContext context, HomeDoc doc) {
    final file = File(doc.filePath);
    final hasImage = file.existsSync();
    final space = _spaceName(doc.spaceId);
    return NkCard(
      onTap: () async {
        // The photo view pops with 'deleted' when the document is
        // deleted from it; confirm here on the list (build 20).
        final result = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => DocPhotoView(
              state: state,
              doc: doc,
              onOpenPaywall: widget.onOpenPaywall,
            ),
          ),
        );
        if (result == 'deleted' && context.mounted) {
          showTicker(context, 'Document deleted');
        }
      },
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: hasImage
                ? Image.file(
                    file,
                    height: 84,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _thumbFallback(context),
                  )
                : _thumbFallback(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.navyText,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${space ?? 'Whole home'} · '
                  '${doc.createdAt.month}/${doc.createdAt.day}/${doc.createdAt.year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: context.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback(BuildContext context) {
    return Container(
      height: 84,
      width: double.infinity,
      color: context.line.withValues(alpha: 0.4),
      child: Icon(Icons.description_outlined, color: context.muted, size: 30),
    );
  }

  // ---------- spaces ----------

  Future<void> _addSpace() async {
    final created = await createHomeSpace(context, state);
    if (created != null && mounted) {
      setState(() => _filter = created.id!);
      showTicker(context, 'Space added');
    }
  }

  Future<void> _manageSpace(HomeSpace space) async {
    if (!state.isPro) {
      widget.onOpenPaywall();
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename space'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete space'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'rename') {
      final result = await showDialog<_SpaceFormResult>(
        context: context,
        builder: (_) => _SpaceFormDialog(
          heading: 'Rename space',
          initialName: space.name,
          initialIcon: space.icon,
        ),
      );
      if (result == null) return;
      await AppDb.updateHomeSpace(
        space.copyWith(
          name: result.name,
          icon: result.icon,
          updatedAt: DateTime.now(),
        ),
      );
      await state.reload();
      if (mounted) showTicker(context, 'Space updated');
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete ${space.name}?'),
          content: Text(
            'Docs filed under ${space.name} will move to Whole home. '
            'The space itself is removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: NkColors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await AppDb.deleteHomeSpace(space.id!);
      if (!mounted) return;
      if (_filter == space.id) setState(() => _filter = _filterAll);
      await state.reload();
      if (mounted) showTicker(context, 'Space deleted');
    }
  }

  // ---------- documents ----------

  Future<void> _addDoc() async {
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
    final String dest;
    try {
      // Copied into the app's own folder, like appliance attachments:
      // the document stays put even if the gallery photo is deleted.
      // Local only, never synced.
      final dir = await getApplicationDocumentsDirectory();
      dest = p.join(
        dir.path,
        'homedoc_${DateTime.now().millisecondsSinceEpoch}'
        '${p.extension(picked.path)}',
      );
      await File(picked.path).copy(dest);
    } catch (_) {
      return;
    }
    if (!mounted) {
      try {
        await File(dest).delete();
      } catch (_) {}
      return;
    }
    final result = await showDialog<_DocFormResult>(
      context: context,
      builder: (_) => _DocFormDialog(
        heading: 'Add document',
        spaces: state.spaces,
        initialSpaceId: _filter >= 0 ? _filter : null,
        onNewSpace: () => createHomeSpace(context, state),
      ),
    );
    if (result == null) {
      // Backed out of the form: do not leave an orphaned file behind.
      try {
        await File(dest).delete();
      } catch (_) {}
      return;
    }
    final now = DateTime.now();
    await AppDb.insertHomeDoc(
      HomeDoc(
        homeId: state.activeHome!.id!,
        spaceId: result.spaceId,
        title: result.title,
        filePath: dest,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (result.spaceId != null) {
      setState(() => _filter = result.spaceId!);
    } else if (_filter != _filterAll) {
      setState(() => _filter = _filterWholeHome);
    }
    await state.reload();
    if (mounted) showTicker(context, 'Document added');
  }
}

/// Full-screen look at one document photo, with its filing details.
/// Editing and deleting pause at the paywall when Pro is off; looking
/// never does.
class DocPhotoView extends StatefulWidget {
  final AppState state;
  final HomeDoc doc;
  final VoidCallback onOpenPaywall;

  const DocPhotoView({
    super.key,
    required this.state,
    required this.doc,
    required this.onOpenPaywall,
  });

  @override
  State<DocPhotoView> createState() => _DocPhotoViewState();
}

class _DocPhotoViewState extends State<DocPhotoView> {
  AppState get state => widget.state;

  /// The freshest copy: edits reload state, so read from there.
  HomeDoc get _current => state.docs.firstWhere(
    (d) => d.id == widget.doc.id,
    orElse: () => widget.doc,
  );

  String get _spaceLine {
    final doc = _current;
    final name = doc.spaceId == null
        ? 'Whole home'
        : state.spaces
              .where((s) => s.id == doc.spaceId)
              .map((s) => s.name)
              .firstOrNull;
    return '${name ?? 'Whole home'} · '
        '${doc.createdAt.month}/${doc.createdAt.day}/${doc.createdAt.year}';
  }

  Future<void> _edit() async {
    final doc = _current;
    final result = await showDialog<_DocFormResult>(
      context: context,
      builder: (_) => _DocFormDialog(
        heading: 'Edit document',
        spaces: state.spaces,
        initialTitle: doc.title,
        initialSpaceId: doc.spaceId,
        onNewSpace: () => createHomeSpace(context, state),
      ),
    );
    if (result == null) return;
    await AppDb.updateHomeDoc(
      doc.copyWith(
        title: result.title,
        spaceId: result.spaceId,
        clearSpace: result.spaceId == null,
        updatedAt: DateTime.now(),
      ),
    );
    await state.reload();
    if (mounted) {
      setState(() {});
      showTicker(context, 'Document updated');
    }
  }

  Future<void> _delete() async {
    final doc = _current;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this document?'),
        content: const Text(
          'The photo is removed from this phone. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NkColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AppDb.deleteHomeDoc(doc.id!);
    try {
      await File(doc.filePath).delete();
    } catch (_) {}
    await state.reload();
    // Pop with the outcome so the documents list confirms the delete
    // once navigation has completed (build 20).
    if (mounted) Navigator.of(context).pop('deleted');
  }

  @override
  Widget build(BuildContext context) {
    final doc = _current;
    final file = File(doc.filePath);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(doc.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: state.isPro ? _edit : widget.onOpenPaywall,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: state.isPro ? _delete : widget.onOpenPaywall,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: file.existsSync()
                  ? InteractiveViewer(child: Image.file(file))
                  : const Text(
                      'This photo is no longer on this phone.',
                      style: TextStyle(color: Colors.white70),
                    ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                _spaceLine,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ask for a name and icon, save the space, and hand back the row.
/// Shared by the section's "+ Space" chip and the document form's
/// "New space…" shortcut.
Future<HomeSpace?> createHomeSpace(BuildContext context, AppState state) async {
  final result = await showDialog<_SpaceFormResult>(
    context: context,
    builder: (_) => const _SpaceFormDialog(heading: 'Add a space'),
  );
  if (result == null) return null;
  final now = DateTime.now();
  final homeId = state.activeHome!.id!;
  final id = await AppDb.insertHomeSpace(
    HomeSpace(
      homeId: homeId,
      name: result.name,
      icon: result.icon,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await state.reload();
  return HomeSpace(
    id: id,
    homeId: homeId,
    name: result.name,
    icon: result.icon,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------- dialogs ----------

class _DocFormResult {
  final String title;
  final int? spaceId;
  const _DocFormResult(this.title, this.spaceId);
}

/// Title + where to file it. Used for both adding and editing a
/// document; [onNewSpace] enables the "New space…" shortcut in the
/// dropdown.
class _DocFormDialog extends StatefulWidget {
  final String heading;
  final List<HomeSpace> spaces;
  final String initialTitle;
  final int? initialSpaceId;
  final Future<HomeSpace?> Function()? onNewSpace;

  const _DocFormDialog({
    required this.heading,
    required this.spaces,
    this.initialTitle = '',
    this.initialSpaceId,
    this.onNewSpace,
  });

  @override
  State<_DocFormDialog> createState() => _DocFormDialogState();
}

class _DocFormDialogState extends State<_DocFormDialog> {
  static const _wholeHome = -1;
  static const _newSpace = -99;

  late final _title = TextEditingController(text: widget.initialTitle);
  late List<HomeSpace> _spaces = [...widget.spaces];
  late int? _spaceId = widget.initialSpaceId;

  // Bumped after the "New space…" detour so the dropdown re-reads
  // _spaceId instead of keeping the shortcut's value on display.
  int _epoch = 0;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _onSpaceChanged(int? value) async {
    if (value == null) return;
    if (value == _newSpace) {
      final created = await widget.onNewSpace?.call();
      if (!mounted) return;
      setState(() {
        _epoch++;
        if (created != null) {
          _spaces = [..._spaces, created];
          _spaceId = created.id;
        }
      });
      return;
    }
    setState(() => _spaceId = value == _wholeHome ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.heading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Deed, insurance, manual…',
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey(_epoch),
            initialValue: _spaceId ?? _wholeHome,
            decoration: const InputDecoration(labelText: 'Filed under'),
            items: [
              const DropdownMenuItem(
                value: _wholeHome,
                child: Text('Whole home'),
              ),
              for (final s in _spaces)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
              if (widget.onNewSpace != null)
                const DropdownMenuItem(
                  value: _newSpace,
                  child: Text('New space…'),
                ),
            ],
            onChanged: _onSpaceChanged,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(context, _DocFormResult(title, _spaceId));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SpaceFormResult {
  final String name;
  final String icon;
  const _SpaceFormResult(this.name, this.icon);
}

/// Name + icon for a space, for both adding and renaming.
class _SpaceFormDialog extends StatefulWidget {
  final String heading;
  final String initialName;
  final String initialIcon;

  const _SpaceFormDialog({
    required this.heading,
    this.initialName = '',
    this.initialIcon = 'general',
  });

  @override
  State<_SpaceFormDialog> createState() => _SpaceFormDialogState();
}

class _SpaceFormDialogState extends State<_SpaceFormDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late String _icon = widget.initialIcon;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.heading),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Space name',
                hintText: 'Kitchen, Garden, Attic…',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in spaceIconKeys) _iconOption(context, key),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, _SpaceFormResult(name, _icon));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _iconOption(BuildContext context, String key) {
    final selected = _icon == key;
    final accent = context.primary;
    return InkWell(
      onTap: () => setState(() => _icon = key),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.13)
              : context.line.withValues(alpha: 0.3),
          border: Border.all(
            color: selected ? accent : context.line,
            width: selected ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              spaceIcon(key),
              size: 21,
              color: selected ? accent : context.navyText,
            ),
            const SizedBox(height: 3),
            Text(
              spaceIconLabel(key),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: selected ? accent : context.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
