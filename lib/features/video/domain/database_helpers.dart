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

/// Public getter for offline storage directory on native platforms
Future<Directory> getOfflineDirectory() => _getOfflineDir();

// ---- Public Cross-Platform APIs ----

Future<void> saveOfflineVideoMetadata(
  String id,
  OfflineVideo meta,
) async {
  if (kIsWeb) {
    final db = await _getWebDatabase();
    if (db == null) return;
    final txn = db.transaction('videos', 'readwrite');
    final store = txn.objectStore('videos');
    final existing = await store.getObject(id) as Map?;
    final bytes = existing != null ? existing['bytes'] : null;
    await store.put({'meta': meta.toJson(), 'bytes': bytes}, id);
    await txn.completed;
  } else {
    final dir = await _getOfflineDir();
    final metaFile = File('${dir.path}/$id.json');
    await metaFile.writeAsString(jsonEncode(meta.toJson()));
  }
}

Future<void> saveOfflineVideoFile(
  String id,
  File mediaFile,
  OfflineVideo meta,
) async {
  if (kIsWeb) {
    final bytes = await mediaFile.readAsBytes();
    await saveOfflineVideoBytes(id, bytes, meta);
  } else {
    final dir = await _getOfflineDir();
    final ext = meta.isAudioOnly ? 'mp3' : 'mp4';
    final targetFile = File('${dir.path}/$id.$ext');
    if (mediaFile.path != targetFile.path) {
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await mediaFile.copy(targetFile.path);
    }
    await saveOfflineVideoMetadata(id, meta);
  }
}

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
    final ext = meta.isAudioOnly ? 'mp3' : 'mp4';
    final metaFile = File('${dir.path}/$id.json');
    final videoFile = File('${dir.path}/$id.$ext');

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
    if (await metaFile.exists()) {
      await metaFile.delete();
    }
    for (final ext in ['mp4', 'mp3', 'm4a', 'aac']) {
      final mediaFile = File('${dir.path}/$id.$ext');
      if (await mediaFile.exists()) {
        await mediaFile.delete();
      }
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
    for (final ext in ['mp4', 'mp3', 'm4a', 'aac']) {
      final mediaFile = File('${dir.path}/$id.$ext');
      if (await mediaFile.exists()) {
        return mediaFile.readAsBytes();
      }
    }
    return null;
  }
}

Future<String?> getVideoFilePath(String id) async {
  if (kIsWeb) return null;
  final dir = await _getOfflineDir();
  for (final ext in ['mp4', 'mp3', 'm4a', 'aac']) {
    final mediaFile = File('${dir.path}/$id.$ext');
    if (await mediaFile.exists()) {
      return mediaFile.path;
    }
  }
  return null;
}

Future<OfflineVideo?> getOfflineVideoMetadata(String id) async {
  if (kIsWeb) {
    final db = await _getWebDatabase();
    if (db == null) return null;
    final txn = db.transaction('videos', 'readonly');
    final store = txn.objectStore('videos');
    final data = await store.getObject(id) as Map?;
    await txn.completed;
    if (data == null || data['meta'] == null) return null;
    return OfflineVideo.fromJson(Map<String, dynamic>.from(data['meta']));
  } else {
    final dir = await _getOfflineDir();
    final metaFile = File('${dir.path}/$id.json');
    if (await metaFile.exists()) {
      try {
        final content = await metaFile.readAsString();
        final metaJson = jsonDecode(content) as Map<String, dynamic>;
        return OfflineVideo.fromJson(metaJson);
      } catch (e) {
        debugPrint('[database_helpers] Error reading meta for $id: $e');
      }
    }
    return null;
  }
}

Future<bool> hasOfflineVideo(String id) async {
  if (kIsWeb) {
    final db = await _getWebDatabase();
    if (db == null) return false;
    final txn = db.transaction('videos', 'readonly');
    final store = txn.objectStore('videos');
    final data = await store.getObject(id) as Map?;
    await txn.completed;
    return data != null && (data['bytes'] != null || data['meta'] != null);
  } else {
    final dir = await _getOfflineDir();
    for (final ext in ['mp4', 'mp3', 'm4a', 'aac']) {
      final mediaFile = File('${dir.path}/$id.$ext');
      if (await mediaFile.exists() && (await mediaFile.length()) > 512) {
        return true;
      }
    }
    return false;
  }
}

