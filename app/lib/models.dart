/// Plain data classes for NestKeep. Every row maps 1:1 to a SQLite table and
/// to a Firestore document under users/{uid}/... with the same field names.

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDate(String s) => DateTime.parse(s);

class Home {
  final int? id;
  final String name;
  final String addressLine;
  final String type; // house, townhouse, condo, apartment
  final int yearBuilt;
  final int? sqft;
  final DateTime updatedAt;

  Home({
    this.id,
    required this.name,
    required this.addressLine,
    required this.type,
    required this.yearBuilt,
    this.sqft,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'addressLine': addressLine,
        'type': type,
        'yearBuilt': yearBuilt,
        'sqft': sqft,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Home.fromMap(Map<String, Object?> m) => Home(
        id: m['id'] as int?,
        name: m['name'] as String,
        addressLine: m['addressLine'] as String,
        type: m['type'] as String,
        yearBuilt: m['yearBuilt'] as int,
        sqft: m['sqft'] as int?,
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );
}

class TaskTemplate {
  final String id;
  final String category;
  final String title;
  final int frequencyMonths;
  final List<String> seasons;
  final int diyCost;
  final int ignoreCost;
  final String difficulty; // Easy, Medium, Hard, Pro
  final int minutes;
  final String why;
  final List<String> steps;
  final List<String> needs;
  // Which homes this applies to, matched against onboarding answers.
  // Empty = applies to every home.
  final List<String> requiresAny;

  TaskTemplate({
    required this.id,
    required this.category,
    required this.title,
    required this.frequencyMonths,
    required this.seasons,
    required this.diyCost,
    required this.ignoreCost,
    required this.difficulty,
    required this.minutes,
    required this.why,
    required this.steps,
    required this.needs,
    this.requiresAny = const [],
  });

  bool get isSafety => category == 'Safety';

  factory TaskTemplate.fromJson(Map<String, dynamic> j) => TaskTemplate(
        id: j['id'] as String,
        category: j['category'] as String,
        title: j['title'] as String,
        frequencyMonths: j['frequencyMonths'] as int,
        seasons: (j['seasons'] as List).cast<String>(),
        diyCost: j['diyCost'] as int,
        ignoreCost: j['ignoreCost'] as int,
        difficulty: j['difficulty'] as String,
        minutes: j['minutes'] as int,
        why: j['why'] as String,
        steps: (j['steps'] as List).cast<String>(),
        needs: (j['needs'] as List).cast<String>(),
        requiresAny: ((j['requiresAny'] as List?) ?? const []).cast<String>(),
      );
}

enum TaskStatus { upcoming, done, skipped }

class TaskInstance {
  final int? id;
  final int homeId;
  final String? templateId; // null for custom tasks
  final String title;
  final String category;
  final DateTime dueDate;
  final TaskStatus status;
  final DateTime? doneDate;
  final double? costPaid;
  final String? doneBy; // who did it: "Me", a household member, or a pro
  final String? doneNote; // free note left when the job was completed
  final DateTime updatedAt;

  TaskInstance({
    this.id,
    required this.homeId,
    this.templateId,
    required this.title,
    required this.category,
    required this.dueDate,
    this.status = TaskStatus.upcoming,
    this.doneDate,
    this.costPaid,
    this.doneBy,
    this.doneNote,
    required this.updatedAt,
  });

  bool isOverdue(DateTime now) =>
      status == TaskStatus.upcoming &&
      dueDate.isBefore(DateTime(now.year, now.month, now.day));

  int daysOverdue(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today.difference(due).inDays;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'homeId': homeId,
        'templateId': templateId,
        'title': title,
        'category': category,
        'dueDate': isoDate(dueDate),
        'status': status.name,
        'doneDate': doneDate == null ? null : isoDate(doneDate!),
        'costPaid': costPaid,
        'doneBy': doneBy,
        'doneNote': doneNote,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TaskInstance.fromMap(Map<String, Object?> m) => TaskInstance(
        id: m['id'] as int?,
        homeId: m['homeId'] as int,
        templateId: m['templateId'] as String?,
        title: m['title'] as String,
        category: m['category'] as String,
        dueDate: parseDate(m['dueDate'] as String),
        status: TaskStatus.values.byName(m['status'] as String),
        doneDate: m['doneDate'] == null ? null : parseDate(m['doneDate'] as String),
        costPaid: (m['costPaid'] as num?)?.toDouble(),
        doneBy: m['doneBy'] as String?,
        doneNote: m['doneNote'] as String?,
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );

  TaskInstance copyWith({
    TaskStatus? status,
    DateTime? doneDate,
    double? costPaid,
    String? doneBy,
    String? doneNote,
    DateTime? dueDate,
    DateTime? updatedAt,
  }) =>
      TaskInstance(
        id: id,
        homeId: homeId,
        templateId: templateId,
        title: title,
        category: category,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        doneDate: doneDate ?? this.doneDate,
        costPaid: costPaid ?? this.costPaid,
        doneBy: doneBy ?? this.doneBy,
        doneNote: doneNote ?? this.doneNote,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Appliance {
  final int? id;
  final int homeId;
  final String name;
  final String? brand;
  final String? model;
  final String? serial;
  final DateTime? purchaseDate;
  final int warrantyMonths;
  final int? lifespanYears; // expected working life; null = use the typical value
  final String? store;
  final double? price;
  final int? receiptId;
  final String? imagePath; // local device path, may be null
  final bool imageSynced;
  final String? notes; // filter sizes, manual info, quirks
  // The owner's own call on the machine's condition, set from the
  // card or the detail screen: 'excellent' | 'good' | 'bad' |
  // 'worn_out', or null when they have not set one. Separate from the
  // computed life bands in lifespan.dart: age maths vs owner's eyes.
  final String? condition;
  final DateTime updatedAt;

  Appliance({
    this.id,
    required this.homeId,
    required this.name,
    this.brand,
    this.model,
    this.serial,
    this.purchaseDate,
    required this.warrantyMonths,
    this.lifespanYears,
    this.store,
    this.price,
    this.receiptId,
    this.imagePath,
    this.imageSynced = false,
    this.notes,
    this.condition,
    required this.updatedAt,
  });

  DateTime? get warrantyEnd => purchaseDate == null
      ? null
      : DateTime(purchaseDate!.year, purchaseDate!.month + warrantyMonths,
          purchaseDate!.day);

  Map<String, Object?> toMap() => {
        'id': id,
        'homeId': homeId,
        'name': name,
        'brand': brand,
        'model': model,
        'serial': serial,
        'purchaseDate': purchaseDate == null ? null : isoDate(purchaseDate!),
        'warrantyMonths': warrantyMonths,
        'lifespanYears': lifespanYears,
        'store': store,
        'price': price,
        'receiptId': receiptId,
        'imagePath': imagePath,
        'imageSynced': imageSynced ? 1 : 0,
        'notes': notes,
        'condition': condition,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Appliance.fromMap(Map<String, Object?> m) => Appliance(
        id: m['id'] as int?,
        homeId: m['homeId'] as int,
        name: m['name'] as String,
        brand: m['brand'] as String?,
        model: m['model'] as String?,
        serial: m['serial'] as String?,
        purchaseDate:
            m['purchaseDate'] == null ? null : parseDate(m['purchaseDate'] as String),
        warrantyMonths: m['warrantyMonths'] as int,
        lifespanYears: m['lifespanYears'] as int?,
        store: m['store'] as String?,
        price: (m['price'] as num?)?.toDouble(),
        receiptId: m['receiptId'] as int?,
        imagePath: m['imagePath'] as String?,
        imageSynced: (m['imageSynced'] as int? ?? 0) == 1,
        notes: m['notes'] as String?,
        condition: m['condition'] as String?,
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );

  Appliance copyWith({
    String? condition,
    bool clearCondition = false,
    DateTime? updatedAt,
  }) =>
      Appliance(
        id: id,
        homeId: homeId,
        name: name,
        brand: brand,
        model: model,
        serial: serial,
        purchaseDate: purchaseDate,
        warrantyMonths: warrantyMonths,
        lifespanYears: lifespanYears,
        store: store,
        price: price,
        receiptId: receiptId,
        imagePath: imagePath,
        imageSynced: imageSynced,
        notes: notes,
        condition: clearCondition ? null : (condition ?? this.condition),
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// A photo or invoice attached to one appliance (Pro). Files live in the
/// app's documents folder on this phone only: they are never synced, the
/// same rule as every other local file in the app.
class ApplianceFile {
  final int? id;
  final int applianceId;
  final String path;
  final DateTime createdAt;

  ApplianceFile({
    this.id,
    required this.applianceId,
    required this.path,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'applianceId': applianceId,
        'path': path,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory ApplianceFile.fromMap(Map<String, Object?> m) => ApplianceFile(
        id: m['id'] as int?,
        applianceId: m['applianceId'] as int,
        path: m['path'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );
}

/// A part of the home the user names: Kitchen, Bathroom, Garden…
/// Documents are filed under a space, or under the whole home.
/// Local only in v1 (see [HomeDoc]).
class HomeSpace {
  final int? id;
  final int homeId;
  final String name;
  final String icon; // a key into spaceIcons, not a code point
  final DateTime createdAt;
  final DateTime updatedAt;

  HomeSpace({
    this.id,
    required this.homeId,
    required this.name,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'homeId': homeId,
        'name': name,
        'icon': icon,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory HomeSpace.fromMap(Map<String, Object?> m) => HomeSpace(
        id: m['id'] as int?,
        homeId: m['homeId'] as int,
        name: m['name'] as String,
        icon: m['icon'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
      );

  HomeSpace copyWith({String? name, String? icon, DateTime? updatedAt}) =>
      HomeSpace(
        id: id,
        homeId: homeId,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// A photo of one of the home's papers: the deed, the insurance policy,
/// a manual page. A Pro feature. The file lives in the app's documents
/// folder on this phone only and is never synced, the same rule as
/// receipt photos and appliance attachments; the space it is filed
/// under stays local too, for the same reason.
class HomeDoc {
  final int? id;
  final int homeId;
  final int? spaceId; // null = filed under the whole home
  final String title;
  final String filePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  HomeDoc({
    this.id,
    required this.homeId,
    this.spaceId,
    required this.title,
    required this.filePath,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'homeId': homeId,
        'spaceId': spaceId,
        'title': title,
        'filePath': filePath,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory HomeDoc.fromMap(Map<String, Object?> m) => HomeDoc(
        id: m['id'] as int?,
        homeId: m['homeId'] as int,
        spaceId: m['spaceId'] as int?,
        title: m['title'] as String,
        filePath: m['filePath'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
      );

  HomeDoc copyWith({String? title, int? spaceId, bool clearSpace = false,
          DateTime? updatedAt}) =>
      HomeDoc(
        id: id,
        homeId: homeId,
        spaceId: clearSpace ? null : (spaceId ?? this.spaceId),
        title: title ?? this.title,
        filePath: filePath,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// A trusted pro the user calls: plumber, electrician, HVAC tech.
/// Pure local data, like everything else in the app.
class Contractor {
  final int? id;
  final int homeId;
  final String name;
  final String trade;
  final String? phone;
  final String? notes;
  final DateTime updatedAt;

  Contractor({
    this.id,
    required this.homeId,
    required this.name,
    required this.trade,
    this.phone,
    this.notes,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'homeId': homeId,
        'name': name,
        'trade': trade,
        'phone': phone,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Contractor.fromMap(Map<String, Object?> m) => Contractor(
        id: m['id'] as int?,
        homeId: m['homeId'] as int,
        name: m['name'] as String,
        trade: m['trade'] as String,
        phone: m['phone'] as String?,
        notes: m['notes'] as String?,
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );
}

/// A free-form note about the home: paint colours, part numbers, codes,
/// where things are. House Notes, kept simple.
class HomeNote {
  final int? id;
  final int homeId;
  final String title;
  final String body;
  final DateTime updatedAt;

  HomeNote({
    this.id,
    required this.homeId,
    required this.title,
    required this.body,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'homeId': homeId,
        'title': title,
        'body': body,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HomeNote.fromMap(Map<String, Object?> m) => HomeNote(
        id: m['id'] as int?,
        homeId: m['homeId'] as int,
        title: m['title'] as String,
        body: m['body'] as String,
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );
}

/// One belonging worth listing for insurance: name, room, honest value.
/// The light version, not a full inventory machine.
class Belonging {
  final int? id;
  final int homeId;
  final String name;
  final String room;
  final double value;
  final DateTime updatedAt;

  Belonging({
    this.id,
    required this.homeId,
    required this.name,
    required this.room,
    required this.value,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'homeId': homeId,
        'name': name,
        'room': room,
        'value': value,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Belonging.fromMap(Map<String, Object?> m) => Belonging(
        id: m['id'] as int?,
        homeId: m['homeId'] as int,
        name: m['name'] as String,
        room: m['room'] as String,
        value: (m['value'] as num).toDouble(),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );
}

class ReceiptItem {
  final String name;
  final double? price;
  ReceiptItem(this.name, this.price);

  Map<String, Object?> toMap() => {'name': name, 'price': price};
  factory ReceiptItem.fromMap(Map<String, dynamic> m) =>
      ReceiptItem(m['name'] as String, (m['price'] as num?)?.toDouble());
}

class Receipt {
  final int? id;
  final int homeId;
  final String store;
  final DateTime date;
  final double total;
  final List<ReceiptItem> items;
  final String? imagePath;
  final bool imageSynced;
  final DateTime updatedAt;

  Receipt({
    this.id,
    required this.homeId,
    required this.store,
    required this.date,
    required this.total,
    required this.items,
    this.imagePath,
    this.imageSynced = false,
    required this.updatedAt,
  });
}

class Expense {
  final int? id;
  final int homeId;
  final DateTime date;
  final double amount;
  final String category;
  final int? taskId;
  final int? applianceId;
  final String? note;
  final DateTime updatedAt;

  Expense({
    this.id,
    required this.homeId,
    required this.date,
    required this.amount,
    required this.category,
    this.taskId,
    this.applianceId,
    this.note,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'homeId': homeId,
        'date': isoDate(date),
        'amount': amount,
        'category': category,
        'taskId': taskId,
        'applianceId': applianceId,
        'note': note,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as int?,
        homeId: m['homeId'] as int,
        date: parseDate(m['date'] as String),
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String,
        taskId: m['taskId'] as int?,
        applianceId: m['applianceId'] as int?,
        note: m['note'] as String?,
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );
}

enum EntitlementSource { none, monthly, yearly, lifetime }

class Entitlement {
  final bool isPro;
  final EntitlementSource source;
  final DateTime? expiry;

  const Entitlement({this.isPro = false, this.source = EntitlementSource.none, this.expiry});

  static const free = Entitlement();
}

/// Typical warranty lengths in months, labelled in the UI as
/// "typical — check your paperwork". Keys are matched loosely against
/// appliance names.
const warrantyDefaultsMonths = <String, int>{
  'refrigerator': 12,
  'fridge': 12,
  'washer': 12,
  'washing machine': 12,
  'dryer': 12,
  'dishwasher': 12,
  'oven': 12,
  'range': 12,
  'stove': 12,
  'microwave': 12,
  'water heater': 72,
  'furnace': 120,
  'air conditioner': 120,
  'ac unit': 120,
  'hvac': 120,
  'garage door opener': 60,
  'television': 12,
  'tv': 12,
  'freezer': 12,
  'dehumidifier': 12,
  'air purifier': 12,
};

int typicalWarrantyMonths(String applianceName) {
  final n = applianceName.toLowerCase();
  for (final e in warrantyDefaultsMonths.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return 12; // small appliances default
}

/// A category the user added themselves (build 24, Pro to create).
/// Categories are global, not per home: the same list feeds the
/// expense form and the custom-job form on every home. Expenses and
/// jobs store their category as a plain string, so deleting one of
/// these never touches history — the name simply stops being
/// offered, and anything already filed under it keeps displaying
/// it. Synced like the other record tables (updatedAt is the ISO
/// string the sync merge compares, createdAt rides along as the
/// epoch int the local tables use).
class CustomCategory {
  final int? id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomCategory({
    this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CustomCategory.fromMap(Map<String, Object?> m) => CustomCategory(
        id: m['id'] as int?,
        name: m['name'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );
}
