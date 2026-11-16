import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/sync.dart';

Map<String, Object?> row(int id, String title, String updatedAt) =>
    {'id': id, 'title': title, 'updatedAt': updatedAt};

void main() {
  test('merge keeps the newer version of a record', () {
    final local = [row(1, 'old', '2026-11-01T10:00:00')];
    final remote = [row(1, 'new', '2026-11-05T10:00:00')];
    final merged = mergeRows(local, remote);
    expect(merged.length, 1);
    expect(merged.first['title'], 'new');
  });

  test('merge keeps local when local is newer', () {
    final local = [row(1, 'mine', '2026-11-09T10:00:00')];
    final remote = [row(1, 'theirs', '2026-11-05T10:00:00')];
    expect(mergeRows(local, remote).first['title'], 'mine');
  });

  test('merge unions records that exist on only one side', () {
    final merged = mergeRows(
      [row(1, 'a', '2026-11-01T10:00:00')],
      [row(2, 'b', '2026-11-01T10:00:00')],
    );
    expect(merged.length, 2);
  });
}
