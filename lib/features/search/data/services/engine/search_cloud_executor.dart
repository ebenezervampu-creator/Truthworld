import 'package:cloud_functions/cloud_functions.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';

/// Handles Cloud Function execution for server-side vector and hybrid search.
class SearchCloudExecutor {
  SearchCloudExecutor({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;

  /// Executes Cloud Function `searchTruthWorld` with timeout and payload validation.
  Future<List<SearchResult>> executeVectorSearch(
    String normalizedQuery, {
    String? filter,
    int limit = 20,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'searchTruthWorld',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
      );

      final resp = await callable.call({
        'query': normalizedQuery,
        'filter': filter ?? 'All',
        'limit': limit,
      });

      final rawList = resp.data;
      if (rawList is List && rawList.isNotEmpty) {
        final backendResults = rawList
            .whereType<Map>()
            .map((m) => SearchResult.fromMap(Map<String, dynamic>.from(m)))
            .where((r) => r.isValid)
            .toList();

        return backendResults;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'SearchCloudExecutor.searchTruthWorldCallable',
      );
    }
    return [];
  }
}
