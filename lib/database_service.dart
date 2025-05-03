import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  final FirebaseDatabase _db;

  DatabaseService({ FirebaseDatabase? database })
      : _db = database ?? FirebaseDatabase.instance {
    _db.setPersistenceEnabled(true);
    _db.setPersistenceCacheSizeBytes(10 * 1024 * 1024);
  }

  Future<String> create({
    required String path,
    required Map<String, dynamic> data,
    bool generateKey = false,
  }) async {
    try {
      DatabaseReference ref = _db.ref(path);
      if (generateKey) {
        ref = ref.push();
      }
      await ref.set(data);
      return ref.key!;
    } catch (e) {
      // You can log here or wrap in a custom exception
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> read({ required String path }) async {
    try {
      final snapshot = await _db.ref(path).get();
      if (!snapshot.exists || snapshot.value == null) return null;
      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      rethrow;
    }
  }

  Stream<DatabaseEvent> subscribe(String path) {
    return _db.ref(path).onValue;
  }

  Future<void> update({
    required String path,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _db.ref(path).update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> delete({ required String path }) async {
    try {
      await _db.ref(path).remove();
    } catch (e) {
      rethrow;
    }
  }
}