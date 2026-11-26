import 'package:cloud_functions/cloud_functions.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Whether the server could price the dub yet.
enum DubbingQuoteStatus {
  /// [DubbingQuote.dubbingChargeUsd] is exactly what the server will charge.
  ready,

  /// The video is still being transcribed; the exact price is not known yet.
  transcriptPending,

  /// The quote could not be fetched (offline, server error).
  unavailable,

  /// Dubbing isn't offered for this video's language or a chosen language yet;
  /// [DubbingQuote.message] explains it to the creator.
  languageUnavailable,
}

/// The server's dubbing price for a video (callable `getDubbingQuote`).
///
/// The server is the only place dubbing is priced and charged: the quote uses the
/// same function as the charge in `triggerVideoAIFeatures`, so the amount shown
/// to the creator is the amount debited. Per language it is the higher of
/// $0.30 per minute and — when character pricing is on — $0.30 per 1,000
/// dubbed characters.
class DubbingQuote {
  const DubbingQuote({
    required this.status,
    this.dubbingChargeUsd = 0,
    this.priceByLanguage = const {},
    this.basis = 'minutes',
    this.characterPricingEnabled = false,
    this.minimumPricePerLanguageUsd = 0,
    this.message,
  });

  const DubbingQuote.unavailable() : this(status: DubbingQuoteStatus.unavailable);

  factory DubbingQuote.fromMap(Map<String, dynamic> map) {
    double toDouble(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    final rawStatus = map['status'] as String? ?? '';
    final prices = <String, double>{};
    final rawPrices = map['priceByLanguage'];
    if (rawPrices is Map) {
      rawPrices.forEach((key, value) => prices['$key'] = toDouble(value));
    }
    return DubbingQuote(
      status: switch (rawStatus) {
        'ready' => DubbingQuoteStatus.ready,
        'transcript_pending' => DubbingQuoteStatus.transcriptPending,
        'language_unavailable' => DubbingQuoteStatus.languageUnavailable,
        _ => DubbingQuoteStatus.unavailable,
      },
      dubbingChargeUsd: toDouble(map['dubbingChargeUsd']),
      priceByLanguage: prices,
      basis: map['basis'] as String? ?? 'minutes',
      characterPricingEnabled: map['characterPricingEnabled'] == true,
      minimumPricePerLanguageUsd: toDouble(map['minimumPricePerLanguageUsd']),
      message: map['message'] as String?,
    );
  }

  final DubbingQuoteStatus status;
  final double dubbingChargeUsd;
  final Map<String, double> priceByLanguage;

  /// `minutes` or `characters`.
  final String basis;
  final bool characterPricingEnabled;
  final double minimumPricePerLanguageUsd;

  /// Friendly text from the server (e.g. while the transcript is pending, or why a
  /// language can't be dubbed yet).
  final String? message;

  bool get isReady => status == DubbingQuoteStatus.ready;
  bool get isPricedByCharacters => basis == 'characters';
}

/// Fetches dubbing quotes from the server.
class DubbingQuoteService {
  DubbingQuoteService({FirebaseFunctions? functions}) : _functionsInstance = functions;

  final FirebaseFunctions? _functionsInstance;
  FirebaseFunctions get _functions =>
      _functionsInstance ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Never throws: failures come back as [DubbingQuoteStatus.unavailable].
  Future<DubbingQuote> fetch({
    required String videoId,
    required List<String> targetLanguages,
    int durationSeconds = 0,
  }) async {
    if (videoId.isEmpty || targetLanguages.isEmpty) {
      return const DubbingQuote(status: DubbingQuoteStatus.ready);
    }
    try {
      // Callable results arrive as Map<Object?, Object?> on some platforms: read as dynamic.
      final result = await _functions.httpsCallable('getDubbingQuote').call<dynamic>({
        'videoId': videoId,
        'targetLanguages': targetLanguages,
        'durationSeconds': durationSeconds,
      });
      final data = result.data;
      if (data is! Map) return const DubbingQuote.unavailable();
      return DubbingQuote.fromMap(Map<String, dynamic>.from(data));
    } on FirebaseFunctionsException catch (e) {
      logger.warning(
        'Server quote unavailable (${e.code}): ${e.message ?? "internal"}',
        tag: 'DubbingQuoteService.fetch',
      );
      return const DubbingQuote.unavailable();
    } catch (e) {
      logger.warning(
        'Server quote unavailable: $e',
        tag: 'DubbingQuoteService.fetch',
      );
      return const DubbingQuote.unavailable();
    }
  }
}
