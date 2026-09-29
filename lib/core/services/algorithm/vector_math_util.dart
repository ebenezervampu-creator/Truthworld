import 'dart:math';

/// High-performance, pure Dart isolate-safe vector mathematics utility
/// for semantic vector embeddings and Two-Tower recommendation operations.
class VectorMathUtil {
  const VectorMathUtil._();

  /// Computes the dot product of two vectors: A · B = Σ (a_i * b_i).
  /// Returns 0.0 if vectors are empty or dimensions mismatch.
  static double dotProduct(List<double> a, List<double> b) {
    final len = min(a.length, b.length);
    if (len == 0) return 0.0;

    var dot = 0.0;
    for (var i = 0; i < len; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  /// Computes the Euclidean norm (L2 magnitude) of a vector: ||v|| = sqrt(Σ v_i^2).
  static double norm(List<double> v) {
    if (v.isEmpty) return 0.0;
    var sumSq = 0.0;
    for (var i = 0; i < v.length; i++) {
      final val = v[i];
      sumSq += val * val;
    }
    return sqrt(sumSq);
  }

  /// Computes Cosine Similarity between vectors A and B:
  /// cos(θ) = (A · B) / (||A|| * ||B||)
  /// Normalized to [-1.0, 1.0]. Returns 0.0 if either vector has zero magnitude.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;

    final dot = dotProduct(a, b);
    final normA = norm(a);
    final normB = norm(b);

    if (normA == 0.0 || normB == 0.0) return 0.0;

    final cosSim = dot / (normA * normB);
    return cosSim.clamp(-1.0, 1.0);
  }

  /// Computes Cosine Distance between vectors A and B:
  /// d_cos = 1.0 - cos(θ)
  /// Normalized to [0.0, 2.0].
  /// Identical vectors = 0.0, orthogonal = 1.0, opposite = 2.0.
  static double cosineDistance(List<double> a, List<double> b) {
    return 1.0 - cosineSimilarity(a, b);
  }

  /// Normalizes a vector to unit length (L2 norm = 1.0).
  /// Returns a copy of the vector. If zero magnitude, returns a zero vector copy.
  static List<double> normalize(List<double> v) {
    final magnitude = norm(v);
    if (magnitude == 0.0) return List<double>.from(v);

    final normalized = List<double>.filled(v.length, 0.0);
    for (var i = 0; i < v.length; i++) {
      normalized[i] = v[i] / magnitude;
    }
    return normalized;
  }

  /// Computes a weighted average centroid of multiple vectors.
  /// Result is normalized to unit length.
  static List<double>? weightedCentroid(
    List<List<double>> vectors,
    List<double> weights,
  ) {
    if (vectors.isEmpty || weights.isEmpty) return null;

    final count = min(vectors.length, weights.length);
    if (count == 0) return null;

    final dim = vectors[0].length;
    final centroid = List<double>.filled(dim, 0.0);
    var totalWeight = 0.0;

    for (var i = 0; i < count; i++) {
      final vec = vectors[i];
      if (vec.length != dim) continue;
      final w = weights[i];
      if (w <= 0.0) continue;

      totalWeight += w;
      for (var d = 0; d < dim; d++) {
        centroid[d] += vec[d] * w;
      }
    }

    if (totalWeight == 0.0) return null;

    return normalize(centroid);
  }
}
