import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:truthworld/data/models/offline.dart';

// ---- Web IndexedDB Database ----
Future<Database?> _getWebDatabase() async {
  try {
    final dbFactory = getIdbFactory();
    if (dbFactory == null) return null;
    return await dbFactory.open(
      'video_db',
      version: 1,
      onUpgradeNeeded: (e) {
        final db = e.database;
        if (!db.objectStoreNames.contains('videos')) {
          db.createObjectStore('videos');
        }
      },
    );
  } catch (e) {
    debugPrint('[database_helpers] Web database error: $e');
    return null;
  }
}

// ---- Native File Directory ----
Future<Directory> _getOfflineDir() async {
  final appDir = await getApplicationDocumentsDirectory();
  final offlineDir = Directory('${appDir.path}/offline_videos');
  if (!await offlineDir.exists()) {
    await offlineDir.create(recursive: true);
  }
  return offlineDir;
}

// ---- Public Cross-Platform APIs ----

Future<void> saveOfflineVideoBytes(
  String id,
  Uint8List bytes,
  OfflineVideo meta,
) async {
  if (kIsWeb) {
    final db = await _getWebDatabase();
    if (db == null) return;
    final txn = db.transaction('videos', 'readwrite');
    final store = txn.objectStore('videos');
    await store.put({'meta': meta.toJson(), 'bytes': bytes}, id);
    await txn.completed;
  } else {
    final dir = await _getOfflineDir();
    final metaFile = File('${dir.path}/$id.json');
    final videoFile = File('${dir.path}/$id.mp4');

    await metaFile.writeAsString(jsonEncode(meta.toJson()));
    if (bytes.isNotEmpty) {
      await videoFile.writeAsBytes(bytes);
    }
  }
}

Future<List<Map<String, dynamic>>> getAllVideosData() async {
  if (kIsWeb) {
    final db = await _getWebDatabase();
    if (db == null) return [];
    final txn = db.transaction('videos', 'readonly');
    final store = txn.objectStore('videos');
    final result = await store.getAll();
    await txn.completed;
    return List<Map<String, dynamic>>.from(result);
  } else {
    final dir = await _getOfflineDir();
    final results = <Map<String, dynamic>>[];
    final entities = await dir.list().toList();

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final metaJson = jsonDecode(content) as Map<String, dynamic>;
          results.add({'meta': metaJson});
        } catch (e) {
          debugPrint(
            '[database_helpers] Error reading meta file ${entity.path}: $e',
          );
        }
      }
    }
    return results;
  }
}

Future<void> deleteVideo(String id) async {
  if (kIsWeb) {
    final db = await _getWebDatabase();
    if (db == null) return;
    final txn = db.transaction('videos', 'readwrite');
    await txn.objectStore('videos').delete(id);
    await txn.completed;
  } else {
    final dir = await _getOfflineDir();
    final metaFile = File('${dir.path}/$id.json');
    final videoFile = File('${dir.path}/$id.mp4');

    if (await metaFile.exists()) {
      await metaFile.delete();
    }
    if (await videoFile.exists()) {
      await videoFile.delete();
    }
  }
}

Future<Uint8List?> getVideoBytes(String id) async {
  if (kIsWeb) {
    final db = await _getWebDatabase();
    if (db == null) return null;
    final txn = db.transaction('videos', 'readonly');
    final store = txn.objectStore('videos');
    final data = await store.getObject(id) as Map?;
    await txn.completed;
    if (data == null || data['bytes'] == null) return null;
    return Uint8List.fromList(List<int>.from(data['bytes']));
  } else {
    final dir = await _getOfflineDir();
    final videoFile = File('${dir.path}/$id.mp4');
    if (await videoFile.exists()) {
      return videoFile.readAsBytes();
    }
    return null;
  }
}

Future<String?> getVideoFilePath(String id) async {
  if (kIsWeb) return null;
  final dir = await _getOfflineDir();
  final videoFile = File('${dir.path}/$id.mp4');
  if (await videoFile.exists()) {
    return videoFile.path;
  }
  return null;
}
