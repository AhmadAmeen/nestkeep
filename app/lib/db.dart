import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Local-first storage. The phone is the source of truth; Firestore (when the
/// user creates the optional account) is a mirror of these same rows.
class AppDb {
  static Database? _db;

  static Future<Database> open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'nestkeep.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE homes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            addressLine TEXT NOT NULL,
            type TEXT NOT NULL,
            yearBuilt INTEGER NOT NULL,
            sqft INTEGER,
            updatedAt TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE task_instances(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            homeId INTEGER NOT NULL,
            templateId TEXT,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            dueDate TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'upcoming',
            doneDate TEXT,
            costPaid REAL,
            updatedAt TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE appliances(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            homeId INTEGER NOT NULL,
            name TEXT NOT NULL,
            brand TEXT,
            model TEXT,
            serial TEXT,
            purchaseDate TEXT,
            warrantyMonths INTEGER NOT NULL DEFAULT 12,
            store TEXT,
            price REAL,
            receiptId INTEGER,
            imagePath TEXT,
            imageSynced INTEGER NOT NULL DEFAULT 0,
            updatedAt TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE receipts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            homeId INTEGER NOT NULL,
            store TEXT NOT NULL,
            date TEXT NOT NULL,
            total REAL NOT NULL,
            items TEXT NOT NULL DEFAULT '[]',
            imagePath TEXT,
            imageSynced INTEGER NOT NULL DEFAULT 0,
            updatedAt TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            homeId INTEGER NOT NULL,
            date TEXT NOT NULL,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            taskId INTEGER,
            applianceId INTEGER,
            note TEXT,
            updatedAt TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT
          )''');
      },
    );
    return _db!;
  }

  // ---------- settings ----------
  static Future<String?> getSetting(String key) async {
    final db = await open();
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  static Future<void> setSetting(String key, String? value) async {
    final db = await open();
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- homes ----------
  static Future<int> insertHome(Home h) async {
    final db = await open();
    final map = h.toMap()..remove('id');
    return db.insert('homes', map);
  }

  static Future<List<Home>> homes() async {
    final db = await open();
    final rows = await db.query('homes', orderBy: 'id');
    return rows.map(Home.fromMap).toList();
  }

  static Future<void> deleteHome(int id) async {
    final db = await open();
    await db.delete('task_instances', where: 'homeId = ?', whereArgs: [id]);
    await db.delete('appliances', where: 'homeId = ?', whereArgs: [id]);
    await db.delete('receipts', where: 'homeId = ?', whereArgs: [id]);
    await db.delete('expenses', where: 'homeId = ?', whereArgs: [id]);
    await db.delete('homes', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- tasks ----------
  static Future<int> insertTask(TaskInstance t) async {
    final db = await open();
    final map = t.toMap()..remove('id');
    return db.insert('task_instances', map);
  }

  static Future<List<TaskInstance>> tasksForHome(int homeId) async {
    final db = await open();
    final rows = await db.query(
      'task_instances',
      where: 'homeId = ?',
      whereArgs: [homeId],
      orderBy: 'dueDate',
    );
    return rows.map(TaskInstance.fromMap).toList();
  }

  static Future<void> updateTask(TaskInstance t) async {
    final db = await open();
    await db.update('task_instances', t.toMap(),
        where: 'id = ?', whereArgs: [t.id]);
  }

  static Future<void> deleteTask(int id) async {
    final db = await open();
    await db.delete('task_instances', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- appliances ----------
  static Future<int> insertAppliance(Appliance a) async {
    final db = await open();
    final map = a.toMap()..remove('id');
    return db.insert('appliances', map);
  }

  static Future<List<Appliance>> appliancesForHome(int homeId) async {
    final db = await open();
    final rows = await db.query(
      'appliances',
      where: 'homeId = ?',
      whereArgs: [homeId],
      orderBy: 'name',
    );
    return rows.map(Appliance.fromMap).toList();
  }

  static Future<void> updateAppliance(Appliance a) async {
    final db = await open();
    await db.update('appliances', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  }

  static Future<void> deleteAppliance(int id) async {
    final db = await open();
    await db.delete('appliances', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- receipts ----------
  static Future<int> insertReceipt(Receipt r) async {
    final db = await open();
    return db.insert('receipts', {
      'homeId': r.homeId,
      'store': r.store,
      'date': isoDate(r.date),
      'total': r.total,
      'items': jsonEncode(r.items.map((e) => e.toMap()).toList()),
      'imagePath': r.imagePath,
      'imageSynced': r.imageSynced ? 1 : 0,
      'updatedAt': r.updatedAt.toIso8601String(),
    });
  }

  static Future<List<Receipt>> receiptsForHome(int homeId) async {
    final db = await open();
    final rows = await db.query(
      'receipts',
      where: 'homeId = ?',
      whereArgs: [homeId],
      orderBy: 'date DESC',
    );
    return rows
        .map((m) => Receipt(
              id: m['id'] as int?,
              homeId: m['homeId'] as int,
              store: m['store'] as String,
              date: parseDate(m['date'] as String),
              total: (m['total'] as num).toDouble(),
              items: (jsonDecode(m['items'] as String) as List)
                  .map((e) => ReceiptItem.fromMap(e as Map<String, dynamic>))
                  .toList(),
              imagePath: m['imagePath'] as String?,
              imageSynced: (m['imageSynced'] as int? ?? 0) == 1,
              updatedAt: DateTime.parse(m['updatedAt'] as String),
            ))
        .toList();
  }

  // ---------- expenses ----------
  static Future<int> insertExpense(Expense e) async {
    final db = await open();
    final map = e.toMap()..remove('id');
    return db.insert('expenses', map);
  }

  static Future<List<Expense>> expensesForHome(int homeId) async {
    final db = await open();
    final rows = await db.query(
      'expenses',
      where: 'homeId = ?',
      whereArgs: [homeId],
      orderBy: 'date DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  static Future<void> deleteExpense(int id) async {
    final db = await open();
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// Wipe everything (used by in-app account deletion when the user also
  /// chooses to clear this phone).
  static Future<void> wipeAll() async {
    final db = await open();
    await db.delete('task_instances');
    await db.delete('appliances');
    await db.delete('receipts');
    await db.delete('expenses');
    await db.delete('homes');
    await db.delete('settings');
  }
}
