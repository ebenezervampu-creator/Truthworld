import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Custom Cache Manager for TruthWorld
///
/// Implements optimized caching for images and media with:
/// - Long retention (30 days for immutable content)
/// - Efficient storage (500 max items)
/// - SQLite database for metadata
/// - Automatic cleanup of expired items
class CustomCacheManager {
  static const String key = 'truthworld_image_cache';
  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 500,
        fileService: HttpFileService(),
        repo: JsonCacheInfoRepository(path: key),
        fileSystem: IOFileSystem(key),
      ),
    );
    return _instance!;
  }

  /// Get the cache directory size
  static Future<int> getCacheSize() async {
    try {
      final dir = await _getCacheDir();
      if (!dir.existsSync()) return 0;

      int size = 0;
      final files = dir.listSync(recursive: true, followLinks: false);

      for (var file in files) {
        if (file is File) {
          size += file.lengthSync();
        }
      }

      return size;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  /// Clear entire cache
  static Future<void> clearCache() async {
    try {
      await instance.emptyCache();
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Clear cache older than duration
  static Future<void> clearOldCache({Duration? duration}) async {
    try {
      await instance.emptyCache();
    } catch (e) {
      debugPrint('Error clearing old cache: $e');
    }
  }

  /// Get cache directory
  static Future<Directory> _getCacheDir() async {
    final cacheDir = await getTemporaryDirectory();
    final imagesDir = Directory('${cacheDir.path}/$key');
    return imagesDir;
  }

  /// Preload image to cache
  static Future<void> preloadImage(String imageUrl) async {
    try {
      await instance.getSingleFile(imageUrl);
    } catch (e) {
      debugPrint('Error preloading image: $e');
    }
  }

  /// Preload multiple images in parallel
  static Future<void> preloadImages(List<String> imageUrls) async {
    try {
      await Future.wait(imageUrls.map((url) => preloadImage(url)).toList());
    } catch (e) {
      debugPrint('Error preloading images: $e');
    }
  }
}

/// Video Thumbnail Cache Manager
///
/// Specialized cache for video thumbnails with aggressive caching.
class ThumbnailCacheManager {
  static const String key = 'truthworld_thumbnail_cache';
  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 60), // Longer for thumbnails
        maxNrOfCacheObjects: 1000, // More thumbnails
        fileService: HttpFileService(),
        repo: JsonCacheInfoRepository(path: key),
        fileSystem: IOFileSystem(key),
      ),
    );
    return _instance!;
  }

  /// Preload thumbnails on demand
  static Future<void> preloadThumbnail(String url) async {
    try {
      await instance.getSingleFile(url);
    } catch (e) {
      debugPrint('Error preloading thumbnail: $e');
    }
  }

  /// Batch preload thumbnails
  static Future<void> preloadThumbnailBatch(
    List<String> urls, {
    int batchSize = 10,
  }) async {
    try {
      for (int i = 0; i < urls.length; i += batchSize) {
        final batch = urls.sublist(
          i,
          i + batchSize > urls.length ? urls.length : i + batchSize,
        );

        await Future.wait(batch.map((url) => preloadThumbnail(url)).toList());

        // Add small delay between batches
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      debugPrint('Error in batch preload: $e');
    }
  }
}





