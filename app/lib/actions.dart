import 'app_state.dart';
import 'db.dart';
import 'models.dart';
import 'plan.dart';
import 'reminders.dart';
import 'sync.dart';

/// Shared task mutations used by Today, Plan and the task guide screen.

Future<void> completeTask(
  AppState state,
  TaskInstance task, {
  double? costPaid,
}) async {
  final now = DateTime.now();
  final done = task.copyWith(
    status: TaskStatus.done,
    doneDate: now,
    costPaid: costPaid,
    updatedAt: now,
  );
  await AppDb.updateTask(done);

  // Recurring library jobs roll forward from the day they were done.
  final tpl = task.templateId == null ? null : state.templateById[task.templateId];
  if (tpl != null) {
    await AppDb.insertTask(TaskInstance(
      homeId: task.homeId,
      templateId: tpl.id,
      title: tpl.title,
      category: tpl.category,
      dueDate: nextDueAfter(tpl, now),
      updatedAt: now,
    ));
  }

  if (costPaid != null && costPaid > 0) {
    await AppDb.insertExpense(Expense(
      homeId: task.homeId,
      date: now,
      amount: costPaid,
      category: task.category,
      taskId: task.id,
      note: task.title,
      updatedAt: now,
    ));
  }

  await state.reload();
  await Reminders.reschedule(state.tasks);
  SyncService.syncNow();
}

Future<void> skipTask(AppState state, TaskInstance task) async {
  final now = DateTime.now();
  await AppDb.updateTask(task.copyWith(
    status: TaskStatus.skipped,
    updatedAt: now,
  ));
  final tpl = task.templateId == null ? null : state.templateById[task.templateId];
  if (tpl != null) {
    await AppDb.insertTask(TaskInstance(
      homeId: task.homeId,
      templateId: tpl.id,
      title: tpl.title,
      category: tpl.category,
      dueDate: nextDueAfter(tpl, task.dueDate),
      updatedAt: now,
    ));
  }
  await state.reload();
  await Reminders.reschedule(state.tasks);
  SyncService.syncNow();
}

Future<void> snoozeTask(AppState state, TaskInstance task, int days) async {
  final now = DateTime.now();
  await AppDb.updateTask(task.copyWith(
    dueDate: task.dueDate.add(Duration(days: days)),
    updatedAt: now,
  ));
  await state.reload();
  await Reminders.reschedule(state.tasks);
  SyncService.syncNow();
}
