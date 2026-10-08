import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/errors/error_handler.dart';

extension DocumentReferenceCacheExtension<T> on DocumentReference<T> {
  /// Attempts to fetch the document from cache first to avoid Firestore read costs.
  /// If the cache fetch fails or does not exist, it falls back to server (with cache fallback).
  Future<DocumentSnapshot<T>> getCacheFirst() async {
    try {
      final cacheDoc = await get(const GetOptions(source: Source.cache));
      if (cacheDoc.exists && cacheDoc.data() != null) {
        return cacheDoc;
      }
    } catch (_) {
      // Expected cache miss when document is not yet stored in local client cache.
    }
    try {
      return await get();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DocumentReferenceCacheExtension.getCacheFirst.serverFallback',
      );
      return get(const GetOptions(source: Source.cache));
    }
  }
}

extension QueryCacheExtension<T> on Query<T> {
  /// Attempts to fetch the query results from cache first to avoid Firestore read costs.
  /// If the cache fetch fails or is empty, it falls back to server (with cache fallback).
  Future<QuerySnapshot<T>> getCacheFirst() async {
    try {
      final cacheQuery = await get(const GetOptions(source: Source.cache));
      if (cacheQuery.docs.isNotEmpty) {
        return cacheQuery;
      }
    } catch (_) {
      // Expected cache miss when query is not yet stored in local client cache.
    }
    try {
      return await get();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'QueryCacheExtension.getCacheFirst.serverFallback',
      );
      return get(const GetOptions(source: Source.cache));
    }
  }
}
