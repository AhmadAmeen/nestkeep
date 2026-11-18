import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// The category list shared by the expense form and the custom-job
/// form (build 24): the eight built-ins, then the user's own
/// categories, then the way to add another. Before build 24 each
/// form carried its own copy of the built-in list and there was no
/// way to add one.
///
/// Custom categories are Pro to CREATE: a free user tapping
/// "+ New category" is sent to the paywall instead. Categories a
/// user already made stay listed and usable if Pro lapses — only
/// creating is gated. Deleting one (the small delete on its row)
/// removes it from the pickers; expenses and jobs already filed
/// under the name keep displaying it, because they store the
/// category as a plain string.

/// The built-in categories, in picker order.
const baseCategories = [
  'HVAC',
  'Plumbing',
  'Roof & Gutters',
  'Exterior',
  'Interior',
  'Safety',
  'Appliances',
  'Seasonal',
];

/// How many categories of their own a user can keep.
const maxCustomCategories = 20;

/// The form field that opens the picker: the current category in a
/// standard input frame with a dropdown arrow, replacing the old
/// DropdownButtonFormField (whose menu could not carry per-entry
/// delete buttons or a gated "+ New category" entry).
class CategoryField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const CategoryField({super.key, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Category',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(value),
      ),
    );
  }
}

/// Open the category picker over [context] (a form dialog, usually).
/// Returns the picked category name, or null when the user backed
/// out without changing anything — including the free-user trip to
/// the paywall and the at-cap refusal, which change nothing.
Future<String?> showCategoryPicker(
  BuildContext context, {
  required AppState state,
  required String current,
  required VoidCallback onOpenPaywall,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CategoryPickerSheet(
      state: state,
      current: current,
      onOpenPaywall: onOpenPaywall,
      tickerContext: context,
    ),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  final AppState state;
  final String current;
  final VoidCallback onOpenPaywall;

  /// The form's context, kept so the at-cap ticker can be shown on
  /// the screen the user returns to (a ticker shown from inside
  /// the sheet would expire hidden behind it).
  final BuildContext tickerContext;

  const _CategoryPickerSheet({
    required this.state,
    required this.current,
    required this.onOpenPaywall,
    required this.tickerContext,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  /// A local snapshot so a delete repaints the sheet at once; the
  /// state's own list is refreshed by the same calls.
  late final List<CustomCategory> _customs = [...widget.state.customCategories];

  Future<void> _delete(CustomCategory c) async {
    await widget.state.removeCustomCategory(c.id!);
    if (!mounted) return;
    if (c.name == widget.current) {
      // The category the form had selected is gone: close with a
      // built-in fallback so the form is never left pointing at a
      // name the pickers no longer offer.
      Navigator.of(context).pop('Interior');
      return;
    }
    setState(() => _customs.removeWhere((x) => x.id == c.id));
  }

  Future<void> _newCategory() async {
    final state = widget.state;
    if (!state.isPro) {
      Navigator.of(context).pop(null);
      widget.onOpenPaywall();
      return;
    }
    if (state.customCategories.length >= maxCustomCategories) {
      Navigator.of(context).pop(null);
      showTicker(
        widget.tickerContext,
        'You can have up to $maxCustomCategories custom categories',
      );
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NewCategoryDialog(
        taken: {
          for (final c in baseCategories) c.toLowerCase(),
          for (final c in state.customCategories) c.name.toLowerCase(),
        },
      ),
    );
    if (name == null || !mounted) return;
    await state.addCustomCategory(name);
    if (!mounted) return;
    // The new category is the pick: close with it selected.
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    final known = <String>{...baseCategories, for (final c in _customs) c.name};
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.navyText,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // A current value the lists no longer hold (an
                  // expense filed under a since-deleted category):
                  // shown, checked, with nothing to delete — the
                  // record keeps its name either way.
                  if (!known.contains(current))
                    ListTile(
                      leading: Icon(
                        Icons.check,
                        size: 19,
                        color: context.primary,
                      ),
                      title: Text(current),
                      onTap: () => Navigator.of(context).pop(current),
                    ),
                  for (final c in baseCategories)
                    ListTile(
                      leading: Icon(
                        c == current ? Icons.check : null,
                        size: 19,
                        color: context.primary,
                      ),
                      title: Text(c),
                      onTap: () => Navigator.of(context).pop(c),
                    ),
                  if (_customs.isNotEmpty) const Divider(height: 1),
                  for (final c in _customs)
                    ListTile(
                      leading: Icon(
                        c.name == current ? Icons.check : null,
                        size: 19,
                        color: context.primary,
                      ),
                      title: Text(c.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Delete category',
                        onPressed: () => _delete(c),
                      ),
                      onTap: () => Navigator.of(context).pop(c.name),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.add, size: 19, color: context.primary),
                    title: const Text('New category'),
                    trailing: widget.state.isPro
                        ? null
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: NkColors.amber,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: NkColors.lightNavy,
                              ),
                            ),
                          ),
                    onTap: _newCategory,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The name prompt for a new category. Validates in place: an empty
/// name or one already in use (built-in or custom, any case) keeps
/// the dialog open with the reason under the field.
class _NewCategoryDialog extends StatefulWidget {
  final Set<String> taken;

  const _NewCategoryDialog({required this.taken});

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the category a name');
      return;
    }
    if (widget.taken.contains(name.toLowerCase())) {
      setState(() => _error = 'That category already exists');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New category'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Garden',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
