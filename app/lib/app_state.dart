import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'avatars.dart';
import 'badges.dart';
import 'db.dart';
import 'health.dart';
import 'local_images.dart';
import 'models.dart';
import 'plan.dart';
import 'pro_test_unlock.dart';
import 'theme.dart';

/// App-wide state, deliberately simple: one ChangeNotifier holding the
/// active home and its data, reloaded from SQLite after every mutation.
/// The phone's database is the source of truth; this is just its mirror
/// for the UI.
class AppState extends ChangeNotifier {
  List<TaskTemplate> templates = [];
  Map<String, TaskTemplate> templateById = {};
  List<Home> homes = [];
  Map<int, HomeProfile> profiles = {};
  Map<int, Set<String>> planSelections = {};
  Home? activeHome;

  HomeProfile? profileFor(int? homeId) =>
      homeId == null ? null : profiles[homeId];
  List<TaskInstance> tasks = [];
  List<Appliance> appliances = [];

  /// The first attached photo per appliance (appliance id -> local
  /// path), for the My Home card thumbnail. Attachments themselves
  /// stay loaded per-appliance by the detail screen; this is just the
  /// one path the card needs.
  Map<int, String> appliancePhotos = {};
  List<Expense> expenses = [];
  List<Receipt> receipts = [];
  List<Contractor> contractors = [];
  List<HomeNote> homeNotes = [];
  List<Belonging> belongings = [];
  List<HomeSpace> spaces = [];
  List<HomeDoc> docs = [];

  /// The user's own categories (build 24), in creation order.
  /// Global, not per home — one list feeds every category picker.
  /// Creating one is Pro; the list itself loads for everyone, so a
  /// lapsed Pro keeps seeing and using theirs.
  List<CustomCategory> customCategories = [];
  Entitlement entitlement = Entitlement.free;

  // PRO-TEST-UNLOCK (build 22, TEMPORARY): local test flag that makes
  // this phone read as Pro. See lib/pro_test_unlock.dart — remove
  // before the production release build.
  bool proTestMode = false;
  AppAccent accent = AppAccent.purple;
  AvatarDef currentAvatar = avatarById(null);

  /// The custom (own-photo) avatar's file in the documents folder, or
  /// null when the user has not added one (build 20). Local only.
  String? customAvatarPath;

  /// Home photos by home id (documents folder paths, build 20).
  /// Local only, never synced, like receipt photos.
  Map<int, String> homePhotos = {};

  bool get hasCustomAvatar => customAvatarPath != null;

  /// The stored custom photo as a file, when it is really there.
  File? get customAvatarFile {
    final path = customAvatarPath;
    if (path == null) return null;
    final f = File(path);
    return f.existsSync() ? f : null;
  }

  /// The avatar to draw: the custom def only counts while its photo
  /// exists; a missing photo falls back to the default house avatar.
  AvatarDef get displayAvatar =>
      currentAvatar.id == 'custom' && !hasCustomAvatar
          ? avatarById('house')
          : currentAvatar;

  /// A home's photo path, or null when it has none.
  String? homePhotoPath(int homeId) => homePhotos[homeId];

  /// The optional account, mirrored from Firebase Auth on init and on
  /// every reload (sign-in and sign-out both end in a reload). Guest
  /// mode is the default: false and null.
  bool signedIn = false;
  String? accountEmail;

  /// Badges earned but not yet celebrated, in celebration order.
  /// Filled by reload(); the Shell drains it one at a time via
  /// [consumeCelebration].
  List<BadgeResult> pendingCelebrations = [];
  bool loaded = false;

  bool get hasHome => activeHome != null;

  // PRO-TEST-UNLOCK: the test flag ORs in here — this getter is the
  // one read point every Pro check in the app goes through (paywall,
  // caps, locks, badges), so Pro behaviour follows it everywhere.
  bool get isPro => entitlement.isPro || proTestMode;

  Future<void> init() async {
    final raw = await rootBundle.loadString('assets/tasks.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    templates = (decoded['tasks'] as List)
        .map((e) => TaskTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
    templateById = {for (final t in templates) t.id: t};

    final savedEnt = await AppDb.getSetting('entitlement');
    if (savedEnt != null) {
      final m = jsonDecode(savedEnt) as Map<String, dynamic>;
      entitlement = Entitlement(
        isPro: m['isPro'] as bool? ?? false,
        source: EntitlementSource.values.byName(m['source'] as String? ?? 'none'),
        expiry: m['expiry'] == null ? null : DateTime.parse(m['expiry'] as String),
      );
      if (entitlement.expiry != null &&
          entitlement.expiry!.isBefore(DateTime.now()) &&
          entitlement.source != EntitlementSource.lifetime) {
        entitlement = Entitlement.free;
      }
    }

    // PRO-TEST-UNLOCK: restore the local test flag. It lives in the
    // settings table, which is never synced and never exported.
    proTestMode = await AppDb.getSetting(proTestModeSettingKey) == '1';

    _refreshAccount();

    final savedAccent = await AppDb.getSetting('accent');
    accent = parseAppAccent(savedAccent);

    currentAvatar = avatarById(await AppDb.getSetting('avatar'));

    customCategories = await AppDb.customCategories();

    homes = await AppDb.homes();
    for (final h in homes) {
      final p = await loadProfile(h.id!);
      if (p != null) profiles[h.id!] = p;
    }
    final activeId = await AppDb.getSetting('activeHomeId');
    if (homes.isNotEmpty) {
      activeHome = homes.firstWhere(
        (h) => h.id.toString() == activeId,
        orElse: () => homes.first,
      );
      await reload();
    }
    await _resolveLocalPhotos();
    loaded = true;
    notifyListeners();
  }

  /// Point at the local photo files that exist in the documents
  /// folder: the custom avatar and each home's photo (build 20).
  /// Files only — nothing here is read from or written to sync.
  Future<void> _resolveLocalPhotos() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final avatarFile = File(p.join(dir.path, customAvatarFileName));
      customAvatarPath = await avatarFile.exists() ? avatarFile.path : null;
      for (final h in homes) {
        if (h.id == null) continue;
        final f = File(p.join(dir.path, homePhotoFileName(h.id!)));
        if (await f.exists()) homePhotos[h.id!] = f.path;
      }
    } catch (_) {
      // No documents folder (tests, odd platforms): no local photos.
    }
  }

  /// Mirror the Firebase account into plain fields the UI and the
  /// badge tallies can read. Firebase may be unreachable or (in tests)
  /// uninitialised; both simply mean guest mode.
  void _refreshAccount() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      signedIn = user != null;
      accountEmail = user?.email;
    } catch (_) {
      signedIn = false;
      accountEmail = null;
    }
  }

  Future<void> reload() async {
    // Categories are global: refresh them even with no home yet.
    customCategories = await AppDb.customCategories();
    if (activeHome == null) return;
    _refreshAccount();
    final id = activeHome!.id!;
    if (!profiles.containsKey(id)) {
      final p = await loadProfile(id);
      if (p != null) profiles[id] = p;
    }
    tasks = await AppDb.tasksForHome(id);
    planSelections[id] =
        await loadPlanSelection(id) ?? derivedSelectionFromTasks(tasks);
    appliances = await AppDb.appliancesForHome(id);
    appliancePhotos = {};
    for (final a in appliances) {
      if (a.id == null) continue;
      final files = await AppDb.filesForAppliance(a.id!);
      if (files.isNotEmpty) appliancePhotos[a.id!] = files.first.path;
    }
    expenses = await AppDb.expensesForHome(id);
    receipts = await AppDb.receiptsForHome(id);
    contractors = await AppDb.contractorsForHome(id);
    homeNotes = await AppDb.homeNotesForHome(id);
    belongings = await AppDb.belongingsForHome(id);
    spaces = await AppDb.spacesForHome(id);
    docs = await AppDb.docsForHome(id);
    await _updateBadgeCelebrations();
    notifyListeners();
  }

  Future<void> setActiveHome(Home h) async {
    activeHome = h;
    await AppDb.setSetting('activeHomeId', h.id.toString());
    await reload();
  }

  /// Add one of the user's own categories (build 24). The Pro gate
  /// and the cap live in the picker, not here; this just writes and
  /// refreshes. Returns the stored row.
  Future<CustomCategory> addCustomCategory(String name) async {
    final now = DateTime.now();
    final id = await AppDb.insertCustomCategory(CustomCategory(
      name: name,
      createdAt: now,
      updatedAt: now,
    ));
    customCategories = await AppDb.customCategories();
    notifyListeners();
    return customCategories.firstWhere((c) => c.id == id);
  }

  /// Remove one of the user's own categories. Expenses and jobs
  /// that already use the name keep it as a plain string — only
  /// the pickers stop offering it.
  Future<void> removeCustomCategory(int id) async {
    await AppDb.deleteCustomCategory(id);
    customCategories = await AppDb.customCategories();
    notifyListeners();
  }

  /// The library jobs the user has ticked for a home, from the cache
  /// filled by reload(). For the active home before any reload, falls
  /// back to the templates already in its plan.
  Set<String> selectionFor(int homeId) =>
      planSelections[homeId] ??
      (homeId == activeHome?.id
          ? derivedSelectionFromTasks(tasks)
          : const <String>{});

  /// The ticked library jobs for any home, storage-checked: the saved
  /// selection when one exists, otherwise (homes planned before build
  /// 10) the templates that already have jobs in that home's plan.
  Future<Set<String>> selectedTemplateIds(int homeId) async {
    final stored = await loadPlanSelection(homeId);
    if (stored != null) return stored;
    if (planSelections.containsKey(homeId)) return planSelections[homeId]!;
    final homeTasks = homeId == activeHome?.id
        ? tasks
        : await AppDb.tasksForHome(homeId);
    return derivedSelectionFromTasks(homeTasks);
  }

  /// The badge shelf, from tallies of the records this home holds.
  /// On-time means finished on or before the due day; DIY means the
  /// finisher was the owner (doneBy empty or "Me", the done dialog's
  /// own wording), and a named finisher counts as a hired pro.
  List<BadgeResult> get currentBadges {
    final done = tasks.where((t) => t.status == TaskStatus.done).toList();
    bool diy(String? by) {
      final who = (by ?? '').trim().toLowerCase();
      return who.isEmpty || who == 'me';
    }

    bool onTime(TaskInstance t) {
      final d = t.doneDate;
      if (d == null) return false;
      return !DateTime(d.year, d.month, d.day)
          .isAfter(DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day));
    }

    int dayCompare(TaskInstance t) {
      final d = t.doneDate;
      if (d == null) return 0;
      return DateTime(d.year, d.month, d.day)
          .compareTo(DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day));
    }

    final donePerDay = <String, int>{};
    for (final t in done) {
      final d = t.doneDate;
      if (d == null) continue;
      final key = '${d.year}-${d.month}-${d.day}';
      donePerDay[key] = (donePerDay[key] ?? 0) + 1;
    }

    return computeBadges(BadgeTallies(
      doneCount: done.length,
      onTimeCount: done.where(onTime).length,
      earlyCount: done.where((t) => dayCompare(t) < 0).length,
      lateCount: done.where((t) => dayCompare(t) > 0).length,
      skippedCount:
          tasks.where((t) => t.status == TaskStatus.skipped).length,
      maxDoneInOneDay:
          donePerDay.values.fold(0, (a, b) => a > b ? a : b),
      diyCount: done.where((t) => diy(t.doneBy)).length,
      hiredProCount: done.where((t) => !diy(t.doneBy)).length,
      categoriesDone: done.map((t) => t.category).toSet().length,
      categoriesTotal: templates.map((t) => t.category).toSet().length,
      streakWeeks: streakWeeks,
      score: health.score,
      expensesCount: expenses.length,
      totalSpent: expenses.fold(0.0, (sum, e) => sum + e.amount),
      receiptsCount: receipts.length,
      receiptsWithPhoto:
          receipts.where((r) => r.imagePath != null).length,
      appliancesCount: appliances.length,
      appliancesWithPhoto: appliances
          .where((a) =>
              (a.id != null && appliancePhotos.containsKey(a.id)) ||
              a.imagePath != null)
          .length,
      appliancesWithCondition:
          appliances.where((a) => a.condition != null).length,
      appliancesWithWarranty: appliances
          .where((a) => a.purchaseDate != null && a.warrantyMonths > 0)
          .length,
      docsCount: docs.length,
      spacesCount: spaces.length,
      customJobsCount: tasks.where((t) => t.templateId == null).length,
      homesCount: homes.length,
      signedIn: signedIn,
      isPro: isPro,
      isLifetime: entitlement.source == EntitlementSource.lifetime,
    ));
  }

  HealthResult get health => computeHealth(tasks, templateById, DateTime.now());
  List<CategoryHealth> get healthByCategory =>
      computeHealthByCategory(tasks, templateById, DateTime.now());
  int get streakWeeks => computeStreakWeeks(tasks, DateTime.now());

  double get belongingsTotal =>
      belongings.fold(0.0, (sum, b) => sum + b.value);

  List<TaskInstance> get upcoming =>
      tasks.where((t) => t.status == TaskStatus.upcoming).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<TaskInstance> get overdue =>
      upcoming.where((t) => t.isOverdue(DateTime.now())).toList();

  List<TaskInstance> get actionNeeded => overdue;

  double get spentThisYear {
    final y = DateTime.now().year;
    return expenses
        .where((e) => e.date.year == y)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// The "typical" comparison for the Spent card: the plan's own DIY costs
  /// for a year, from the task library (an honest internal yardstick, not a
  /// made-up national statistic).
  double get typicalYearSpend {
    var total = 0.0;
    for (final t in tasks) {
      final tpl = t.templateId == null ? null : templateById[t.templateId];
      if (tpl != null && tpl.frequencyMonths > 0) {
        total += tpl.diyCost * (12 / tpl.frequencyMonths);
      }
    }
    return total;
  }

  /// Switch the app colour. Persisted, and the whole app (light and
  /// dark alike) repaints in the new accent. Custom colours are Pro
  /// (build 19); a custom colour already picked stays picked if Pro
  /// lapses — the Settings picker simply will not offer a change to
  /// another locked one, exactly like Pro avatars.
  Future<void> setAccent(AppAccent a) async {
    accent = a;
    await AppDb.setSetting('accent', a.name);
    notifyListeners();
  }

  Future<void> setEntitlement(Entitlement e) async {
    entitlement = e;
    await AppDb.setSetting(
      'entitlement',
      jsonEncode({
        'isPro': e.isPro,
        'source': e.source.name,
        'expiry': e.expiry?.toIso8601String(),
      }),
    );
    // A purchase or restore can earn the Pro member badge; billing
    // notifies through here rather than reload(), so check here too.
    await _updateBadgeCelebrations();
    notifyListeners();
  }

  /// PRO-TEST-UNLOCK (TEMPORARY, build 22): flip the local test flag.
  /// Purely local: persisted in the settings table, which is never
  /// synced and never exported, and the real [entitlement] is left
  /// untouched — turning this off returns the app to the real billing
  /// state immediately.
  Future<void> setProTestMode(bool on) async {
    proTestMode = on;
    await AppDb.setSetting(proTestModeSettingKey, on ? '1' : null);
    await _updateBadgeCelebrations();
    notifyListeners();
  }

  /// Badge celebrations. The first time this runs (the first reload on
  /// build 12+), whatever is already earned is recorded as celebrated
  /// without a show, so existing users never get a flood. After that,
  /// newly earned badges queue in [pendingCelebrations] and are marked
  /// celebrated immediately, so a crash cannot re-fire them.
  Future<void> _updateBadgeCelebrations() async {
    if (activeHome == null) return;
    final earned = currentBadges.where((b) => b.earned).toList();
    final raw = await AppDb.getSetting('celebrated_badges');
    if (raw == null) {
      await AppDb.setSetting(
        'celebrated_badges',
        jsonEncode([for (final b in earned) b.id]),
      );
      return;
    }
    final celebrated =
        (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    final fresh = newlyEarned([for (final b in earned) b.id], celebrated);
    if (fresh.isEmpty) return;
    pendingCelebrations = [
      ...pendingCelebrations,
      for (final id in fresh) earned.firstWhere((b) => b.id == id),
    ];
    await AppDb.setSetting(
      'celebrated_badges',
      jsonEncode([...celebrated, ...fresh]),
    );
  }

  /// The Shell calls this once a celebration has been shown.
  void consumeCelebration(String id) {
    pendingCelebrations =
        pendingCelebrations.where((b) => b.id != id).toList();
    notifyListeners();
  }

  /// Switch the user's avatar. Persisted, like the accent. A Pro-only
  /// avatar already picked stays picked if Pro lapses; the picker in
  /// Profile simply will not offer a change to another locked one.
  Future<void> setAvatar(AvatarDef a) async {
    currentAvatar = a;
    await AppDb.setSetting('avatar', a.id);
    notifyListeners();
  }

  /// Save a picked photo as the custom avatar (build 20, Pro): the
  /// picture is center-cropped square and downscaled into the
  /// documents folder, then selected. Local only, never synced.
  /// Returns false when the photo could not be processed.
  Future<bool> setCustomAvatarFromPicked(String pickedPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = p.join(dir.path, customAvatarFileName);
      if (!await writeSquareAvatar(pickedPath, dest)) return false;
      customAvatarPath = dest;
      await setAvatar(customAvatarDef);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Remove the custom avatar photo. If it was the selected avatar,
  /// the default house avatar takes its place.
  Future<void> removeCustomAvatar() async {
    final path = customAvatarPath;
    customAvatarPath = null;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    if (currentAvatar.id == 'custom') {
      await setAvatar(avatarById('house'));
    } else {
      notifyListeners();
    }
  }

  /// Save a picked photo as a home's photo (build 20; adding one is
  /// Pro since build 21 — the gate lives in the photo flows, not
  /// here, and a photo already set stays if Pro lapses): downscaled
  /// into the documents folder as `home_photo_<homeId>.jpg`. Local
  /// only, never synced — only the home's facts sync, never this file.
  Future<bool> setHomePhoto(int homeId, String pickedPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = p.join(dir.path, homePhotoFileName(homeId));
      if (!await writeHomePhoto(pickedPath, dest)) return false;
      homePhotos[homeId] = dest;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Remove a home's photo (the file and the pointer; the home's
  /// facts are untouched).
  Future<void> removeHomePhoto(int homeId) async {
    final path = homePhotos.remove(homeId);
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    notifyListeners();
  }
}
