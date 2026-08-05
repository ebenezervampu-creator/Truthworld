import 'package:truthworld/core/network/result.dart';

/// Repository interface for category operations.
abstract class CategoryRepository {
  /// Fetch all available categories.
  Future<Result<List<Map<String, dynamic>>>> getCategories();

  /// Fetch videos in a category with pagination.
  Future<Result<List<Map<String, dynamic>>>> getVideosByCategory(
    String category, {
    int page = 1,
    int limit = 20,
    String sortBy = 'trending',
  });

  /// Fetch category insights/stats.
  Future<Result<Map<String, dynamic>>> getCategoryInsights(String category);
}
