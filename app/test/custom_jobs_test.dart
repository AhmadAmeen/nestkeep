import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/plan.dart';

TaskInstance _task({String? templateId, TaskStatus status = TaskStatus.upcoming}) =>
    TaskInstance(
      homeId: 1,
      templateId: templateId,
      title: 'Job',
      category: 'Interior',
      dueDate: DateTime(2026, 12, 1),
      status: status,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('counts only live custom jobs', () {
    final tasks = [
      _task(), // custom, live
      _task(), // custom, live
      _task(templateId: 'hvac-filter'), // from the plan, not custom
      _task(status: TaskStatus.done), // custom but finished
      _task(status: TaskStatus.skipped), // custom but skipped
    ];
    expect(activeCustomJobs(tasks), 2);
    expect(freeCustomJobLimit, 10);
  });
}
