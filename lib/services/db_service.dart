// Pengganti database.js
// Semua akses Realtime Database lewat sini, biar rapi dan satu pintu.

import 'package:firebase_database/firebase_database.dart';

class DbService {
  DbService._internal();
  static final DbService instance = DbService._internal();
  factory DbService() => instance;

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  DatabaseReference ref(String path) => _db.ref(path);

  Future<DataSnapshot> getOnce(String path) async {
    return await _db.ref(path).get();
  }

  Stream<DatabaseEvent> onValue(String path) {
    return _db.ref(path).onValue;
  }

  Future<void> set(String path, Map<String, dynamic> data) async {
    await _db.ref(path).set(data);
  }

  Future<void> update(String path, Map<String, dynamic> data) async {
    await _db.ref(path).update(data);
  }

  Future<void> remove(String path) async {
    await _db.ref(path).remove();
  }

  Future<void> push(String path, Map<String, dynamic> data) async {
    await _db.ref(path).push().set(data);
  }

  // FIX BUG #3: firebase_database ^10.x mengharapkan callback bertipe
  // Transaction Function(Object?) — bukan Object? Function(Object?).
  // Gunakan Transaction.success(data) untuk commit, Transaction.abort() untuk batal.
  Future<TransactionResult> runTransaction(
    String path,
    Transaction Function(Object? currentValue) update,
  ) async {
    return await _db.ref(path).runTransaction(update);
  }
}
