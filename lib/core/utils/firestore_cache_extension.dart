import 'package:cloud_firestore/cloud_firestore.dart';

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
      // Fallback on cache miss/error
    }
    try {
      return await get();
    } catch (_) {
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
      // Fallback on cache miss/error
    }
    try {
      return await get();
    } catch (_) {
      return get(const GetOptions(source: Source.cache));
    }
  }
}
