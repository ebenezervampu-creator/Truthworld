import 'package:cloud_functions/cloud_functions.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// Production client service for the TruthWorld IFCN Fact-Check Appeals Desk
/// and cryptographic governance audit operations.
class CredibilityGovernanceService {
  CredibilityGovernanceService._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: AppConfig.credibilityFunctionsRegion);

  /// Submits a formal claim appeal to the IFCN accredited appeals desk.
  /// Enforces creator authorization, ombudsman quorum, and cryptographic SHA-256 audit chaining.
  static Future<Map<String, dynamic>> submitClaimAppeal({
    required String videoId,
    required String claimId,
    required String claimText,
    required String originalVerdict,
    required String creatorRationale,
    List<String> evidenceUrls = const [],
  }) async {
    try {
      final callable = _functions.httpsCallable('submitClaimAppeal');
      final response = await callable.call<dynamic>({
        'videoId': videoId,
        'claimId': claimId,
        'claimText': claimText,
        'originalVerdict': originalVerdict,
        'creatorRationale': creatorRationale,
        'evidenceUrls': evidenceUrls,
      });
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      ErrorHandler.log(e);
      rethrow;
    }
  }

  /// Submits a factual dispute with supporting sources from a creator or community viewer.
  /// If creator: transitions video to pending review with tamper-evident audit logging.
  /// If viewer: records crowdsourced counter-evidence for community bridging consensus.
  static Future<Map<String, dynamic>> submitFactualDispute({
    required String videoId,
    required String reason,
    List<String> additionalSources = const [],
    String? claimId,
    int? claimIndex,
    String? claimText,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitFactualDispute');
      final response = await callable.call<dynamic>({
        'videoId': videoId,
        'reason': reason,
        'additionalSources': additionalSources,
        'claimId': ?claimId,
        'claimIndex': ?claimIndex,
        'claimText': ?claimText,
      });
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      ErrorHandler.log(e);
      rethrow;
    }
  }
}
