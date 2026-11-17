import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../pdf_report.dart';
import '../sync.dart';
import '../theme.dart';
import '../widgets.dart';

/// Cost tracker. Free: this year's total and the recent list. Pro: switch
/// years, per-category breakdown, and the PDF home report.
class ExpensesScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onOpenPaywall;

  const ExpensesScreen(
      {super.key, required this.state, required this.onOpenPaywall});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final isPro = state.isPro;
    final yearExpenses =
        state.expenses.where((e) => e.date.year == _year).toList();
    final total = yearExpenses.fold(0.0, (s, e) => s + e.amount);
    final byCategory = <String, double>{};
    for (final e in yearExpenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final sortedCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final years = state.expenses.map((e) => e.date.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Costs',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.navyText)),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Home report (Pro)',
              onPressed: () =>
                  isPro ? shareHomeReport(state) : widget.onOpenPaywall(),
            ),
            FilledButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        NkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Spent in $_year',
                        style: TextStyle(color: context.muted)),
                  ),
                  if (isPro && years.length > 1)
                    DropdownButton<int>(
                      value: _year,
                      items: years
                          .map((y) => DropdownMenuItem(
                              value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) => setState(() => _year = v ?? _year),
                    )
                  else if (!isPro && years.length > 1)
                    TextButton(
                      onPressed: widget.onOpenPaywall,
                      child: const Text('Year view is Pro'),
                    ),
                ],
              ),
              Text(money(total),
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: context.navyText)),
              if (isPro && sortedCats.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final c in sortedCats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(categoryIcon(c.key),
                            size: 18, color: categoryColor(c.key)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.key)),
                        Text(money(c.value),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeading('Recent'),
        const SizedBox(height: 10),
        if (yearExpenses.isEmpty)
          NkCard(
            child: Text(
              'No costs logged yet. Marking a job done asks what it cost, and receipts log themselves.',
              style: TextStyle(color: context.muted, height: 1.4),
            ),
          ),
        for (final e in yearExpenses.take(40)) ...[
          NkCard(
            // Tap any entry to edit it (or delete it from the form).
            onTap: () => _expenseForm(existing: e),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: categoryColor(e.category).withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(categoryIcon(e.category),
                      color: categoryColor(e.category), size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.note ?? e.category,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: context.navyText)),
                      Text(
                        '${e.date.month}/${e.date.day}/${e.date.year} · ${e.category}',
                        style: TextStyle(fontSize: 13, color: context.muted),
                      ),
                    ],
                  ),
                ),
                Text(money(e.amount),
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: context.navyText)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _addExpense() => _expenseForm();

  /// The add-cost form, doubling as the edit form when [existing] is
  /// given: fields come prefilled, Save writes the row back, and a
  /// Delete option (edit mode only) removes it after a confirmation.
  /// Editing or deleting touches ONLY the expense row — a receipt that
  /// logged this cost keeps its own record, image and all.
  Future<void> _expenseForm({Expense? existing}) async {
    final isEdit = existing != null;
    final amount = TextEditingController(
        text: isEdit ? _amountText(existing.amount) : '');
    final note = TextEditingController(text: existing?.note ?? '');
    var category = existing?.category ?? 'Interior';
    var date = existing?.date ?? DateTime.now();
    const baseCategories = [
      'HVAC', 'Plumbing', 'Roof & Gutters', 'Exterior', 'Interior',
      'Safety', 'Appliances', 'Seasonal',
    ];
    final categories = <String>{
      ...baseCategories,
      if (isEdit) existing.category,
    }.toList();

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit cost' : 'Add a cost'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Amount', prefixText: '\$ '),
                autofocus: !isEdit,
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'What for'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => category = v ?? category,
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined, size: 20),
                title: const Text('Date'),
                subtitle: Text('${date.month}/${date.day}/${date.year}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2015),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setDialogState(() => date = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            if (isEdit)
              TextButton(
                onPressed: () async {
                  final sure = await _confirmDelete();
                  if (sure && ctx.mounted) {
                    Navigator.pop(ctx, 'delete');
                  }
                },
                style:
                    TextButton.styleFrom(foregroundColor: NkColors.red),
                child: const Text('Delete'),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: Text(isEdit ? 'Save changes' : 'Add')),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'delete') {
      await AppDb.deleteExpense(existing!.id!);
      await state.reload();
      SyncService.syncNow();
      return;
    }

    final value = double.tryParse(amount.text.trim());
    if (value == null || value <= 0) return;
    final now = DateTime.now();
    final noteText = note.text.trim().isEmpty ? null : note.text.trim();
    if (isEdit) {
      // Same row, new values: the id and any task/appliance links stay,
      // and updatedAt moves so sync's last-write-wins picks the edit up.
      await AppDb.updateExpense(Expense(
        id: existing.id,
        homeId: existing.homeId,
        date: date,
        amount: value,
        category: category,
        taskId: existing.taskId,
        applianceId: existing.applianceId,
        note: noteText,
        updatedAt: now,
      ));
    } else {
      await AppDb.insertExpense(Expense(
        homeId: state.activeHome!.id!,
        date: date,
        amount: value,
        category: category,
        note: noteText,
        updatedAt: now,
      ));
    }
    await state.reload();
    SyncService.syncNow();
  }

  /// The delete confirmation, shown over the edit form.
  Future<bool> _confirmDelete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text(
            'This cost will be removed from your tracker. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep it')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: NkColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return sure ?? false;
  }

  /// Prefill text for the amount field: whole dollars without a
  /// trailing ".0", cents kept as typed.
  static String _amountText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
