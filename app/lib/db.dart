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
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        // v2 (build 5): completion details, appliance notes, and the
        // contractor book, home notes and belongings tables. Purely
        // additive: existing rows keep working untouched.
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE task_instances ADD COLUMN doneBy TEXT');
          await db.execute(
              'ALTER TABLE task_instances ADD COLUMN doneNote TEXT');
          await db.execute('ALTER TABLE appliances ADD COLUMN notes TEXT');
          await _createV2Tables(db);
        }
        // v3 (build 9): appliance expected lifespan, and the table for
        // photos and invoices attached to an appliance. Additive again.
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE appliances ADD COLUMN lifespanYears INTEGER');
          await _createV3Tables(db);
        }
      },
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
            doneBy TEXT,
            doneNote TEXT,
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
            lifespanYears INTEGER,
            store TEXT,
            price REAL,
            receiptId INTEGER,
            imagePath TEXT,
            imageSynced INTEGER NOT NULL DEFAULT 0,
            notes TEXT,
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
        await _createV2Tables(db);
        await _createV3Tables(db);
      },
    );
    return _db!;
  }

  static Future<void> _createV3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS appliance_files(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        applianceId INTEGER NOT NULL,
        path TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )''');
  }

  static Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contractors(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        homeId INTEGER NOT NULL,
        name TEXT NOT NULL,
        trade TEXT NOT NULL,
        phone TEXT,
        notes TEXT,
        updatedAt TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS home_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        homeId INTEGER NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS belongings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        homeId INTEGER NOT NULL,
        name TEXT NOT NULL,
        room TEXT NOT NULL,
        value REAL NOT NULL DEFAULT 0,
        updatedAt TEXT NOT NULL
      )''');
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
    await db.execute(
        'DELETE FROM appliance_files WHERE applianceId IN '
        '(SELECT id FROM appliances WHERE homeId = ?)',
        [id]);
    await db.delete('appliances', where: 'homeId = ?', whereArgs: [id]);
    await db.delete('receipts', where: 'homeId = ?', whereArgs: [id]);
    await db.delete('expenses', where: 'homeId = ?', whereArgs: [id]);
    await db.delete('contractors', where: 'homeId = ?', whereArgs: [id]);
    await db.delete('home_notes', where: 'homeId = ?', whereArgs: [id]);
    await db.delete('belongings', where: 'homeId = ?', whereArgs: [id]);
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
    await db.delete('appliance_files',
        where: 'applianceId = ?', whereArgs: [id]);
    await db.delete('appliances', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- appliance files (photos + invoices, Pro, local only) ----------
  static Future<int> insertApplianceFile(ApplianceFile f) async {
    final db = await open();
    final map = f.toMap()..remove('id');
    return db.insert('appliance_files', map);
  }

  static Future<List<ApplianceFile>> filesForAppliance(int applianceId) async {
    final db = await open();
    final rows = await db.query(
      'appliance_files',
      where: 'applianceId = ?',
      whereArgs: [applianceId],
      orderBy: 'createdAt',
    );
    return rows.map(ApplianceFile.fromMap).toList();
  }

  static Future<void> deleteApplianceFile(int id) async {
    final db = await open();
    await db.delete('appliance_files', where: 'id = ?', whereArgs: [id]);
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

  // ---------- contractors ----------
  static Future<int> insertContractor(Contractor c) async {
    final db = await open();
    final map = c.toMap()..remove('id');
    return db.insert('contractors', map);
  }

  static Future<List<Contractor>> contractorsForHome(int homeId) async {
    final db = await open();
    final rows = await db.query(
      'contractors',
      where: 'homeId = ?',
      whereArgs: [homeId],
      orderBy: 'name',
    );
    return rows.map(Contractor.fromMap).toList();
  }

  static Future<void> updateContractor(Contractor c) async {
    final db = await open();
    await db.update('contractors', c.toMap(),
        where: 'id = ?', whereArgs: [c.id]);
  }

  static Future<void> deleteContractor(int id) async {
    final db = await open();
    await db.delete('contractors', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- home notes ----------
  static Future<int> insertHomeNote(HomeNote n) async {
    final db = await open();
    final map = n.toMap()..remove('id');
    return db.insert('home_notes', map);
  }

  static Future<List<HomeNote>> homeNotesForHome(int homeId) async {
    final db = await open();
    final rows = await db.query(
      'home_notes',
      where: 'homeId = ?',
      whereArgs: [homeId],
      orderBy: 'updatedAt DESC',
    );
    return rows.map(HomeNote.fromMap).toList();
  }

  static Future<void> updateHomeNote(HomeNote n) async {
    final db = await open();
    await db.update('home_notes', n.toMap(),
        where: 'id = ?', whereArgs: [n.id]);
  }

  static Future<void> deleteHomeNote(int id) async {
    final db = await open();
    await db.delete('home_notes', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- belongings ----------
  static Future<int> insertBelonging(Belonging b) async {
    final db = await open();
    final map = b.toMap()..remove('id');
    return db.insert('belongings', map);
  }

  static Future<List<Belonging>> belongingsForHome(int homeId) async {
    final db = await open();
    final rows = await db.query(
      'belongings',
      where: 'homeId = ?',
      whereArgs: [homeId],
      orderBy: 'name',
    );
    return rows.map(Belonging.fromMap).toList();
  }

  static Future<void> updateBelonging(Belonging b) async {
    final db = await open();
    await db.update('belongings', b.toMap(),
        where: 'id = ?', whereArgs: [b.id]);
  }

  static Future<void> deleteBelonging(int id) async {
    final db = await open();
    await db.delete('belongings', where: 'id = ?', whereArgs: [id]);
  }

  /// Wipe everything (used by in-app account deletion when the user also
  /// chooses to clear this phone).
  static Future<void> wipeAll() async {
    final db = await open();
    await db.delete('task_instances');
    await db.delete('appliance_files');
    await db.delete('appliances');
    await db.delete('receipts');
    await db.delete('expenses');
    await db.delete('contractors');
    await db.delete('home_notes');
    await db.delete('belongings');
    await db.delete('homes');
    await db.delete('settings');
  }
}
