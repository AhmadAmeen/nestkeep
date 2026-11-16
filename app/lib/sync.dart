import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'db.dart';
import 'models.dart';

/// Optional account: Google sign-in only. Guest mode is the full app; the
/// account adds backup + sync. Sync mirrors the local SQLite rows into
/// users/{uid}/... and merges last-write-wins per record (updatedAt).
/// Pure merge helper is unit-tested.
List<Map<String, Object?>> mergeRows(
  List<Map<String, Object?>> local,
  List<Map<String, Object?>> remote,
) {
  final byId = <Object, Map<String, Object?>>{};
  for (final r in local) {
    byId[r['id']!] = r;
  }
  for (final r in remote) {
    final id = r['id']!;
    final existing = byId[id];
    if (existing == null) {
      byId[id] = r;
    } else {
      final lt = DateTime.parse(existing['updatedAt'] as String);
      final rt = DateTime.parse(r['updatedAt'] as String);
      if (rt.isAfter(lt)) byId[id] = r;
    }
  }
  return byId.values.toList();
}

class SyncService {
  static User? get user => FirebaseAuth.instance.currentUser;
  static bool get signedIn => user != null;

  static Future<User?> signInWithGoogle() async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize();
    final account = await signIn.authenticate();
    final auth = account.authentication;
    final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    await syncNow();
    return result.user;
  }

  static Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  static CollectionReference<Map<String, dynamic>> _col(String name) =>
      FirebaseFirestore.instance.collection('users/${user!.uid}/$name');

  static Map<String, dynamic> _clean(Map<String, Object?> m) =>
      m.map((k, v) => MapEntry(k, v));

  /// Push local, pull remote, merge, write merged set back to both sides.
  static Future<void> syncNow() async {
    if (!signedIn) return;
    final db = await AppDb.open();

    Future<void> syncTable(
      String table,
      String collection,
      Map<String, Object?> Function(Map<String, Object?>) toRow,
    ) async {
      final localRows = await db.query(table);
      final snap = await _col(collection).get();
      final remoteRows = snap.docs.map((d) => d.data()).toList();
      final merged = mergeRows(
        localRows.map((r) => Map<String, Object?>.from(r)).toList(),
        remoteRows.map((r) => Map<String, Object?>.from(r)).toList(),
      );
      final batch = FirebaseFirestore.instance.batch();
      for (final row in merged) {
        final clean = toRow(row);
        batch.set(_col(collection).doc('${clean['id']}'), _clean(clean));
        await db.insert(table, clean,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit();
    }

    await syncTable('homes', 'homes', (r) => r);
    await syncTable('task_instances', 'tasks', (r) => r);
    await syncTable('appliances', 'appliances', (r) => r);
    await syncTable('expenses', 'expenses', (r) => r);
    // Receipts carry a JSON items string locally and in Firestore alike.
    await syncTable('receipts', 'receipts', (r) => r);
  }

  /// Pro: store a compressed copy of a receipt image in Firestore
  /// (max width 1200px, JPEG ~65, target <= 400 KB; doc limit 1 MiB).
  static Future<bool> syncReceiptImage(Receipt r) async {
    if (!signedIn || r.imagePath == null) return false;
    final file = File(r.imagePath!);
    if (!await file.exists()) return false;
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return false;
    var resized = decoded;
    if (decoded.width > 1200) {
      resized = img.copyResize(decoded, width: 1200);
    }
    var quality = 65;
    var jpg = img.encodeJpg(resized, quality: quality);
    while (jpg.length > 400 * 1024 && quality > 30) {
      quality -= 10;
      jpg = img.encodeJpg(resized, quality: quality);
    }
    await _col('receiptImages').doc('${r.id}').set({
      'base64': base64Encode(jpg),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return true;
  }

  /// Fetch a synced receipt image back to this phone (new phone restore).
  static Future<String?> fetchReceiptImage(int receiptId) async {
    if (!signedIn) return null;
    final doc = await _col('receiptImages').doc('$receiptId').get();
    final b64 = doc.data()?['base64'] as String?;
    if (b64 == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'receipt_$receiptId.jpg');
    await File(path).writeAsBytes(base64Decode(b64));
    return path;
  }

  /// Full account deletion: Firestore subtree + Auth user. Local data is
  /// kept unless the caller wipes it separately (the UI offers both).
  static Future<void> deleteAccount() async {
    if (!signedIn) return;
    final uid = user!.uid;
    for (final name in [
      'homes', 'tasks', 'appliances', 'expenses', 'receipts', 'receiptImages'
    ]) {
      final snap =
          await FirebaseFirestore.instance.collection('users/$uid/$name').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await user!.delete();
    await signOut();
  }
}
