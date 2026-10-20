import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/local_playback_proxy.dart';
import 'package:truthworld/core/services/media_crypto_service.dart';
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
  } catch (e, s) {
    ErrorHandler.log(
      e,
      stackTrace: s,
      tag: 'database_helpers._getWebDatabase',
    );
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
  final metaMap = meta.toJson();
  metaMap['isEncrypted'] = true;

  if (kIsWeb) {
    final db = await _getWebDatabase();
    if (db == null) return;
    final txn = db.transaction('videos', 'readwrite');
    final store = txn.objectStore('videos');
    final existing = await store.getObject(id) as Map?;
    final bytes = existing != null ? existing['bytes'] : null;
    await store.put({'meta': metaMap, 'bytes': bytes}, id);
    await txn.completed;
  } else {
    final dir = await _getOfflineDir();
    final metaFile = File('${dir.path}/$id.json');
    await metaFile.writeAsString(jsonEncode(metaMap));
  }
}

/// Saves media file to offline storage, encrypting it with AES-256 CTR if not already encrypted.
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
    final targetEncryptedFile = File('${dir.path}/$id.twenc');

    // Check if the source file is already encrypted with TWENC header
    final isSourceEncrypted = await () async {
      try {
        final headerBytes = await mediaFile.openRead(0, MediaCryptoService.magicHeader.length).first;
        return MediaCryptoService.instance.isEncryptedMedia(headerBytes);
      } catch (_) {
        return false;
      }
    }();

    if (isSourceEncrypted) {
      if (mediaFile.path != targetEncryptedFile.path) {
        if (await targetEncryptedFile.exists()) {
          await targetEncryptedFile.delete();
        }
        await mediaFile.copy(targetEncryptedFile.path);
      }
    } else {
      // Encrypt unencrypted file into target .twenc
      final tempEncrypted = File('${dir.path}/$id.twenc.tmp');
      await MediaCryptoService.instance.encryptFile(
        mediaFile,
        tempEncrypted,
        isAudio: meta.isAudioOnly,
      );
      if (await targetEncryptedFile.exists()) {
        await targetEncryptedFile.delete();
      }
      await tempEncrypted.rename(targetEncryptedFile.path);

      // Remove source unencrypted file if in the offline dir
      if (mediaFile.path != targetEncryptedFile.path &&
          mediaFile.path.startsWith(dir.path) &&
          await mediaFile.exists()) {
        try {
          await mediaFile.delete();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'database_helpers.saveOfflineVideoFile.deleteSource',
          );
        }
      }
    }

    await saveOfflineVideoMetadata(id, meta);
  }
}

/// Saves media bytes to offline storage, encrypting them with AES-256 CTR before writing to disk/IndexedDB.
Future<void> saveOfflineVideoBytes(
  String id,
  Uint8List bytes,
  OfflineVideo meta,
) async {
  final crypto = MediaCryptoService.instance;
  final isAlreadyEncrypted = crypto.isEncryptedMedia(bytes);
  final encryptedBytes = isAlreadyEncrypted
      ? bytes
      : await crypto.encryptBytes(bytes, isAudio: meta.isAudioOnly);

  if (kIsWeb) {
    final db = await _getWebDatabase();
    if (db == null) return;
    final txn = db.transaction('videos', 'readwrite');
    final store = txn.objectStore('videos');
    final metaMap = meta.toJson();
    metaMap['isEncrypted'] = true;
    await store.put({'meta': metaMap, 'bytes': encryptedBytes}, id);
    await txn.completed;
  } else {
    final dir = await _getOfflineDir();
    final metaFile = File('${dir.path}/$id.json');
    final encryptedFile = File('${dir.path}/$id.twenc');

    final metaMap = meta.toJson();
    metaMap['isEncrypted'] = true;
    await metaFile.writeAsString(jsonEncode(metaMap));
    await encryptedFile.writeAsBytes(encryptedBytes);

    // Clean up any legacy unencrypted media files for this id
    for (final ext in ['mp4', 'mp3', 'm4a', 'aac']) {
      final legacy = File('${dir.path}/$id.$ext');
      if (await legacy.exists()) {
        try {
          await legacy.delete();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'database_helpers.saveOfflineVideoBytes.deleteLegacy',
          );
        }
      }
    }
  }
}

Future<List<Map<String, dynamic>>> getAllVideosData() async {
  if (kIsWeb) {
    try {
      final db = await _getWebDatabase();
      if (db == null) return [];
      final txn = db.transaction('videos', 'readonly');
      final store = txn.objectStore('videos');
      final result = await store.getAll();
      await txn.completed;

      final list = <Map<String, dynamic>>[];
      for (final item in result) {
        if (item is Map) {
          final itemMap = Map<String, dynamic>.from(item);
          if (itemMap['meta'] is Map) {
            itemMap['meta'] = Map<String, dynamic>.from(itemMap['meta'] as Map);
          }
          list.add(itemMap);
        }
      }
      return list;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'database_helpers.getAllVideosData.web',
      );
      return [];
    }
  } else {
    try {
      final dir = await _getOfflineDir();
      final results = <Map<String, dynamic>>[];
      final entities = await dir.list().toList();

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final metaJson = jsonDecode(content);
            if (metaJson is Map) {
              results.add({'meta': Map<String, dynamic>.from(metaJson)});
            }
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'database_helpers.getAllVideosData.item',
            );
          }
        }
      }
      return results;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'database_helpers.getAllVideosData.native',
      );
      return [];
    }
  }
}

Future<void> deleteVideo(String id) async {
  if (!kIsWeb) {
    LocalPlaybackProxyServer.instance.unregisterVideo(id);
  }

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

    final encFile = File('${dir.path}/$id.twenc');
    if (await encFile.exists()) {
      await encFile.delete();
    }

    for (final ext in ['mp4', 'mp3', 'm4a', 'aac', 'part', 'twenc.tmp']) {
      final mediaFile = File('${dir.path}/$id.$ext');
      if (await mediaFile.exists()) {
        await mediaFile.delete();
      }
    }
  }
}

/// Retrieves the decrypted bytes of an offline video.
/// On Web and Native, automatically decrypts TWENC payloads before returning.
Future<Uint8List?> getVideoBytes(String id) async {
  Uint8List? rawBytes;

  if (kIsWeb) {
    final db = await _getWebDatabase();
    if (db == null) return null;
    final txn = db.transaction('videos', 'readonly');
    final store = txn.objectStore('videos');
    final data = await store.getObject(id) as Map?;
    await txn.completed;
    if (data == null || data['bytes'] == null) return null;
    rawBytes = Uint8List.fromList(List<int>.from(data['bytes']));
  } else {
    final dir = await _getOfflineDir();
    final encFile = File('${dir.path}/$id.twenc');
    if (await encFile.exists()) {
      rawBytes = await encFile.readAsBytes();
    } else {
      for (final ext in ['mp4', 'mp3', 'm4a', 'aac']) {
        final mediaFile = File('${dir.path}/$id.$ext');
        if (await mediaFile.exists()) {
          rawBytes = await mediaFile.readAsBytes();
          break;
        }
      }
    }
  }

  if (rawBytes == null || rawBytes.isEmpty) return null;

  if (MediaCryptoService.instance.isEncryptedMedia(rawBytes)) {
    return MediaCryptoService.instance.decryptBytes(rawBytes);
  }

  return rawBytes;
}

/// Verifies that an encrypted .twenc file exists and is fully downloaded/written.
Future<bool> _isEncryptedFileComplete(File encFile) async {
  if (!await encFile.exists()) return false;
  final fileLen = await encFile.length();
  if (fileLen <= MediaCryptoService.headerSize) return false;
  try {
    final headerBytes = await encFile.openRead(0, MediaCryptoService.headerSize).first;
    if (!MediaCryptoService.instance.isEncryptedMedia(headerBytes)) return false;
    final header = MediaCryptoService.instance.parseHeader(headerBytes);
    return fileLen >= header.originalLength + MediaCryptoService.headerSize;
  } catch (_) {
    return false;
  }
}

/// Resolves a streaming loopback URL for offline video playback via LocalPlaybackProxyServer.
/// On native platforms, serves the encrypted file on-the-fly without writing unencrypted bytes to disk.
Future<String?> getOfflinePlaybackUrl(String id) async {
  if (kIsWeb) return null;

  final dir = await _getOfflineDir();
  final encFile = File('${dir.path}/$id.twenc');

  if (await _isEncryptedFileComplete(encFile)) {
    return LocalPlaybackProxyServer.instance.serveVideo(id, encFile);
  }

  // Check for legacy unencrypted file and transparently migrate to .twenc
  for (final ext in ['mp4', 'mp3', 'm4a', 'aac']) {
    final legacyFile = File('${dir.path}/$id.$ext');
    if (await legacyFile.exists() && (await legacyFile.length()) > 512) {
      debugPrint('[database_helpers] 🔄 Migrating legacy $ext download to encrypted .twenc');
      try {
        final isAudio = ext == 'mp3' || ext == 'm4a' || ext == 'aac';
        await MediaCryptoService.instance.encryptFile(
          legacyFile,
          encFile,
          isAudio: isAudio,
        );
        await legacyFile.delete();
        return LocalPlaybackProxyServer.instance.serveVideo(id, encFile);
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'database_helpers.getOfflinePlaybackUrl.migrateLegacy',
        );
        // Fallback: serve legacy directly
        return LocalPlaybackProxyServer.instance.serveVideo(id, legacyFile);
      }
    }
  }

  return null;
}

/// Returns the file path of an offline video.
/// Prefer [getOfflinePlaybackUrl] for secure on-the-fly decrypted streaming.
Future<String?> getVideoFilePath(String id) async {
  if (kIsWeb) return null;
  final dir = await _getOfflineDir();

  final encFile = File('${dir.path}/$id.twenc');
  if (await encFile.exists()) {
    return encFile.path;
  }

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
    final meta = data['meta'];
    if (meta is Map) {
      return OfflineVideo.fromJson(Map<String, dynamic>.from(meta));
    }
    return null;
  } else {
    final dir = await _getOfflineDir();
    final metaFile = File('${dir.path}/$id.json');
    if (await metaFile.exists()) {
      try {
        final content = await metaFile.readAsString();
        final metaJson = jsonDecode(content);
        if (metaJson is Map) {
          return OfflineVideo.fromJson(Map<String, dynamic>.from(metaJson));
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'database_helpers.getOfflineVideoMetadata',
        );
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

    final encFile = File('${dir.path}/$id.twenc');
    if (await _isEncryptedFileComplete(encFile)) {
      return true;
    }

    for (final ext in ['mp4', 'mp3', 'm4a', 'aac']) {
      final mediaFile = File('${dir.path}/$id.$ext');
      if (await mediaFile.exists() && (await mediaFile.length()) > 512) {
        return true;
      }
    }
    return false;
  }
}
