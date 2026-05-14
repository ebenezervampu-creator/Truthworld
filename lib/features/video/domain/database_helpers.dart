import 'package:idb_shim/idb_browser.dart';
import 'dart:typed_data';
import 'package:truthworld/data/models/offline.dart';

// ----

Future<Database> getDatabase() async {
  final dbFactory = getIdbFactory()!;
  final db = await dbFactory.open(
    'video_db',
    version: 1,
    onUpgradeNeeded: (e) {
      final db = e.database;
      if (!db.objectStoreNames.contains('videos')) {
        db.createObjectStore('videos');
      }
    },
  );
  return db;
}

Future<void> saveOfflineVideoBytes(
  String id,
  Uint8List bytes,
  OfflineVideo meta,
) async {
  final db = await getDatabase();
  final txn = db.transaction('videos', 'readwrite');
  final store = txn.objectStore('videos');
  await store.put({'meta': meta.toJson(), 'bytes': bytes}, id);
  await txn.completed;
}

Future<List<Map<String, dynamic>>> getAllVideosData() async {
  final db = await getDatabase();
  final txn = db.transaction('videos', 'readonly');
  final store = txn.objectStore('videos');
  final result = await store.getAll(null);
  await txn.completed;
  return List<Map<String, dynamic>>.from(result);
}

Future<void> deleteVideo(String id) async {
  final db = await getDatabase();
  final txn = db.transaction('videos', 'readwrite');
  await txn.objectStore('videos').delete(id);
  await txn.completed;
}

Future<Uint8List?> getVideoBytes(String id) async {
  final db = await getDatabase();
  final txn = db.transaction('videos', 'readonly');
  final store = txn.objectStore('videos');
  final data = await store.getObject(id) as Map?;
  await txn.completed;
  if (data == null) return null;
  return Uint8List.fromList(List<int>.from(data['bytes']));
}





